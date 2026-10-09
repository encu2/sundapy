const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const compress_types = @import("gpu_compress_types.zig");
const CodecType = compress_types.CodecType;

// ============================================================================
// Production GPU & System Memory Budget Subsystem
// Enforces VRAM limits, performs tiered compaction, and prevents Out-Of-Memory
// ============================================================================

pub const MAX_TRACKED_BUFFERS: usize = 256;

pub const MemoryBudgetState = struct {
    budget_limit_bytes: usize = 0, // 0 = unlimited
    total_physical_bytes: usize = 0, // Actual physical VRAM/RAM used
    virtual_uncompressed_bytes: usize = 0, // Uncompressed equivalent
    compressed_bytes: usize = 0, // Total compressed payload bytes
    saved_bytes: usize = 0, // Bytes saved by compression
    oom_prevented_count: usize = 0, // Number of zero-OOM saves triggered
    tracked_buffers: [MAX_TRACKED_BUFFERS]?*GpuBuffer = [_]?*GpuBuffer{null} ** MAX_TRACKED_BUFFERS,
    buffer_count: usize = 0,
};

var global_budget: MemoryBudgetState = .{};

pub fn setMemoryBudget(bytes: usize) void {
    global_budget.budget_limit_bytes = bytes;
}

pub fn getMemoryBudget() MemoryBudgetState {
    return global_budget;
}

pub fn registerBuffer(buf: *GpuBuffer) void {
    const raw_bytes = buf.size * buf.dtype.sizeOf();
    global_budget.total_physical_bytes += raw_bytes;
    global_budget.virtual_uncompressed_bytes += raw_bytes;

    for (&global_budget.tracked_buffers) |*slot| {
        if (slot.* == null) {
            slot.* = buf;
            global_budget.buffer_count += 1;
            break;
        }
    }
}

pub fn unregisterBuffer(buf: *GpuBuffer) void {
    const raw_bytes = buf.size * buf.dtype.sizeOf();
    if (global_budget.total_physical_bytes >= raw_bytes) {
        global_budget.total_physical_bytes -= raw_bytes;
    }
    if (global_budget.virtual_uncompressed_bytes >= raw_bytes) {
        global_budget.virtual_uncompressed_bytes -= raw_bytes;
    }

    for (&global_budget.tracked_buffers) |*slot| {
        if (slot.* == buf) {
            slot.* = null;
            if (global_budget.buffer_count > 0) global_budget.buffer_count -= 1;
            break;
        }
    }
}

pub fn recordCompression(orig_bytes: usize, comp_bytes: usize) void {
    if (orig_bytes > comp_bytes) {
        const diff = orig_bytes - comp_bytes;
        global_budget.saved_bytes += diff;
        if (global_budget.total_physical_bytes >= diff) {
            global_budget.total_physical_bytes -= diff;
        }
        global_budget.compressed_bytes += comp_bytes;
    }
}

pub fn recordDecompression(orig_bytes: usize, comp_bytes: usize) void {
    if (orig_bytes > comp_bytes) {
        const diff = orig_bytes - comp_bytes;
        if (global_budget.saved_bytes >= diff) {
            global_budget.saved_bytes -= diff;
        }
        global_budget.total_physical_bytes += diff;
        if (global_budget.compressed_bytes >= comp_bytes) {
            global_budget.compressed_bytes -= comp_bytes;
        }
    }
}

pub fn autoCompactIfNeeded(req_bytes: usize) bool {
    if (global_budget.budget_limit_bytes > 0 and global_budget.total_physical_bytes + req_bytes > global_budget.budget_limit_bytes) {
        _ = compactMemory();
        return (global_budget.total_physical_bytes + req_bytes <= global_budget.budget_limit_bytes);
    }
    return true;
}

pub fn compactMemory() usize {
    var reclaimed_bytes: usize = 0;
    const fpc = @import("gpu_codec_fpc.zig");

    for (global_budget.tracked_buffers) |slot| {
        if (slot) |buf| {
            const is_comp = if (buf.compression_info) |ci| ci.is_compressed else false;
            if (!is_comp and buf.size > 16) {
                // Compress with lossless FPC
                const comp = fpc.compress(std.heap.c_allocator, buf.data) catch continue;
                const orig_b = buf.size * @sizeOf(f32);
                if (comp.len < orig_b) {
                    const saved = orig_b - comp.len;
                    reclaimed_bytes += saved;
                    recordCompression(orig_b, comp.len);
                    if (buf.compression_info == null) {
                        buf.compression_info = std.heap.c_allocator.create(gpu_types.CompressionInfo) catch {
                            std.heap.c_allocator.free(comp);
                            continue;
                        };
                        buf.compression_info.?.* = .{};
                    }
                    const ci = buf.compression_info.?;
                    if (ci.raw_payload) |old_p| {
                        std.heap.c_allocator.free(old_p);
                    }
                    ci.raw_payload = comp;
                    ci.is_compressed = true;
                    ci.compressed_bytes = comp.len;
                    ci.original_bytes = orig_b;
                    ci.compression_ratio = @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(comp.len));
                    ci.savings_pct = (@as(f32, @floatFromInt(saved)) / @as(f32, @floatFromInt(orig_b))) * 100.0;
                    ci.scheme = "fpc";
                } else {
                    std.heap.c_allocator.free(comp);
                }
            }
        }
    }

    if (reclaimed_bytes > 0) {
        global_budget.oom_prevented_count += 1;
    }
    return reclaimed_bytes;
}

