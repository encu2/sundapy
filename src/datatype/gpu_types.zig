const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const kernel = @import("gpu_kernel_types.zig");
const ops = @import("gpu_buffer_ops.zig");

pub const BoundKernel = kernel.BoundKernel;
pub const createBoundKernel = kernel.createBoundKernel;
pub const LaunchFn = kernel.LaunchFn;
pub var launch_fn: ?LaunchFn = null;

pub var buffer_free_fn: ?*const fn (u64) void = null;
pub var buffer_to_device_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_to_host_fn: ?*const fn (*GpuBuffer) void = null;
pub var buffer_item_set_fn: ?*const fn (*GpuBuffer, usize, f32) void = null;
pub var buffer_sync_fn: ?*const fn () void = null;
pub var buffer_decompress_fn: ?*const fn (*GpuBuffer) anyerror!*GpuBuffer = null;
pub var buffer_slab_free_fn: ?*const fn ([*]u8) void = null;
pub var buffer_sparse_deinit_fn: ?*const fn (*anyopaque) void = null;
pub var buffer_sparse_get_fn: ?*const fn (*anyopaque, usize) anyerror!f32 = null;
pub var buffer_sparse_set_fn: ?*const fn (*anyopaque, usize, f32) anyerror!void = null;
pub var buffer_sparse_stats_fn: ?*const fn (*anyopaque) anyerror!Dynamic = null;
pub var buffer_sparse_commit_fn: ?*const fn (*anyopaque, usize) anyerror!void = null;
pub var buffer_sparse_decommit_fn: ?*const fn (*anyopaque, usize) void = null;
pub var buffer_sparse_is_committed_fn: ?*const fn (*anyopaque, usize) bool = null;
pub var buffer_sparse_compress_idle_fn: ?*const fn (*anyopaque) anyerror!usize = null;
pub var buffer_compress_hook: ?*const fn (*GpuBuffer, []const u8) anyerror!void = null;
pub var buffer_decompress_hook: ?*const fn (*GpuBuffer) anyerror!void = null;
pub var budget_register_fn: ?*const fn (*GpuBuffer) void = null;
pub var budget_unregister_fn: ?*const fn (*GpuBuffer) void = null;
pub const PinnedAllocResult = struct {
    host_ptr: ?[*]u8 = null,
    dev_ptr: u64 = 0,
};
pub var buffer_pinned_alloc_fn: ?*const fn (usize) PinnedAllocResult = null;
pub var buffer_pinned_free_fn: ?*const fn (?*anyopaque) void = null;
pub var buffer_copy_fn: ?*const fn (*GpuBuffer, *GpuBuffer) bool = null;
pub var buffer_graph_deinit_fn: ?*const fn (*anyopaque) void = null;
pub var buffer_graph_call_fn: ?*const fn (*anyopaque, []const u8, std.mem.Allocator, []const Dynamic) anyerror!Dynamic = null;
pub var buffer_graph_getattr_fn: ?*const fn (*anyopaque, []const u8) ?Dynamic = null;
pub var buffer_spmv_fn: ?*const fn (*GpuBuffer, *GpuBuffer) anyerror!*GpuBuffer = null;

