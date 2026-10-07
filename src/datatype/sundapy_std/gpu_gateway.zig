const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");

// ============================================================================
// Seamless Zero-Copy Interop Gateway (HLA <-> LLA Bridge)
// ============================================================================

pub const MemoryDescriptor = extern struct {
    dev_ptr: u64,
    host_ptr: ?*anyopaque,
    byte_size: usize,
    stride: usize,
    alignment: u32,
    is_managed: u32,
};

pub fn to_raw_handle(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var dict = Dynamic.initDict(std.heap.c_allocator);
    try dict.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(buf.dev_ptr)));
    try dict.value.dict_type.put(Dynamic.initStr("byte_size"), Dynamic.initInt(@intCast(buf.size * @sizeOf(f32))));
    try dict.value.dict_type.put(Dynamic.initStr("stride"), Dynamic.initInt(@sizeOf(f32)));
    try dict.value.dict_type.put(Dynamic.initStr("is_managed"), Dynamic.initBool(buf.is_managed));
    try dict.value.dict_type.put(Dynamic.initStr("is_device"), Dynamic.initBool(buf.is_device_allocated));
    return dict;
}

pub fn from_raw_handle(dev_ptr_dyn: Dynamic, size_dyn: Dynamic) anyerror!Dynamic {
    if (dev_ptr_dyn.value != .i64_type or size_dyn.value != .i64_type) return error.TypeError;
    const dev_ptr: u64 = @intCast(@max(0, dev_ptr_dyn.value.i64_type));
    const size: usize = @intCast(@max(0, size_dyn.value.i64_type));

    const host_mem = try std.heap.c_allocator.alloc(f32, size);
    @memset(host_mem, 0.0);

    const buf = try std.heap.c_allocator.create(GpuBuffer);
    buf.* = GpuBuffer{
        .allocator = std.heap.c_allocator,
        .size = size,
        .data = host_mem,
        .dev_ptr = dev_ptr,
        .is_device_allocated = (dev_ptr != 0),
        .is_managed = false,
    };
    return buf.asDynamic();
}

pub fn get_raw_pointer(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    return Dynamic.initInt(@intCast(buf.dev_ptr));
}
