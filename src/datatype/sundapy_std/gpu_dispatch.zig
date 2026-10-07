const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");
const spmd = @import("gpu_spmd.zig");
const pool = @import("gpu_pool.zig");

// ============================================================================
// Multi-Core CPU & GPU Kernel Dispatcher (Persistent Worker Pool)
// ============================================================================

pub const WorkerPayload = struct {
    kernel_fn: Dynamic,
    start_block: usize,
    end_block: usize,
    grid_x: usize,
    grid_y: usize,
    grid_z: usize,
    block_x: usize,
    block_y: usize,
    block_z: usize,
    args: []const Dynamic,
    alloc: std.mem.Allocator,
};

pub fn cpuWorker(payload: WorkerPayload) void {
    spmd.cur_grid_dim_x = payload.grid_x;
    spmd.cur_grid_dim_y = payload.grid_y;
    spmd.cur_grid_dim_z = payload.grid_z;
    spmd.cur_block_dim_x = payload.block_x;
    spmd.cur_block_dim_y = payload.block_y;
    spmd.cur_block_dim_z = payload.block_z;

    // Fast Path: 1D Grid & 1D Block (most frequent GPU compute pattern)
    if (payload.grid_y == 1 and payload.grid_z == 1 and payload.block_y == 1 and payload.block_z == 1) {
        spmd.cur_block_idx_y = 0;
        spmd.cur_block_idx_z = 0;
        spmd.cur_thread_idx_y = 0;
        spmd.cur_thread_idx_z = 0;

        var b: usize = payload.start_block;
        while (b < payload.end_block) : (b += 1) {
            spmd.cur_block_idx_x = b;
            var tx: usize = 0;
            while (tx < payload.block_x) : (tx += 1) {
                spmd.cur_thread_idx_x = tx;
                _ = payload.kernel_fn.builtin_call(payload.alloc, payload.args, null) catch {};
            }
        }
        return;
    }

    // General Multi-Dimensional Grid & Block Path
    const gx = payload.grid_x;
    const gy = payload.grid_y;
    const gxy = gx * gy;

    var b: usize = payload.start_block;
    while (b < payload.end_block) : (b += 1) {
        spmd.cur_block_idx_x = b % gx;
        spmd.cur_block_idx_y = (b / gx) % gy;
        spmd.cur_block_idx_z = b / gxy;

        var tx: usize = 0;
        while (tx < payload.block_x) : (tx += 1) {
            spmd.cur_thread_idx_x = tx;
            var ty: usize = 0;
            while (ty < payload.block_y) : (ty += 1) {
                spmd.cur_thread_idx_y = ty;
                var tz: usize = 0;
                while (tz < payload.block_z) : (tz += 1) {
                    spmd.cur_thread_idx_z = tz;
                    _ = payload.kernel_fn.builtin_call(payload.alloc, payload.args, null) catch {};
                }
            }
        }
    }
}

fn workerTaskWrapper(ctx: ?*anyopaque) void {
    const p: *WorkerPayload = @ptrCast(@alignCast(ctx.?));
    cpuWorker(p.*);
}

pub fn launchInternal(allocator_mem: std.mem.Allocator, kernel_fn: Dynamic, gx: usize, gy: usize, gz: usize, bx: usize, by: usize, bz: usize, args: []const Dynamic) anyerror!Dynamic {
    driver.initGpuDriver(launchInternal);

    for (args) |arg| {
        if (arg.value == .gpu_buffer_type) {
            const buf: *GpuBuffer = @ptrCast(@alignCast(arg.value.gpu_buffer_type));
            buf.toDevice();
        }
    }

    const total_blocks = gx * gy * gz;
    if (total_blocks == 0) return Dynamic.initNone();

    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;
    const num_threads = @min(total_blocks, @max(1, num_workers));

    if (num_threads <= 1) {
        cpuWorker(WorkerPayload{
            .kernel_fn = kernel_fn,
            .start_block = 0,
            .end_block = total_blocks,
            .grid_x = gx,
            .grid_y = gy,
            .grid_z = gz,
            .block_x = bx,
            .block_y = by,
            .block_z = bz,
            .args = args,
            .alloc = allocator_mem,
        });
    } else {
        var payloads: [pool.MAX_WORKERS]WorkerPayload = undefined;
        var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
        var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

        const blocks_per_thread = (total_blocks + num_threads - 1) / num_threads;
        var start_b: usize = 0;
        var count: usize = 0;

        for (0..num_threads) |i| {
            if (start_b >= total_blocks) break;
            const end_b = @min(total_blocks, start_b + blocks_per_thread);

            payloads[i] = WorkerPayload{
                .kernel_fn = kernel_fn,
                .start_block = start_b,
                .end_block = end_b,
                .grid_x = gx,
                .grid_y = gy,
                .grid_z = gz,
                .block_x = bx,
                .block_y = by,
                .block_z = bz,
                .args = args,
                .alloc = allocator_mem,
            };
            funcs[i] = workerTaskWrapper;
            args_ptr[i] = &payloads[i];
            count += 1;
            start_b = end_b;
        }

        global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    }

    for (args) |arg| {
        if (arg.value == .gpu_buffer_type) {
            const buf: *GpuBuffer = @ptrCast(@alignCast(arg.value.gpu_buffer_type));
            buf.toDevice();
        }
    }

    return Dynamic.initNone();
}