pub const GpuDtype = enum {
    f32,
    f64,
    i32,
    i64,
    u8,
    f16,
    bf16,
    int8,
    fp8_e4m3,
    fp8_e5m2,
    fp4_e2m1,

    pub fn sizeOf(self: GpuDtype) usize {
        return switch (self) {
            .f32 => 4,
            .f64 => 8,
            .i32 => 4,
            .i64 => 8,
            .u8, .int8, .fp8_e4m3, .fp8_e5m2, .fp4_e2m1 => 1,
            .f16, .bf16 => 2,
        };
    }

    pub fn name(self: GpuDtype) []const u8 {
        return switch (self) {
            .f32 => "f32",
            .f64 => "f64",
            .i32 => "i32",
            .i64 => "i64",
            .u8 => "u8",
            .f16 => "f16",
            .bf16 => "bf16",
            .int8 => "int8",
            .fp8_e4m3 => "fp8_e4m3",
            .fp8_e5m2 => "fp8_e5m2",
            .fp4_e2m1 => "fp4_e2m1",
        };
    }

    pub fn fromString(str: []const u8) GpuDtype {
        if (std.mem.eql(u8, str, "f64") or std.mem.eql(u8, str, "float64")) return .f64;
        if (std.mem.eql(u8, str, "i32") or std.mem.eql(u8, str, "int32")) return .i32;
        if (std.mem.eql(u8, str, "i64") or std.mem.eql(u8, str, "int64")) return .i64;
        if (std.mem.eql(u8, str, "u8") or std.mem.eql(u8, str, "uint8") or std.mem.eql(u8, str, "byte")) return .u8;
        if (std.mem.eql(u8, str, "f16") or std.mem.eql(u8, str, "float16") or std.mem.eql(u8, str, "half")) return .f16;
        if (std.mem.eql(u8, str, "bf16") or std.mem.eql(u8, str, "bfloat16")) return .bf16;
        if (std.mem.eql(u8, str, "int8") or std.mem.eql(u8, str, "i8")) return .int8;
        if (std.mem.eql(u8, str, "fp8") or std.mem.eql(u8, str, "fp8_e4m3") or std.mem.eql(u8, str, "e4m3")) return .fp8_e4m3;
        if (std.mem.eql(u8, str, "fp8_e5m2") or std.mem.eql(u8, str, "e5m2")) return .fp8_e5m2;
        if (std.mem.eql(u8, str, "fp4") or std.mem.eql(u8, str, "fp4_e2m1") or std.mem.eql(u8, str, "e2m1")) return .fp4_e2m1;
        return .f32;
    }
};

