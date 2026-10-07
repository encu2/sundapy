const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const GpuDtype = enum {
    f32,
    f64,
    i32,
    i64,
    u8,

    pub fn sizeOf(self: GpuDtype) usize {
        return switch (self) {
            .f32 => 4,
            .f64 => 8,
            .i32 => 4,
            .i64 => 8,
            .u8 => 1,
        };
    }

    pub fn name(self: GpuDtype) []const u8 {
        return switch (self) {
            .f32 => "f32",
            .f64 => "f64",
            .i32 => "i32",
            .i64 => "i64",
            .u8 => "u8",
        };
    }

    pub fn fromString(str: []const u8) GpuDtype {
        if (std.mem.eql(u8, str, "f64") or std.mem.eql(u8, str, "float64")) return .f64;
        if (std.mem.eql(u8, str, "i32") or std.mem.eql(u8, str, "int32")) return .i32;
        if (std.mem.eql(u8, str, "i64") or std.mem.eql(u8, str, "int64")) return .i64;
        if (std.mem.eql(u8, str, "u8") or std.mem.eql(u8, str, "uint8") or std.mem.eql(u8, str, "byte")) return .u8;
        return .f32;
    }
};

pub const GpuBuffer = struct {
    allocator: std.mem.Allocator,
    size: usize,
    data: []f32,
    dtype: GpuDtype = .f32,
    dev_ptr: u64 = 0,
    is_device_allocated: bool = false,
    is_managed: bool = false,

    shape: [4]usize = [_]usize{ 0, 0, 0, 0 },
    strides: [4]usize = [_]usize{ 1, 1, 1, 1 },
    ndim: usize = 1,
    last_method: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator, size: usize) !*GpuBuffer {
        return initWithDtype(allocator, size, .f32);
    }

    pub fn initWithDtype(allocator: std.mem.Allocator, size: usize, dt: GpuDtype) !*GpuBuffer {
        const self = try allocator.create(GpuBuffer);
        const mem = try allocator.alloc(f32, size);
        @memset(mem, 0.0);

        self.* = GpuBuffer{
            .allocator = allocator,
            .size = size,
            .data = mem,
            .dtype = dt,
            .dev_ptr = 0,
            .is_device_allocated = false,
            .is_managed = false,
            .shape = [_]usize{ size, 1, 1, 1 },
            .strides = [_]usize{ 1, 1, 1, 1 },
            .ndim = 1,
        };
        return self;
    }

    pub fn deinit(self: *GpuBuffer) void {
        if (buffer_free_fn) |free_fn| {
            if (self.is_device_allocated and self.dev_ptr != 0) {
                free_fn(self.dev_ptr);
                self.dev_ptr = 0;
                self.is_device_allocated = false;
            }
        }
        if (!self.is_managed) {
            self.allocator.free(self.data);
        }
        self.allocator.destroy(self);
    }

    pub fn toDevice(self: *GpuBuffer) void {
        if (self.is_managed) {
            if (buffer_sync_fn) |sfn| sfn();
            return;
        }
        if (buffer_to_device_fn) |fn_ptr| {
            fn_ptr(self);
        }
    }

    pub fn toHost(self: *GpuBuffer) void {
        if (self.is_managed) {
            if (buffer_sync_fn) |sfn| sfn();
            return;
        }
        if (buffer_to_host_fn) |fn_ptr| {
            fn_ptr(self);
        }
    }

    pub fn getItem(self: *GpuBuffer, index: Dynamic) !Dynamic {
        var idx: usize = 0;
        if (index.value == .i64_type) {
            const i = index.value.i64_type;
            if (i < 0 or i >= self.size) return error.IndexError;
            idx = @intCast(i);
        } else if (index.value == .tuple_type or index.value == .list_type) {
            const items = if (index.value == .tuple_type) index.value.tuple_type.items else index.value.list_type.items.items;
            if (self.ndim > 0 and items.len == self.ndim) {
                var offset: usize = 0;
                for (items, 0..) |item, dim_i| {
                    if (item.value != .i64_type) return error.TypeError;
                    const coord = item.value.i64_type;
                    if (coord < 0 or coord >= self.shape[dim_i]) return error.IndexError;
                    offset += @as(usize, @intCast(coord)) * self.strides[dim_i];
                }
                if (offset >= self.size) return error.IndexError;
                idx = offset;
            } else {
                return error.IndexError;
            }
        } else {
            return error.TypeError;
        }
        if (self.dtype == .i32) {
            const s: [*]const i32 = @ptrCast(@alignCast(self.data.ptr));
            return Dynamic.initInt(@intCast(s[idx]));
        } else if (self.dtype == .u8) {
            const s: [*]const u8 = @ptrCast(self.data.ptr);
            return Dynamic.initInt(@intCast(s[idx]));
        } else if (self.dtype == .i64) {
            const s: [*]const i64 = @ptrCast(@alignCast(self.data.ptr));
            return Dynamic.initInt(s[idx]);
        }
        return Dynamic.initFloat(@floatCast(self.data[idx]));
    }

    pub fn setItem(self: *GpuBuffer, index: Dynamic, val: Dynamic) !void {
        var idx: usize = 0;
        if (index.value == .i64_type) {
            const i = index.value.i64_type;
            if (i < 0 or i >= self.size) return error.IndexError;
            idx = @intCast(i);
        } else if (index.value == .tuple_type or index.value == .list_type) {
            const items = if (index.value == .tuple_type) index.value.tuple_type.items else index.value.list_type.items.items;
            if (self.ndim > 0 and items.len == self.ndim) {
                var offset: usize = 0;
                for (items, 0..) |item, dim_i| {
                    if (item.value != .i64_type) return error.TypeError;
                    const coord = item.value.i64_type;
                    if (coord < 0 or coord >= self.shape[dim_i]) return error.IndexError;
                    offset += @as(usize, @intCast(coord)) * self.strides[dim_i];
                }
                if (offset >= self.size) return error.IndexError;
                idx = offset;
            } else {
                return error.IndexError;
            }
        } else {
            return error.TypeError;
        }

        if (self.dtype == .i32) {
            const s: [*]i32 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = switch (val.value) { .i64_type => |v| @intCast(v), .float_type => |v| @intFromFloat(v), else => 0 };
        } else if (self.dtype == .u8) {
            const s: [*]u8 = @ptrCast(self.data.ptr);
            s[idx] = switch (val.value) { .i64_type => |v| @intCast(v & 0xFF), .float_type => |v| @intFromFloat(@min(255.0, @max(0.0, v))), else => 0 };
        } else if (self.dtype == .i64) {
            const s: [*]i64 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = switch (val.value) { .i64_type => |v| v, .float_type => |v| @intFromFloat(v), else => 0 };
        } else {
            const float_val: f32 = switch (val.value) {
                .float_type => |f| @floatCast(f),
                .i64_type => |i| @floatFromInt(i),
                .i32_type => |i| @floatFromInt(i),
                .u32_type => |u| @floatFromInt(u),
                .u64_type => |u| @floatFromInt(u),
                else => return error.TypeError,
            };

            self.data[idx] = float_val;
            if (buffer_item_set_fn) |fn_ptr| {
                fn_ptr(self, idx, float_val);
            }
        }
    }

    pub fn toList(self: *GpuBuffer, allocator_mem: std.mem.Allocator) !Dynamic {
        self.toHost();
        var list = std.ArrayList(Dynamic).empty;
        for (self.data) |v| {
            try list.append(allocator_mem, Dynamic.initFloat(@floatCast(v)));
        }
        return Dynamic.initList(list);
    }

    pub fn copyFromList(self: *GpuBuffer, list_dyn: Dynamic) !void {
        if (list_dyn.value != .list_type) return error.TypeError;
        const items = list_dyn.value.list_type.items.items;
        const count = @min(self.size, items.len);
        for (0..count) |i| {
            switch (items[i].value) {
                .float_type => |f| self.data[i] = @floatCast(f),
                .i64_type => |v| self.data[i] = @floatFromInt(v),
                else => {},
            }
        }
        self.toDevice();
    }

    pub fn callMethod(self: *GpuBuffer, alloc_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        if (std.mem.eql(u8, self.last_method, "fill")) {
            var val: f32 = 0.0;
            if (args.len > 0) {
                if (args[0].value == .float_type) {
                    val = @floatCast(args[0].value.float_type);
                } else if (args[0].value == .i64_type) {
                    val = @floatFromInt(args[0].value.i64_type);
                }
            }
            if (args.len >= 2 and args[0].value == .gpu_buffer_type) {
                if (args[1].value == .float_type) {
                    val = @floatCast(args[1].value.float_type);
                } else if (args[1].value == .i64_type) {
                    val = @floatFromInt(args[1].value.i64_type);
                }
            }
            @memset(self.data, val);
            self.toDevice();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, self.last_method, "to_raw_handle")) {
            var dict = Dynamic.initDict(std.heap.c_allocator);
            try dict.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(self.dev_ptr)));
            try dict.value.dict_type.put(Dynamic.initStr("byte_size"), Dynamic.initInt(@intCast(self.size * @sizeOf(f32))));
            try dict.value.dict_type.put(Dynamic.initStr("stride"), Dynamic.initInt(@sizeOf(f32)));
            try dict.value.dict_type.put(Dynamic.initStr("is_managed"), Dynamic.initBool(self.is_managed));
            try dict.value.dict_type.put(Dynamic.initStr("is_device"), Dynamic.initBool(self.is_device_allocated));
            return dict;
        } else if (std.mem.eql(u8, self.last_method, "to_list")) {
            return self.toList(alloc_mem);
        } else if (std.mem.eql(u8, self.last_method, "to_device")) {
            self.toDevice();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, self.last_method, "to_host")) {
            self.toHost();
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, self.last_method, "copy_from_list")) {
            const list_arg = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else Dynamic.initNone();
            try self.copyFromList(list_arg);
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, self.last_method, "free")) {
            self.deinit();
            return Dynamic.initNone();
        }
        return Dynamic.initNone();
    }

    pub fn asDynamic(self: *GpuBuffer) Dynamic {
        return Dynamic{ .value = .{ .gpu_buffer_type = @ptrCast(self) } };
    }
};