pub fn launch(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len < 3) return error.TypeError;
    const kernel_fn = args[0];
    const grid_dyn = args[1];
    const block_dyn = args[2];
    const kernel_args = if (args.len > 3) args[3..] else &[_]Dynamic{};

    var gx: usize = 1;
    var gy: usize = 1;
    var gz: usize = 1;
    if (grid_dyn.value == .i64_type) {
        gx = @intCast(@max(1, grid_dyn.value.i64_type));
    } else if (grid_dyn.value == .list_type or grid_dyn.value == .tuple_type) {
        const items = if (grid_dyn.value == .list_type) grid_dyn.value.list_type.items.items else grid_dyn.value.tuple_type.items;
        if (items.len > 0 and items[0].value == .i64_type) gx = @intCast(@max(1, items[0].value.i64_type));
        if (items.len > 1 and items[1].value == .i64_type) gy = @intCast(@max(1, items[1].value.i64_type));
        if (items.len > 2 and items[2].value == .i64_type) gz = @intCast(@max(1, items[2].value.i64_type));
    }

    var bx: usize = 1;
    var by: usize = 1;
    var bz: usize = 1;
    if (block_dyn.value == .i64_type) {
        bx = @intCast(@max(1, block_dyn.value.i64_type));
    } else if (block_dyn.value == .list_type or block_dyn.value == .tuple_type) {
        const items = if (block_dyn.value == .list_type) block_dyn.value.list_type.items.items else block_dyn.value.tuple_type.items;
        if (items.len > 0 and items[0].value == .i64_type) bx = @intCast(@max(1, items[0].value.i64_type));
        if (items.len > 1 and items[1].value == .i64_type) by = @intCast(@max(1, items[1].value.i64_type));
        if (items.len > 2 and items[2].value == .i64_type) bz = @intCast(@max(1, items[2].value.i64_type));
    }

    return launchInternal(std.heap.c_allocator, kernel_fn, gx, gy, gz, bx, by, bz, kernel_args);
}

const ParForPayload = struct {
    func: Dynamic,
    start_idx: i64,
    end_idx: i64,
};

fn parForTaskWrapper(ctx: ?*anyopaque) void {
    const p: *ParForPayload = @ptrCast(@alignCast(ctx.?));
    var i = p.start_idx;
    while (i < p.end_idx) : (i += 1) {
        const arg = [_]Dynamic{Dynamic.initInt(i)};
        _ = p.func.builtin_call(std.heap.c_allocator, &arg, null) catch {};
    }
}

pub fn parallel_for(start_dyn: Dynamic, end_dyn: Dynamic, func: Dynamic) anyerror!Dynamic {
    if (start_dyn.value != .i64_type or end_dyn.value != .i64_type) return error.TypeError;
    const start: i64 = start_dyn.value.i64_type;
    const end: i64 = end_dyn.value.i64_type;
    if (start >= end) return Dynamic.initNone();

    const total: usize = @intCast(end - start);
    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;
    const num_threads = @min(total, @max(1, num_workers));

    if (num_threads <= 1) {
        var p = ParForPayload{ .func = func, .start_idx = start, .end_idx = end };
        parForTaskWrapper(&p);
    } else {
        var payloads: [pool.MAX_WORKERS]ParForPayload = undefined;
        var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
        var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

        const chunk = (total + num_threads - 1) / num_threads;
        var s: i64 = start;
        var count: usize = 0;

        for (0..num_threads) |i| {
            if (s >= end) break;
            const e = @min(end, s + @as(i64, @intCast(chunk)));
            payloads[i] = ParForPayload{ .func = func, .start_idx = s, .end_idx = e };
            funcs[i] = parForTaskWrapper;
            args_ptr[i] = &payloads[i];
            count += 1;
            s = e;
        }

        global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    }

    return Dynamic.initNone();
}

pub fn cpu_parallel(start_dyn: Dynamic, end_dyn: Dynamic, func: Dynamic) anyerror!Dynamic {
    return parallel_for(start_dyn, end_dyn, func);
}