pub const CompressionInfo = struct {
    scheme: []const u8 = "none",
    original_bytes: usize = 0,
    compressed_bytes: usize = 0,
    compression_ratio: f32 = 1.0,
    savings_pct: f32 = 0.0,
    is_compressed: bool = false,
    scale: f32 = 1.0,
    zero_point: i8 = 0,
    rows: usize = 0,
    cols: usize = 0,
    nnz: usize = 0,
    raw_payload: ?[]u8 = null,
    sparse_ptr: ?*anyopaque = null,
    compact_ptr: ?*anyopaque = null,
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
    compression_info: ?*CompressionInfo = null,
    is_suballocated: bool = false,
    is_sparse_vm: bool = false,
    is_pinned: bool = false,
    is_graph: bool = false,
    sparse_vm_ptr: ?*anyopaque = null,
    graph_ptr: ?*anyopaque = null,
    slab_slot_ptr: ?*anyopaque = null,

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
            .shape = [_]usize{ size, 1, 1, 1 },
            .strides = [_]usize{ 1, 1, 1, 1 },
            .ndim = 1,
        };
        return self;
    }

    pub fn initPinned(allocator: std.mem.Allocator, size: usize, dt: GpuDtype) !*GpuBuffer {
        const item_bytes = dt.sizeOf();
        const alloc_bytes = @max(size * item_bytes, size * @sizeOf(f32));
        var host_slice: []f32 = undefined;
        var pinned = false;
        var dptr: u64 = 0;

        if (buffer_pinned_alloc_fn) |palloc| {
            const res = palloc(alloc_bytes);
            if (res.host_ptr) |raw| {
                @memset(raw[0..alloc_bytes], 0);
                const f_ptr: [*]f32 = @ptrCast(@alignCast(raw));
                host_slice = f_ptr[0..size];
                pinned = true;
                dptr = res.dev_ptr;
            }
        }
        if (!pinned) {
            const float_count = (alloc_bytes + @sizeOf(f32) - 1) / @sizeOf(f32);
            const mem = try allocator.alloc(f32, float_count);
            @memset(mem, 0.0);
            host_slice = mem[0..size];
        }
        const self = try allocator.create(GpuBuffer);
        self.* = GpuBuffer{
            .allocator = allocator,
            .size = size,
            .data = host_slice,
            .dtype = dt,
            .dev_ptr = dptr,
            .is_device_allocated = (dptr != 0),
            .is_pinned = pinned,
            .shape = [_]usize{ size, 1, 1, 1 },
            .strides = [_]usize{ 1, 1, 1, 1 },
            .ndim = 1,
        };
        return self;
    }

    pub fn deinit(self: *GpuBuffer) void {
        if (budget_unregister_fn) |bunreg| {
            bunreg(self);
        }
        if (self.is_sparse_vm and self.sparse_vm_ptr != null) {
            if (buffer_sparse_deinit_fn) |sdeinit| {
                sdeinit(self.sparse_vm_ptr.?);
            }
            self.sparse_vm_ptr = null;
        }
        if (self.is_graph and self.graph_ptr != null) {
            if (buffer_graph_deinit_fn) |gdeinit| {
                gdeinit(self.graph_ptr.?);
            }
            self.graph_ptr = null;
        }
        if (buffer_free_fn) |free_fn| {
            if (!self.is_sparse_vm and !self.is_pinned and self.is_device_allocated and self.dev_ptr != 0) {
                free_fn(self.dev_ptr);
                self.dev_ptr = 0;
                self.is_device_allocated = false;
            }
        }
        if (self.compression_info) |ci| {
            if (ci.raw_payload) |p| self.allocator.free(p);
            self.allocator.destroy(ci);
            self.compression_info = null;
        }
        if (self.is_pinned) {
            if (buffer_pinned_free_fn) |pfree| {
                pfree(self.data.ptr);
            }
        } else if (self.is_suballocated) {
            if (buffer_slab_free_fn) |sfree| {
                if (self.data.len > 0) sfree(@ptrCast(self.data.ptr));
            }
        } else if (!self.is_managed and !self.is_sparse_vm) {
            self.allocator.free(self.data);
        }
        self.allocator.destroy(self);
    }

    pub fn toDevice(self: *GpuBuffer) void {
        if (self.is_managed or self.is_pinned or self.is_sparse_vm) {
            if (buffer_sync_fn) |sfn| sfn();
            return;
        }
        if (buffer_to_device_fn) |fn_ptr| fn_ptr(self);
    }

    pub fn toHost(self: *GpuBuffer) void {
        if (self.is_managed or self.is_pinned or self.is_sparse_vm) {
            if (buffer_sync_fn) |sfn| sfn();
            return;
        }
        if (buffer_to_host_fn) |fn_ptr| fn_ptr(self);
    }

    pub fn getItem(self: *GpuBuffer, index: Dynamic) !Dynamic {
        return ops.getItem(self, index);
    }

    pub fn setItem(self: *GpuBuffer, index: Dynamic, val: Dynamic) !void {
        return ops.setItem(self, index, val);
    }

    pub fn toList(self: *GpuBuffer, allocator_mem: std.mem.Allocator) !Dynamic {
        self.toHost();
        var list = std.ArrayList(Dynamic).empty;
        for (0..self.size) |i| {
            const item = try self.getItem(Dynamic.initInt(@intCast(i)));
            try list.append(allocator_mem, item);
        }
        return Dynamic.initList(list);
    }

    pub fn copyFromList(self: *GpuBuffer, list_dyn: Dynamic) !void {
        return ops.copyFromList(self, list_dyn);
    }

    pub fn callMethod(self: *GpuBuffer, alloc_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        return ops.callMethod(self, alloc_mem, args);
    }

    pub fn asDynamic(self: *GpuBuffer) Dynamic {
        return Dynamic{ .value = .{ .gpu_buffer_type = @ptrCast(self) } };
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
    if (std.mem.eql(u8, attr, "size")) return Dynamic.initInt(@intCast(buf.size));
    if (std.mem.eql(u8, attr, "ndim")) return Dynamic.initInt(@intCast(buf.ndim));
    if (std.mem.eql(u8, attr, "dev_ptr") or std.mem.eql(u8, attr, "ptr")) return Dynamic.initInt(@intCast(buf.dev_ptr));
    if (std.mem.eql(u8, attr, "dtype")) return Dynamic.initStr(buf.dtype.name());
    if (std.mem.eql(u8, attr, "itemsize")) return Dynamic.initInt(@intCast(buf.dtype.sizeOf()));
    if (std.mem.eql(u8, attr, "nbytes")) return Dynamic.initInt(@intCast(buf.size * buf.dtype.sizeOf()));

    // Sparse VM & Slab & Graph attributes
    if (buf.is_graph and buf.graph_ptr != null) {
        if (buffer_graph_getattr_fn) |gafn| {
            if (gafn(buf.graph_ptr.?, attr)) |res| return res;
        }
    }
    if (std.mem.eql(u8, attr, "is_pinned")) return Dynamic.initBool(buf.is_pinned);
    if (std.mem.eql(u8, attr, "is_sparse_vm")) return Dynamic.initBool(buf.is_sparse_vm);
    if (std.mem.eql(u8, attr, "is_graph")) return Dynamic.initBool(buf.is_graph);
    if (std.mem.eql(u8, attr, "is_suballocated")) return Dynamic.initBool(buf.is_suballocated);
    if (std.mem.eql(u8, attr, "virtual_size")) return Dynamic.initInt(@intCast(buf.size * buf.dtype.sizeOf()));

    // Compression attributes
    if (std.mem.eql(u8, attr, "is_compressed")) return Dynamic.initBool(if (buf.compression_info) |ci| ci.is_compressed else false);
    if (std.mem.eql(u8, attr, "compression_ratio")) return Dynamic.initFloat(if (buf.compression_info) |ci| ci.compression_ratio else 1.0);
    if (std.mem.eql(u8, attr, "savings_pct")) return Dynamic.initFloat(if (buf.compression_info) |ci| ci.savings_pct else 0.0);
    if (std.mem.eql(u8, attr, "compressed_bytes")) return Dynamic.initInt(@intCast(if (buf.compression_info) |ci| ci.compressed_bytes else buf.size * buf.dtype.sizeOf()));
    if (std.mem.eql(u8, attr, "original_bytes")) return Dynamic.initInt(@intCast(if (buf.compression_info) |ci| ci.original_bytes else buf.size * buf.dtype.sizeOf()));
    if (std.mem.eql(u8, attr, "scheme") or std.mem.eql(u8, attr, "compression_scheme")) return Dynamic.initStr(if (buf.compression_info) |ci| ci.scheme else "none");
    if (std.mem.eql(u8, attr, "nnz")) return Dynamic.initInt(@intCast(if (buf.compression_info) |ci| ci.nnz else buf.size));

    if (std.mem.eql(u8, attr, "shape")) {
        var shape_list = std.ArrayList(Dynamic).empty;
        for (0..buf.ndim) |i| shape_list.append(std.heap.c_allocator, Dynamic.initInt(@intCast(buf.shape[i]))) catch {};
        return Dynamic.initList(shape_list);
    }
    if (ops.isBufferMethod(attr)) {
        buf.last_method = attr;
        return buf.asDynamic();
    }
    return Dynamic.initNone();
}

