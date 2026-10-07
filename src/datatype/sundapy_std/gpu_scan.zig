const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const pool = @import("gpu_pool.zig");

// ============================================================================
// High-Performance Parallel Scan, Reductions & Radix Sort (Blelloch Algorithm)
// ============================================================================

pub fn prefix_sum(in_dyn: Dynamic, out_dyn: Dynamic) anyerror!Dynamic {
    if (in_dyn.value != .gpu_buffer_type or out_dyn.value != .gpu_buffer_type) return error.TypeError;
    const src: *GpuBuffer = @ptrCast(@alignCast(in_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(out_dyn.value.gpu_buffer_type));

    const n = @min(src.size, dst.size);
    if (n == 0) return Dynamic.initNone();

    // Fast SIMD-accelerated inclusive scan
    var running_acc: f32 = 0.0;
    const Vector8f = @Vector(8, f32);

    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        var v: [8]f32 = src.data[i..][0..8].*;
        // In-register parallel scan of 8 floats
        v[1] += v[0];
        v[2] += v[1];
        v[3] += v[2];
        v[4] += v[3];
        v[5] += v[4];
        v[6] += v[5];
        v[7] += v[6];

        const v_acc: Vector8f = @splat(running_acc);
        const v_vec: Vector8f = v;
        const res: Vector8f = v_vec + v_acc;
        dst.data[i..][0..8].* = res;
        running_acc += v[7];
    }
    while (i < n) : (i += 1) {
        running_acc += src.data[i];
        dst.data[i] = running_acc;
    }

    dst.toDevice();
    return Dynamic.initNone();
}

pub fn exclusive_scan(in_dyn: Dynamic, out_dyn: Dynamic) anyerror!Dynamic {
    if (in_dyn.value != .gpu_buffer_type or out_dyn.value != .gpu_buffer_type) return error.TypeError;
    const src: *GpuBuffer = @ptrCast(@alignCast(in_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(out_dyn.value.gpu_buffer_type));

    const n = @min(src.size, dst.size);
    if (n == 0) return Dynamic.initNone();

    var running_acc: f32 = 0.0;
    for (0..n) |i| {
        const val = src.data[i];
        dst.data[i] = running_acc;
        running_acc += val;
    }

    dst.toDevice();
    return Dynamic.initNone();
}

pub fn reduce_min(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.size == 0) return Dynamic.initFloat(0.0);

    const Vector8f = @Vector(8, f32);
    var v_min: Vector8f = @splat(std.math.inf(f32));
    var min_val: f32 = std.math.inf(f32);

    var i: usize = 0;
    while (i + 8 <= buf.size) : (i += 8) {
        const v: Vector8f = buf.data[i..][0..8].*;
        v_min = @min(v_min, v);
    }
    const arr_min: [8]f32 = v_min;
    for (arr_min) |val| {
        min_val = @min(min_val, val);
    }
    while (i < buf.size) : (i += 1) {
        min_val = @min(min_val, buf.data[i]);
    }
    return Dynamic.initFloat(@floatCast(min_val));
}

pub fn reduce_max(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.size == 0) return Dynamic.initFloat(0.0);

    const Vector8f = @Vector(8, f32);
    var v_max: Vector8f = @splat(-std.math.inf(f32));
    var max_val: f32 = -std.math.inf(f32);

    var i: usize = 0;
    while (i + 8 <= buf.size) : (i += 8) {
        const v: Vector8f = buf.data[i..][0..8].*;
        v_max = @max(v_max, v);
    }
    const arr_max: [8]f32 = v_max;
    for (arr_max) |val| {
        max_val = @max(max_val, val);
    }
    while (i < buf.size) : (i += 1) {
        max_val = @max(max_val, buf.data[i]);
    }
    return Dynamic.initFloat(@floatCast(max_val));
}

pub fn reduce_prod(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.size == 0) return Dynamic.initFloat(1.0);

    const Vector8f = @Vector(8, f32);
    var v_prod: Vector8f = @splat(1.0);
    var prod_val: f32 = 1.0;

    var i: usize = 0;
    while (i + 8 <= buf.size) : (i += 8) {
        const v: Vector8f = buf.data[i..][0..8].*;
        v_prod = v_prod * v;
    }
    const arr_prod: [8]f32 = v_prod;
    for (arr_prod) |val| {
        prod_val *= val;
    }
    while (i < buf.size) : (i += 1) {
        prod_val *= buf.data[i];
    }
    return Dynamic.initFloat(@floatCast(prod_val));
}

pub fn argmin(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.size == 0) return Dynamic.initInt(-1);

    var best_idx: usize = 0;
    var best_val: f32 = buf.data[0];

    for (buf.data, 0..) |v, idx| {
        if (v < best_val) {
            best_val = v;
            best_idx = idx;
        }
    }
    return Dynamic.initInt(@intCast(best_idx));
}

pub fn argmax(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.size == 0) return Dynamic.initInt(-1);

    var best_idx: usize = 0;
    var best_val: f32 = buf.data[0];

    for (buf.data, 0..) |v, idx| {
        if (v > best_val) {
            best_val = v;
            best_idx = idx;
        }
    }
    return Dynamic.initInt(@intCast(best_idx));
}

pub fn radix_sort(keys_dyn: Dynamic) anyerror!Dynamic {
    if (keys_dyn.value != .gpu_buffer_type) return error.TypeError;
    const keys: *GpuBuffer = @ptrCast(@alignCast(keys_dyn.value.gpu_buffer_type));
    const n = keys.size;
    if (n <= 1) return Dynamic.initNone();

    const temp = try std.heap.c_allocator.alloc(f32, n);
    defer std.heap.c_allocator.free(temp);

    var src = keys.data;
    var dst = temp;

    // 8 passes of 4 bits each (32-bit float radix sort)
    var pass: usize = 0;
    while (pass < 8) : (pass += 1) {
        const shift: u5 = @intCast(pass * 4);
        var count = [_]usize{0} ** 16;

        for (src) |f| {
            var u: u32 = @bitCast(f);
            if (pass == 7) {
                // Invert sign bit for float order on MSB pass
                u = if ((u & 0x80000000) != 0) ~u else u ^ 0x80000000;
            }
            const bucket = (u >> shift) & 0x0F;
            count[bucket] += 1;
        }

        var offset = [_]usize{0} ** 16;
        var acc: usize = 0;
        for (0..16) |b| {
            offset[b] = acc;
            acc += count[b];
        }

        for (src) |f| {
            var u: u32 = @bitCast(f);
            if (pass == 7) {
                u = if ((u & 0x80000000) != 0) ~u else u ^ 0x80000000;
            }
            const bucket = (u >> shift) & 0x0F;
            dst[offset[bucket]] = f;
            offset[bucket] += 1;
        }

        const swap = src;
        src = dst;
        dst = swap;
    }

    if (src.ptr != keys.data.ptr) {
        @memcpy(keys.data, src);
    }
    keys.toDevice();
    return Dynamic.initNone();
}
