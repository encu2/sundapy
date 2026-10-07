const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

// ============================================================================
// Lock-Free Hardware Atomic Primitives (Numba CUDA & Taichi Style)
// ============================================================================

fn resolveBufferIndex(buf: *GpuBuffer, index: Dynamic) !usize {
    if (index.value == .i64_type) {
        const i = index.value.i64_type;
        if (i < 0 or i >= buf.size) return error.IndexError;
        return @intCast(i);
    } else if (index.value == .tuple_type or index.value == .list_type) {
        const items = if (index.value == .tuple_type) index.value.tuple_type.items else index.value.list_type.items.items;
        if (buf.ndim > 0 and items.len == buf.ndim) {
            var offset: usize = 0;
            for (items, 0..) |item, dim_i| {
                if (item.value != .i64_type) return error.TypeError;
                const coord = item.value.i64_type;
                if (coord < 0 or coord >= buf.shape[dim_i]) return error.IndexError;
                offset += @as(usize, @intCast(coord)) * buf.strides[dim_i];
            }
            if (offset >= buf.size) return error.IndexError;
            return offset;
        }
    }
    return error.TypeError;
}

fn extractFloat(val: Dynamic) !f32 {
    return switch (val.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        .i32_type => |i| @floatFromInt(i),
        else => error.TypeError,
    };
}

pub fn atomic_add(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const add_val = try extractFloat(val_dyn);

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    var old_u = @as(*const volatile u32, u32_ptr).*;
    while (true) {
        const old_f: f32 = @bitCast(old_u);
        const new_f: f32 = old_f + add_val;
        const new_u: u32 = @bitCast(new_f);
        if (@cmpxchgStrong(u32, u32_ptr, old_u, new_u, .monotonic, .monotonic)) |cur| {
            old_u = cur;
        } else {
            if (gpu_types.buffer_item_set_fn) |fn_ptr| {
                fn_ptr(buf, idx, new_f);
            }
            return Dynamic.initFloat(@floatCast(old_f));
        }
    }
}

pub fn atomic_sub(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const sub_val = try extractFloat(val_dyn);

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    var old_u = @as(*const volatile u32, u32_ptr).*;
    while (true) {
        const old_f: f32 = @bitCast(old_u);
        const new_f: f32 = old_f - sub_val;
        const new_u: u32 = @bitCast(new_f);
        if (@cmpxchgStrong(u32, u32_ptr, old_u, new_u, .monotonic, .monotonic)) |cur| {
            old_u = cur;
        } else {
            if (gpu_types.buffer_item_set_fn) |fn_ptr| {
                fn_ptr(buf, idx, new_f);
            }
            return Dynamic.initFloat(@floatCast(old_f));
        }
    }
}

pub fn atomic_min(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const cmp_val = try extractFloat(val_dyn);

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    var old_u = @as(*const volatile u32, u32_ptr).*;
    while (true) {
        const old_f: f32 = @bitCast(old_u);
        if (old_f <= cmp_val) return Dynamic.initFloat(@floatCast(old_f));
        const new_u: u32 = @bitCast(cmp_val);
        if (@cmpxchgStrong(u32, u32_ptr, old_u, new_u, .monotonic, .monotonic)) |cur| {
            old_u = cur;
        } else {
            if (gpu_types.buffer_item_set_fn) |fn_ptr| {
                fn_ptr(buf, idx, cmp_val);
            }
            return Dynamic.initFloat(@floatCast(old_f));
        }
    }
}

pub fn atomic_max(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const cmp_val = try extractFloat(val_dyn);

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    var old_u = @as(*const volatile u32, u32_ptr).*;
    while (true) {
        const old_f: f32 = @bitCast(old_u);
        if (old_f >= cmp_val) return Dynamic.initFloat(@floatCast(old_f));
        const new_u: u32 = @bitCast(cmp_val);
        if (@cmpxchgStrong(u32, u32_ptr, old_u, new_u, .monotonic, .monotonic)) |cur| {
            old_u = cur;
        } else {
            if (gpu_types.buffer_item_set_fn) |fn_ptr| {
                fn_ptr(buf, idx, cmp_val);
            }
            return Dynamic.initFloat(@floatCast(old_f));
        }
    }
}

pub fn atomic_and(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const mask: u32 = if (val_dyn.value == .i64_type) @truncate(@as(u64, @bitCast(val_dyn.value.i64_type))) else 0;

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    const old_val = @atomicRmw(u32, u32_ptr, .And, mask, .monotonic);
    return Dynamic.initInt(@intCast(old_val));
}

pub fn atomic_or(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const mask: u32 = if (val_dyn.value == .i64_type) @truncate(@as(u64, @bitCast(val_dyn.value.i64_type))) else 0;

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    const old_val = @atomicRmw(u32, u32_ptr, .Or, mask, .monotonic);
    return Dynamic.initInt(@intCast(old_val));
}

pub fn atomic_xor(buf_dyn: Dynamic, index_dyn: Dynamic, val_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);
    const mask: u32 = if (val_dyn.value == .i64_type) @truncate(@as(u64, @bitCast(val_dyn.value.i64_type))) else 0;

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    const old_val = @atomicRmw(u32, u32_ptr, .Xor, mask, .monotonic);
    return Dynamic.initInt(@intCast(old_val));
}

pub fn atomic_cas(buf_dyn: Dynamic, index_dyn: Dynamic, expected_dyn: Dynamic, desired_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const idx = try resolveBufferIndex(buf, index_dyn);

    const exp_f = try extractFloat(expected_dyn);
    const des_f = try extractFloat(desired_dyn);
    const exp_u: u32 = @bitCast(exp_f);
    const des_u: u32 = @bitCast(des_f);

    const u32_ptr: *align(@alignOf(u32)) u32 = @ptrCast(&buf.data[idx]);
    if (@cmpxchgStrong(u32, u32_ptr, exp_u, des_u, .monotonic, .monotonic)) |cur| {
        const cur_f: f32 = @bitCast(cur);
        return Dynamic.initFloat(@floatCast(cur_f));
    }
    if (gpu_types.buffer_item_set_fn) |fn_ptr| {
        fn_ptr(buf, idx, des_f);
    }
    return Dynamic.initFloat(@floatCast(exp_f));
}