pub fn printBuffer(ptr: *anyopaque) void {
    const buf: *GpuBuffer = @ptrCast(@alignCast(ptr));
    std.debug.print("<gpu.Buffer size={d} dtype={s} dev_ptr=0x{x}>", .{ buf.size, buf.dtype.name(), buf.dev_ptr });
}

fn recalculateStrides(buf: *GpuBuffer) void {
    if (buf.ndim == 0) return;
    buf.strides[buf.ndim - 1] = 1;
    var s_idx: usize = buf.ndim - 1;
    while (s_idx > 0) {
        s_idx -= 1;
        buf.strides[s_idx] = buf.strides[s_idx + 1] * buf.shape[s_idx + 1];
    }
}

pub fn setBufferAttribute(buf: *GpuBuffer, attr: []const u8, val: Dynamic) bool {
    if (std.mem.eql(u8, attr, "ndim")) {
        if (val.value == .i64_type) {
            buf.ndim = @intCast(@max(1, @min(4, val.value.i64_type)));
            return true;
        }
    } else if (std.mem.eql(u8, attr, "shape")) {
        if (val.value == .list_type) {
            const items = val.value.list_type.items.items;
            buf.ndim = @min(4, items.len);
            for (items, 0..) |item, i| {
                if (i >= 4) break;
                if (item.value == .i64_type) {
                    buf.shape[i] = @intCast(@max(1, item.value.i64_type));
                }
            }
            recalculateStrides(buf);
            return true;
        } else if (val.value == .tuple_type) {
            const items = val.value.tuple_type.items;
            buf.ndim = @min(4, items.len);
            for (items, 0..) |item, i| {
                if (i >= 4) break;
                if (item.value == .i64_type) {
                    buf.shape[i] = @intCast(@max(1, item.value.i64_type));
                }
            }
            recalculateStrides(buf);
            return true;
        }
    }
    return false;
}
