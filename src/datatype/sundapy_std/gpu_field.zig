const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const arena = @import("gpu_arena.zig");

// ============================================================================
// Multidimensional Field / NDArray HLA (Taichi / Numba Paradigm)
// ============================================================================

pub const Layout = enum {
    SoA, // Structure of Arrays
    AoS, // Array of Structures
};

pub const Field = struct {
    buffer: *GpuBuffer,
    shape: [4]usize = [_]usize{ 1, 1, 1, 1 },
    strides: [4]usize = [_]usize{ 1, 1, 1, 1 },
    ndim: usize = 1,
    total_elements: usize = 0,
    layout: Layout = .SoA,

    pub fn init(shape_slice: []const usize, layout: Layout) !*Field {
        if (shape_slice.len == 0 or shape_slice.len > 4) return error.InvalidDimension;

        var total: usize = 1;
        var f_shape = [_]usize{ 1, 1, 1, 1 };
        for (shape_slice, 0..) |dim, i| {
            f_shape[i] = @max(1, dim);
            total *= f_shape[i];
        }

        var f_strides = [_]usize{ 1, 1, 1, 1 };
        if (shape_slice.len == 1) {
            f_strides[0] = 1;
        } else if (shape_slice.len == 2) {
            f_strides[1] = 1;
            f_strides[0] = f_shape[1];
        } else if (shape_slice.len == 3) {
            f_strides[2] = 1;
            f_strides[1] = f_shape[2];
            f_strides[0] = f_shape[1] * f_shape[2];
        } else if (shape_slice.len == 4) {
            f_strides[3] = 1;
            f_strides[2] = f_shape[3];
            f_strides[1] = f_shape[2] * f_shape[3];
            f_strides[0] = f_shape[1] * f_shape[2] * f_shape[3];
        }

        const buf = try arena.getGlobalArena().allocBuffer(total);
        buf.shape = f_shape;
        buf.strides = f_strides;
        buf.ndim = shape_slice.len;

        const self = try std.heap.c_allocator.create(Field);
        self.* = Field{
            .buffer = buf,
            .shape = f_shape,
            .strides = f_strides,
            .ndim = shape_slice.len,
            .total_elements = total,
            .layout = layout,
        };
        return self;
    }

    pub inline fn computeIndex(self: *const Field, idx0: usize, idx1: usize, idx2: usize, idx3: usize) usize {
        return idx0 * self.strides[0] + idx1 * self.strides[1] + idx2 * self.strides[2] + idx3 * self.strides[3];
    }

    pub fn get(self: *Field, idx0: usize, idx1: usize, idx2: usize, idx3: usize) f32 {
        const idx = self.computeIndex(idx0, idx1, idx2, idx3);
        if (idx < self.buffer.data.len) {
            return self.buffer.data[idx];
        }
        return 0.0;
    }

    pub fn set(self: *Field, idx0: usize, idx1: usize, idx2: usize, idx3: usize, val: f32) void {
        const idx = self.computeIndex(idx0, idx1, idx2, idx3);
        if (idx < self.buffer.data.len) {
            self.buffer.data[idx] = val;
        }
    }

    pub fn fill(self: *Field, val: f32) void {
        @memset(self.buffer.data, val);
        self.buffer.toDevice();
    }

    pub fn to_raw_handle(self: *Field) u64 {
        return self.buffer.dev_ptr;
    }

    pub fn to_list(self: *Field) !Dynamic {
        return self.buffer.toList(std.heap.c_allocator);
    }
};

pub fn create_field(args: []const Dynamic) anyerror!Dynamic {
    if (args.len == 0) return error.TypeError;
    var shape_buf: [4]usize = [_]usize{ 1, 1, 1, 1 };
    var ndim: usize = 0;

    const shape_arg = args[0];
    if (shape_arg.value == .i64_type) {
        shape_buf[0] = @intCast(@max(1, shape_arg.value.i64_type));
        ndim = 1;
    } else if (shape_arg.value == .list_type or shape_arg.value == .tuple_type) {
        const items = if (shape_arg.value == .list_type) shape_arg.value.list_type.items.items else shape_arg.value.tuple_type.items;
        ndim = @min(4, items.len);
        for (0..ndim) |i| {
            if (items[i].value == .i64_type) {
                shape_buf[i] = @intCast(@max(1, items[i].value.i64_type));
            }
        }
    }

    var layout = Layout.SoA;
    if (args.len > 1 and args[1].value == .str_type) {
        if (std.mem.eql(u8, args[1].value.str_type, "AoS")) {
            layout = .AoS;
        }
    }

    const f = try Field.init(shape_buf[0..ndim], layout);
    return f.buffer.asDynamic();
}
