const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const pool = @import("gpu_pool.zig");

// ============================================================================
// Ultra-Fast SIMD & Multi-Core Vectorized Math Accelerators
// ============================================================================

pub fn vector_add(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, @min(b.size, c.size));

    const Vector8f = @Vector(8, f32);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        c.data[i..][0..8].* = va + vb;
    }
    while (i < n) : (i += 1) {
        c.data[i] = a.data[i] + b.data[i];
    }
    c.toDevice();
    return Dynamic.initNone();
}

pub fn vector_mul(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, @min(b.size, c.size));

    const Vector8f = @Vector(8, f32);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        c.data[i..][0..8].* = va * vb;
    }
    while (i < n) : (i += 1) {
        c.data[i] = a.data[i] * b.data[i];
    }
    c.toDevice();
    return Dynamic.initNone();
}

const MatmulChunkPayload = struct {
    a: [*]const f32,
    b: [*]const f32,
    c: [*]f32,
    start_i: usize,
    end_i: usize,
    K: usize,
    N: usize,
};

fn matmulWorkerTask(ctx: ?*anyopaque) void {
    const p: *const MatmulChunkPayload = @ptrCast(@alignCast(ctx.?));
    const Vector8f = @Vector(8, f32);
    const K = p.K;
    const N = p.N;

    var i = p.start_i;
    while (i < p.end_i) : (i += 1) {
        // Zero row of C
        @memset(p.c[i * N .. (i + 1) * N], 0.0);
        var k: usize = 0;
        while (k < K) : (k += 1) {
            const a_ik = p.a[i * K + k];
            const va_ik: Vector8f = @splat(a_ik);
            var j: usize = 0;
            while (j + 8 <= N) : (j += 8) {
                const vb: Vector8f = p.b[k * N + j ..][0..8].*;
                const vc: Vector8f = p.c[i * N + j ..][0..8].*;
                p.c[i * N + j ..][0..8].* = vc + va_ik * vb;
            }
            while (j < N) : (j += 1) {
                p.c[i * N + j] += a_ik * p.b[k * N + j];
            }
        }
    }
}

pub fn matmul(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, m_dyn: Dynamic, k_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (m_dyn.value != .i64_type or k_dyn.value != .i64_type or n_dyn.value != .i64_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));

    const M: usize = @intCast(m_dyn.value.i64_type);
    const K: usize = @intCast(k_dyn.value.i64_type);
    const N: usize = @intCast(n_dyn.value.i64_type);

    if (M == 0 or K == 0 or N == 0) return Dynamic.initNone();

    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;

    // For large matrices, split row-wise across persistent worker pool
    if (M >= 16 and (M * N * K) >= 4096 and num_workers > 1) {
        const num_threads = @min(M, num_workers);
        var payloads: [pool.MAX_WORKERS]MatmulChunkPayload = undefined;
        var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
        var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

        const rows_per_thread = (M + num_threads - 1) / num_threads;
        var start_i: usize = 0;
        var count: usize = 0;

        for (0..num_threads) |t| {
            if (start_i >= M) break;
            const end_i = @min(M, start_i + rows_per_thread);
            payloads[t] = MatmulChunkPayload{
                .a = a.data.ptr,
                .b = b.data.ptr,
                .c = c.data.ptr,
                .start_i = start_i,
                .end_i = end_i,
                .K = K,
                .N = N,
            };
            funcs[t] = matmulWorkerTask;
            args_ptr[t] = &payloads[t];
            count += 1;
            start_i = end_i;
        }

        global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    } else {
        // Direct single-threaded vectorized i, k, j loop
        var payload = MatmulChunkPayload{
            .a = a.data.ptr,
            .b = b.data.ptr,
            .c = c.data.ptr,
            .start_i = 0,
            .end_i = M,
            .K = K,
            .N = N,
        };
        matmulWorkerTask(&payload);
    }

    c.toDevice();
    return Dynamic.initNone();
}

pub fn reduce_sum(buf_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(buf.size, @as(usize, @intCast(n_dyn.value.i64_type))) else buf.size;

    const Vector8f = @Vector(8, f32);
    var acc: Vector8f = @splat(0.0);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const v: Vector8f = buf.data[i..][0..8].*;
        acc += v;
    }
    var sum: f32 = @reduce(.Add, acc);
    while (i < n) : (i += 1) {
        sum += buf.data[i];
    }
    return Dynamic.initFloat(@floatCast(sum));
}

pub fn dot_product(a_dyn: Dynamic, b_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type) return error.TypeError;
    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, b.size);

    const Vector8f = @Vector(8, f32);
    var acc: Vector8f = @splat(0.0);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        acc += va * vb;
    }
    var sum: f32 = @reduce(.Add, acc);
    while (i < n) : (i += 1) {
        sum += a.data[i] * b.data[i];
    }
    return Dynamic.initFloat(@floatCast(sum));
}
