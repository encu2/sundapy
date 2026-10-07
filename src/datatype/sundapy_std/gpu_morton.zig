const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

// ============================================================================
// Taichi Lang-Style Morton Z-Order Curve & SoA / AoS Layout Transpositions
// ============================================================================

pub inline fn part1By1(n: u32) u32 {
    var x = n & 0x0000FFFF;
    x = (x ^ (x << 8)) & 0x00FF00FF;
    x = (x ^ (x << 4)) & 0x0F0F0F0F;
    x = (x ^ (x << 2)) & 0x33333333;
    x = (x ^ (x << 1)) & 0x55555555;
    return x;
}

pub inline fn compact1By1(n: u32) u32 {
    var x = n & 0x55555555;
    x = (x ^ (x >> 1)) & 0x33333333;
    x = (x ^ (x >> 2)) & 0x0F0F0F0F;
    x = (x ^ (x >> 4)) & 0x00FF00FF;
    x = (x ^ (x >> 8)) & 0x0000FFFF;
    return x;
}

pub inline fn part1By2(n: u32) u32 {
    var x = n & 0x000003FF;
    x = (x ^ (x << 16)) & 0xFF0000FF;
    x = (x ^ (x << 8)) & 0x0300F00F;
    x = (x ^ (x << 4)) & 0x030C30C3;
    x = (x ^ (x << 2)) & 0x09249249;
    return x;
}

pub inline fn compact1By2(n: u32) u32 {
    var x = n & 0x09249249;
    x = (x ^ (x >> 2)) & 0x030C30C3;
    x = (x ^ (x >> 4)) & 0x0300F00F;
    x = (x ^ (x >> 8)) & 0xFF0000FF;
    x = (x ^ (x >> 16)) & 0x000003FF;
    return x;
}

pub fn morton_encode_2d(x_dyn: Dynamic, y_dyn: Dynamic) anyerror!Dynamic {
    if (x_dyn.value != .i64_type or y_dyn.value != .i64_type) return error.TypeError;
    const x: u32 = @intCast(@max(0, x_dyn.value.i64_type));
    const y: u32 = @intCast(@max(0, y_dyn.value.i64_type));
    const code = part1By1(x) | (part1By1(y) << 1);
    return Dynamic.initInt(@intCast(code));
}

pub fn morton_decode_2d(code_dyn: Dynamic) anyerror!Dynamic {
    if (code_dyn.value != .i64_type) return error.TypeError;
    const code: u32 = @intCast(@max(0, code_dyn.value.i64_type));
    const x = compact1By1(code);
    const y = compact1By1(code >> 1);

    var tuple = try std.heap.c_allocator.alloc(Dynamic, 2);
    tuple[0] = Dynamic.initInt(@intCast(x));
    tuple[1] = Dynamic.initInt(@intCast(y));
    return Dynamic{ .value = .{ .tuple_type = .{ .items = tuple, .allocator = std.heap.c_allocator } } };
}

pub fn morton_encode_3d(x_dyn: Dynamic, y_dyn: Dynamic, z_dyn: Dynamic) anyerror!Dynamic {
    if (x_dyn.value != .i64_type or y_dyn.value != .i64_type or z_dyn.value != .i64_type) return error.TypeError;
    const x: u32 = @intCast(@max(0, x_dyn.value.i64_type));
    const y: u32 = @intCast(@max(0, y_dyn.value.i64_type));
    const z: u32 = @intCast(@max(0, z_dyn.value.i64_type));
    const code = part1By2(x) | (part1By2(y) << 1) | (part1By2(z) << 2);
    return Dynamic.initInt(@intCast(code));
}

