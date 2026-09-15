const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const GpuBuffer = struct {
    allocator: std.mem.Allocator,
    size: usize,
    data: []f32,
    dev_ptr: u64 = 0,
    is_device_allocated: bool = false,

    pub fn init(allocator: std.mem.Allocator, size: usize) !*GpuBuffer {
        const self = try allocator.create(GpuBuffer);
        const mem = try allocator.alloc(f32, size);
        @memset(mem, 0.0);

        self.* = GpuBuffer{
            .allocator = allocator,
            .size = size,
            .data = mem,
            .dev_ptr = 0,
            .is_device_allocated = false,
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
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    pub fn toDevice(self: *GpuBuffer) void {
        if (buffer_to_device_fn) |fn_ptr| {
            fn_ptr(self);
        }
    }

    pub fn toHost(self: *GpuBuffer) void {
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
        } else {
            return error.TypeError;
        }
        return Dynamic.initFloat(@floatCast(self.data[idx]));
    }

    pub fn setItem(self: *GpuBuffer, index: Dynamic, val: Dynamic) !void {
        var idx: usize = 0;
        if (index.value == .i64_type) {
            const i = index.value.i64_type;
            if (i < 0 or i >= self.size) return error.IndexError;
            idx = @intCast(i);
        } else {
            return error.TypeError;
        }

        var float_val: f32 = 0.0;
        switch (val.value) {
            .float_type => |f| float_val = @floatCast(f),
            .i64_type => |i| float_val = @floatFromInt(i),
            .i32_type => |i| float_val = @floatFromInt(i),
            .u32_type => |u| float_val = @floatFromInt(u),
            .u64_type => |u| float_val = @floatFromInt(u),
            else => return error.TypeError,
        }

        self.data[idx] = float_val;
        if (buffer_item_set_fn) |fn_ptr| {
            fn_ptr(self, idx, float_val);
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

    pub fn asDynamic(self: *GpuBuffer) Dynamic {
        return Dynamic{ .value = .{ .gpu_buffer_type = @ptrCast(self) } };
    }
};

// Global hook pointers set by sundapy_std/gpu.zig when loaded
pub var buffer_free_fn: ?*const fn (u64) void = null;
pub var buffer_to_device_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_to_host_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_item_set_fn: ?*const fn (*GpuBuffer, usize, f32) void = null;
pub var launch_fn: ?*const fn (std.mem.Allocator, Dynamic, usize, usize, usize, usize, usize, usize, []const Dynamic) anyerror!Dynamic = null;

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
    _ = ptr;
    if (std.mem.eql(u8, attr, "to_list")) {
        return Dynamic{ .value = .{ .func_type_slice = boundBufferToList } };
    } else if (std.mem.eql(u8, attr, "to_device")) {
        return Dynamic{ .value = .{ .func_type_slice = boundBufferToDevice } };
    } else if (std.mem.eql(u8, attr, "to_host")) {
        return Dynamic{ .value = .{ .func_type_slice = boundBufferToHost } };
    } else if (std.mem.eql(u8, attr, "copy_from_list")) {
        return Dynamic{ .value = .{ .func_type_slice = boundBufferCopyFromList } };
    } else if (std.mem.eql(u8, attr, "free")) {
        return Dynamic{ .value = .{ .func_type_slice = boundBufferFree } };
    }
    return Dynamic.initNone();
}

fn boundBufferToList(alloc_param: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = kwargs_unused;
    if (args.len > 0 and args[0].value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
        return buf.toList(alloc_param);
    }
    return Dynamic.initNone();
}

fn boundBufferToDevice(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len > 0 and args[0].value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
        buf.toDevice();
    }
    return Dynamic.initNone();
}

fn boundBufferToHost(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len > 0 and args[0].value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
        buf.toHost();
    }
    return Dynamic.initNone();
}

fn boundBufferCopyFromList(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len >= 2 and args[0].value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
        try buf.copyFromList(args[1]);
    }
    return Dynamic.initNone();
}

fn boundBufferFree(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len > 0 and args[0].value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
        buf.deinit();
    }
    return Dynamic.initNone();
}

pub fn printBuffer(ptr: *anyopaque) void {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    std.debug.print("<gpu.Buffer size={d} dev_ptr=0x{x}>", .{ buf.size, buf.dev_ptr });
}

pub fn createBoundKernel(kernel_fn: Dynamic, index: Dynamic) anyerror!Dynamic {
    var gx: usize = 1;
    var gy: usize = 1;
    var gz: usize = 1;
    var bx: usize = 1;
    var by: usize = 1;
    var bz: usize = 1;

    if (index.value == .list_type or index.value == .tuple_type) {
        const items = if (index.value == .list_type) index.value.list_type.items.items else index.value.tuple_type.items;
        if (items.len >= 1) {
            const g = items[0];
            if (g.value == .i64_type) {
                gx = @intCast(@max(1, g.value.i64_type));
            } else if (g.value == .list_type or g.value == .tuple_type) {
                const g_items = if (g.value == .list_type) g.value.list_type.items.items else g.value.tuple_type.items;
                if (g_items.len > 0 and g_items[0].value == .i64_type) gx = @intCast(@max(1, g_items[0].value.i64_type));
                if (g_items.len > 1 and g_items[1].value == .i64_type) gy = @intCast(@max(1, g_items[1].value.i64_type));
                if (g_items.len > 2 and g_items[2].value == .i64_type) gz = @intCast(@max(1, g_items[2].value.i64_type));
            }
        }
        if (items.len >= 2) {
            const b = items[1];
            if (b.value == .i64_type) {
                bx = @intCast(@max(1, b.value.i64_type));
            } else if (b.value == .list_type or b.value == .tuple_type) {
                const b_items = if (b.value == .list_type) b.value.list_type.items.items else b.value.tuple_type.items;
                if (b_items.len > 0 and b_items[0].value == .i64_type) bx = @intCast(@max(1, b_items[0].value.i64_type));
                if (b_items.len > 1 and b_items[1].value == .i64_type) by = @intCast(@max(1, b_items[1].value.i64_type));
                if (b_items.len > 2 and b_items[2].value == .i64_type) bz = @intCast(@max(1, b_items[2].value.i64_type));
            }
        }
    } else if (index.value == .i64_type) {
        gx = @intCast(@max(1, index.value.i64_type));
    }

    const bound = try std.heap.c_allocator.create(BoundKernel);
    bound.* = BoundKernel{
        .kernel_fn = kernel_fn,
        .grid_x = gx,
        .grid_y = gy,
        .grid_z = gz,
        .block_x = bx,
        .block_y = by,
        .block_z = bz,
    };

    return Dynamic{ .value = .{ .gpu_kernel_type = @ptrCast(bound) } };
}
