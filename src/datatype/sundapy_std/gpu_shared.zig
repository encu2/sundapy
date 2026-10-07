const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const spmd = @import("gpu_spmd.zig");

// ============================================================================
// Numba-Style Block Shared Memory Scratchpad & Intra-Warp Shuffles
// ============================================================================

// Static cache aligned to 64 bytes (L1 cache line size) for zero-malloc block scratchpad
var shared_scratchpad: [65536]f32 align(64) = [_]f32{0.0} ** 65536;
var shared_alloc_offset: usize = 0;

pub fn shared_array(size_dyn: Dynamic) anyerror!Dynamic {
    const s: usize = if (size_dyn.value == .i64_type) @intCast(@max(1, size_dyn.value.i64_type)) else 256;
    if (shared_alloc_offset + s <= shared_scratchpad.len) {
        const slice = shared_scratchpad[shared_alloc_offset .. shared_alloc_offset + s];
        shared_alloc_offset += s;
        // Wrap as GpuBuffer with static memory
        const buf = try std.heap.c_allocator.create(GpuBuffer);
        buf.* = GpuBuffer{
            .allocator = std.heap.c_allocator,
            .size = s,
            .data = slice,
            .dev_ptr = 0,
            .is_device_allocated = false,
            .is_managed = true, // Prevent deallocation of static memory
            .shape = [_]usize{ s, 1, 1, 1 },
            .strides = [_]usize{ 1, 1, 1, 1 },
            .ndim = 1,
        };
        return buf.asDynamic();
    }

    // Dynamic fallback if requested size exceeds 64KB static scratchpad
    const buf = try GpuBuffer.init(std.heap.c_allocator, s);
    return buf.asDynamic();
}

pub fn reset_shared_memory() void {
    shared_alloc_offset = 0;
}

pub fn grid(ndim_dyn: Dynamic) anyerror!Dynamic {
    const ndim = if (ndim_dyn.value == .i64_type) ndim_dyn.value.i64_type else 1;
    if (ndim <= 1) {
        const gx = spmd.cur_block_idx_x * spmd.cur_block_dim_x + spmd.cur_thread_idx_x;
        return Dynamic.initInt(@intCast(gx));
    } else if (ndim == 2) {
        const gx = spmd.cur_block_idx_x * spmd.cur_block_dim_x + spmd.cur_thread_idx_x;
        const gy = spmd.cur_block_idx_y * spmd.cur_block_dim_y + spmd.cur_thread_idx_y;
        var t = try std.heap.c_allocator.alloc(Dynamic, 2);
        t[0] = Dynamic.initInt(@intCast(gx));
        t[1] = Dynamic.initInt(@intCast(gy));
        return Dynamic{ .value = .{ .tuple_type = .{ .items = t, .allocator = std.heap.c_allocator } } };
    } else {
        const gx = spmd.cur_block_idx_x * spmd.cur_block_dim_x + spmd.cur_thread_idx_x;
        const gy = spmd.cur_block_idx_y * spmd.cur_block_dim_y + spmd.cur_thread_idx_y;
        const gz = spmd.cur_block_idx_z * spmd.cur_block_dim_z + spmd.cur_thread_idx_z;
        var t = try std.heap.c_allocator.alloc(Dynamic, 3);
        t[0] = Dynamic.initInt(@intCast(gx));
        t[1] = Dynamic.initInt(@intCast(gy));
        t[2] = Dynamic.initInt(@intCast(gz));
        return Dynamic{ .value = .{ .tuple_type = .{ .items = t, .allocator = std.heap.c_allocator } } };
    }
}

pub fn warp_shuffle_down(val_dyn: Dynamic, delta_dyn: Dynamic) anyerror!Dynamic {
    _ = delta_dyn;
    // In SIMD/CPU emulation, warp lane shuffle acts as identity or pass-through
    return val_dyn;
}

pub fn warp_shuffle_xor(val_dyn: Dynamic, mask_dyn: Dynamic) anyerror!Dynamic {
    _ = mask_dyn;
    return val_dyn;
}