pub fn morton_decode_3d(code_dyn: Dynamic) anyerror!Dynamic {
    if (code_dyn.value != .i64_type) return error.TypeError;
    const code: u32 = @intCast(@max(0, code_dyn.value.i64_type));
    const x = compact1By2(code);
    const y = compact1By2(code >> 1);
    const z = compact1By2(code >> 2);

    var tuple = try std.heap.c_allocator.alloc(Dynamic, 3);
    tuple[0] = Dynamic.initInt(@intCast(x));
    tuple[1] = Dynamic.initInt(@intCast(y));
    tuple[2] = Dynamic.initInt(@intCast(z));
    return Dynamic{ .value = .{ .tuple_type = .{ .items = tuple, .allocator = std.heap.c_allocator } } };
}

pub fn morton_swizzle_2d(src_dyn: Dynamic, dst_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    if (src_dyn.value != .gpu_buffer_type or dst_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (w_dyn.value != .i64_type or h_dyn.value != .i64_type) return error.TypeError;

    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const w: usize = @intCast(@max(1, w_dyn.value.i64_type));
    const h: usize = @intCast(@max(1, h_dyn.value.i64_type));

    for (0..h) |y| {
        for (0..w) |x| {
            const linear_idx = y * w + x;
            if (linear_idx >= src.size) continue;
            const morton_idx: usize = @intCast(part1By1(@intCast(x)) | (part1By1(@intCast(y)) << 1));
            if (morton_idx < dst.size) {
                dst.data[morton_idx] = src.data[linear_idx];
            }
        }
    }
    dst.toDevice();
    return Dynamic.initNone();
}

pub fn morton_unswizzle_2d(src_dyn: Dynamic, dst_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    if (src_dyn.value != .gpu_buffer_type or dst_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (w_dyn.value != .i64_type or h_dyn.value != .i64_type) return error.TypeError;

    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const w: usize = @intCast(@max(1, w_dyn.value.i64_type));
    const h: usize = @intCast(@max(1, h_dyn.value.i64_type));

    for (0..h) |y| {
        for (0..w) |x| {
            const linear_idx = y * w + x;
            if (linear_idx >= dst.size) continue;
            const morton_idx: usize = @intCast(part1By1(@intCast(x)) | (part1By1(@intCast(y)) << 1));
            if (morton_idx < src.size) {
                dst.data[linear_idx] = src.data[morton_idx];
            }
        }
    }
    dst.toDevice();
    return Dynamic.initNone();
}

pub fn aos_to_soa(src_dyn: Dynamic, dst_dyn: Dynamic, count_dyn: Dynamic, channels_dyn: Dynamic) anyerror!Dynamic {
    if (src_dyn.value != .gpu_buffer_type or dst_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (count_dyn.value != .i64_type or channels_dyn.value != .i64_type) return error.TypeError;

    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const count: usize = @intCast(@max(1, count_dyn.value.i64_type));
    const channels: usize = @intCast(@max(1, channels_dyn.value.i64_type));

    for (0..count) |elem| {
        for (0..channels) |ch| {
            const aos_idx = elem * channels + ch;
            const soa_idx = ch * count + elem;
            if (aos_idx < src.size and soa_idx < dst.size) {
                dst.data[soa_idx] = src.data[aos_idx];
            }
        }
    }
    dst.toDevice();
    return Dynamic.initNone();
}

pub fn soa_to_aos(src_dyn: Dynamic, dst_dyn: Dynamic, count_dyn: Dynamic, channels_dyn: Dynamic) anyerror!Dynamic {
    if (src_dyn.value != .gpu_buffer_type or dst_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (count_dyn.value != .i64_type or channels_dyn.value != .i64_type) return error.TypeError;

    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const count: usize = @intCast(@max(1, count_dyn.value.i64_type));
    const channels: usize = @intCast(@max(1, channels_dyn.value.i64_type));

    for (0..count) |elem| {
        for (0..channels) |ch| {
            const aos_idx = elem * channels + ch;
            const soa_idx = ch * count + elem;
            if (aos_idx < dst.size and soa_idx < src.size) {
                dst.data[aos_idx] = src.data[soa_idx];
            }
        }
    }
    dst.toDevice();
    return Dynamic.initNone();
}
