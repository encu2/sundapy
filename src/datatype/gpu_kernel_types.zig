const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("gpu_types.zig");

pub const LaunchFn = *const fn (std.mem.Allocator, Dynamic, usize, usize, usize, usize, usize, usize, []const Dynamic) anyerror!Dynamic;

pub const BoundKernel = struct {
    kernel_fn: Dynamic,
    grid_x: usize,
    grid_y: usize,
    grid_z: usize,
    block_x: usize,
    block_y: usize,
    block_z: usize,

    pub fn call(self: *BoundKernel, allocator_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        if (gpu_types.launch_fn) |lfn| {
            return lfn(allocator_mem, self.kernel_fn, self.grid_x, self.grid_y, self.grid_z, self.block_x, self.block_y, self.block_z, args);
        }
        return Dynamic.initNone();
    }
};

fn unpackDim(dyn: Dynamic, out: *[3]usize) void {
    if (dyn.value == .i64_type) {
        out[0] = @intCast(@max(1, dyn.value.i64_type));
    } else if (dyn.value == .list_type or dyn.value == .tuple_type) {
        const items = if (dyn.value == .list_type) dyn.value.list_type.items.items else dyn.value.tuple_type.items;
        for (items, 0..) |it, i| {
            if (i < 3 and it.value == .i64_type) out[i] = @intCast(@max(1, it.value.i64_type));
        }
    }
}

pub fn createBoundKernel(kernel_fn: Dynamic, index: Dynamic) anyerror!Dynamic {
    var g = [3]usize{ 1, 1, 1 };
    var b = [3]usize{ 1, 1, 1 };

    if (index.value == .list_type or index.value == .tuple_type) {
        const items = if (index.value == .list_type) index.value.list_type.items.items else index.value.tuple_type.items;
        if (items.len >= 1) unpackDim(items[0], &g);
        if (items.len >= 2) unpackDim(items[1], &b);
    } else if (index.value == .i64_type) {
        g[0] = @intCast(@max(1, index.value.i64_type));
    }

    const bound = try std.heap.c_allocator.create(BoundKernel);
    bound.* = BoundKernel{
        .kernel_fn = kernel_fn,
        .grid_x = g[0],
        .grid_y = g[1],
        .grid_z = g[2],
        .block_x = b[0],
        .block_y = b[1],
        .block_z = b[2],
    };

    return Dynamic{ .value = .{ .gpu_kernel_type = @ptrCast(bound) } };
}