// Global hook pointers set by sundapy_std/gpu.zig when loaded
pub var buffer_free_fn: ?*const fn (u64) void = null;
pub var buffer_to_device_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_to_host_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_item_set_fn: ?*const fn (*GpuBuffer, usize, f32) void = null;
pub var buffer_sync_fn: ?*const fn () void = null;
pub const LaunchFn = *const fn (std.mem.Allocator, Dynamic, usize, usize, usize, usize, usize, usize, []const Dynamic) anyerror!Dynamic;
pub var launch_fn: ?LaunchFn = null;

pub const BoundKernel = struct {
    kernel_fn: Dynamic,
    grid_x: usize,
    grid_y: usize,
    grid_z: usize,
    block_x: usize,
    block_y: usize,
    block_z: usize,

    pub fn call(self: *BoundKernel, allocator_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        if (launch_fn) |lfn| {
            return lfn(allocator_mem, self.kernel_fn, self.grid_x, self.grid_y, self.grid_z, self.block_x, self.block_y, self.block_z, args);
        }
        return Dynamic.initNone();
    }
};

pub fn bufferLen(ptr: *anyopaque) usize {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    return buf.size;
}

pub fn bufferGetItem(ptr: *anyopaque, index: Dynamic) anyerror!Dynamic {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    return buf.getItem(index);
}