pub fn getMemoryStats(allocator: std.mem.Allocator) !Dynamic {
    var dict = Dynamic.initDict(allocator);

    var compressed_count: usize = 0;
    var active_count: usize = 0;
    for (global_budget.tracked_buffers) |slot| {
        if (slot) |buf| {
            active_count += 1;
            if (buf.compression_info) |ci| {
                if (ci.is_compressed) compressed_count += 1;
            }
        }
    }

    const eff_ratio: f32 = if (global_budget.total_physical_bytes > 0)
        @as(f32, @floatFromInt(global_budget.virtual_uncompressed_bytes)) / @as(f32, @floatFromInt(global_budget.total_physical_bytes))
    else
        1.0;

    const savings_pct: f32 = if (global_budget.virtual_uncompressed_bytes > 0)
        (@as(f32, @floatFromInt(global_budget.saved_bytes)) / @as(f32, @floatFromInt(global_budget.virtual_uncompressed_bytes))) * 100.0
    else
        0.0;

    try dict.value.dict_type.put(Dynamic.initStr("budget_limit_bytes"), Dynamic.initInt(@intCast(global_budget.budget_limit_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("budget_limit_mb"), Dynamic.initFloat(@as(f64, @floatFromInt(global_budget.budget_limit_bytes)) / (1024.0 * 1024.0)));
    try dict.value.dict_type.put(Dynamic.initStr("allocated_bytes"), Dynamic.initInt(@intCast(global_budget.total_physical_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("allocated_mb"), Dynamic.initFloat(@as(f64, @floatFromInt(global_budget.total_physical_bytes)) / (1024.0 * 1024.0)));
    try dict.value.dict_type.put(Dynamic.initStr("virtual_bytes"), Dynamic.initInt(@intCast(global_budget.virtual_uncompressed_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("virtual_mb"), Dynamic.initFloat(@as(f64, @floatFromInt(global_budget.virtual_uncompressed_bytes)) / (1024.0 * 1024.0)));
    try dict.value.dict_type.put(Dynamic.initStr("saved_bytes"), Dynamic.initInt(@intCast(global_budget.saved_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("saved_mb"), Dynamic.initFloat(@as(f64, @floatFromInt(global_budget.saved_bytes)) / (1024.0 * 1024.0)));
    try dict.value.dict_type.put(Dynamic.initStr("compression_ratio"), Dynamic.initFloat(@floatCast(eff_ratio)));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings_pct)));
    try dict.value.dict_type.put(Dynamic.initStr("active_buffers"), Dynamic.initInt(@intCast(active_count)));
    try dict.value.dict_type.put(Dynamic.initStr("compressed_buffers"), Dynamic.initInt(@intCast(compressed_count)));
    try dict.value.dict_type.put(Dynamic.initStr("oom_prevented_count"), Dynamic.initInt(@intCast(global_budget.oom_prevented_count)));

    return dict;
}

pub fn printMemoryReport() void {
    const stats_dict = getMemoryStats(std.heap.c_allocator) catch return;
    _ = stats_dict;
    const mb_div: f64 = 1024.0 * 1024.0;
    const alloc_mb = @as(f64, @floatFromInt(global_budget.total_physical_bytes)) / mb_div;
    const virt_mb = @as(f64, @floatFromInt(global_budget.virtual_uncompressed_bytes)) / mb_div;
    const saved_mb = @as(f64, @floatFromInt(global_budget.saved_bytes)) / mb_div;
    const ratio = if (global_budget.total_physical_bytes > 0)
        @as(f64, @floatFromInt(global_budget.virtual_uncompressed_bytes)) / @as(f64, @floatFromInt(global_budget.total_physical_bytes))
    else
        1.0;

    std.debug.print(
        \\=================================================================
        \\   SUNDAPY PRODUCTION GPU MEMORY SUBSYSTEM REPORT
        \\=================================================================
        \\ Physical VRAM/RAM Used : {d:.2} MB
        \\ Virtual Uncompressed   : {d:.2} MB
        \\ Reclaimed / Saved VRAM : {d:.2} MB
        \\ Effective Comp. Ratio  : {d:.2}x
        \\ Active Buffers         : {d}
        \\ Zero-OOM Saves Triggered: {d}
        \\=================================================================
        \\
    , .{ alloc_mb, virt_mb, saved_mb, ratio, global_budget.buffer_count, global_budget.oom_prevented_count });
}