pub fn bufferSetItem(ptr: *anyopaque, index: Dynamic, val: Dynamic) anyerror!void {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    return buf.setItem(index, val);
}

pub fn bufferGetAttribute(ptr: *anyopaque, attr: []const u8) Dynamic {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    if (std.mem.eql(u8, attr, "size")) {
        return Dynamic.initInt(@intCast(buf.size));
    } else if (std.mem.eql(u8, attr, "ndim")) {
        return Dynamic.initInt(@intCast(buf.ndim));
    } else if (std.mem.eql(u8, attr, "dev_ptr") or std.mem.eql(u8, attr, "ptr")) {
        return Dynamic.initInt(@intCast(buf.dev_ptr));
    } else if (std.mem.eql(u8, attr, "shape")) {
        var shape_list = std.ArrayList(Dynamic).empty;
        for (0..buf.ndim) |i| {
            shape_list.append(std.heap.c_allocator, Dynamic.initInt(@intCast(buf.shape[i]))) catch {};
        }
        return Dynamic.initList(shape_list);
    } else if (std.mem.eql(u8, attr, "dtype")) {
        return Dynamic.initStr(buf.dtype.name());
    } else if (std.mem.eql(u8, attr, "itemsize")) {
        return Dynamic.initInt(@intCast(buf.dtype.sizeOf()));
    } else if (std.mem.eql(u8, attr, "nbytes")) {
        return Dynamic.initInt(@intCast(buf.size * buf.dtype.sizeOf()));
    } else if (std.mem.eql(u8, attr, "to_raw_handle") or
        std.mem.eql(u8, attr, "fill") or
        std.mem.eql(u8, attr, "to_list") or
        std.mem.eql(u8, attr, "to_device") or
        std.mem.eql(u8, attr, "to_host") or
        std.mem.eql(u8, attr, "copy_from_list") or
        std.mem.eql(u8, attr, "free"))
    {
        buf.last_method = attr;
        return buf.asDynamic();
    }
    return Dynamic.initNone();
}

pub fn printBuffer(ptr: *anyopaque) void {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    std.debug.print("<gpu.Buffer size={d} dev_ptr=0x{x}>", .{ buf.size, buf.dev_ptr });
}

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
