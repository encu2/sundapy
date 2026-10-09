const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");
const sparse_vm = @import("gpu_sparse_vm.zig");

// ============================================================================
// Seamless Zero-Copy Interop Gateway (HLA <-> LLA Bridge)
// Unified Sparse Virtual Memory, Slab Sub-allocation & Driver Handle Descriptors
// ============================================================================

pub const MemoryDescriptor = extern struct {
    dev_ptr: u64,
    host_ptr: ?*anyopaque,
    byte_size: usize,
    stride: usize,
    alignment: u32,
    is_managed: u32,
    is_sparse: u32,
    virtual_size: usize,
    physical_size: usize,
    page_size: usize,
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
    try dict.value.dict_type.put(Dynamic.initStr("is_suballocated"), Dynamic.initBool(buf.is_suballocated));
    try dict.value.dict_type.put(Dynamic.initStr("is_sparse"), Dynamic.initBool(buf.is_sparse_vm));

    if (buf.is_sparse_vm and buf.sparse_vm_ptr != null) {
        const svm: *sparse_vm.SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));
        try dict.value.dict_type.put(Dynamic.initStr("virtual_size"), Dynamic.initInt(@intCast(svm.virtual_size_bytes)));
        try dict.value.dict_type.put(Dynamic.initStr("physical_size"), Dynamic.initInt(@intCast(svm.getPhysicalBytes())));
        try dict.value.dict_type.put(Dynamic.initStr("page_size"), Dynamic.initInt(@intCast(svm.page_size_bytes)));
        try dict.value.dict_type.put(Dynamic.initStr("committed_pages"), Dynamic.initInt(@intCast(svm.committed_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("total_pages"), Dynamic.initInt(@intCast(svm.total_pages)));
    } else {
        try dict.value.dict_type.put(Dynamic.initStr("virtual_size"), Dynamic.initInt(@intCast(buf.size * @sizeOf(f32))));
        try dict.value.dict_type.put(Dynamic.initStr("physical_size"), Dynamic.initInt(@intCast(buf.size * @sizeOf(f32))));
        try dict.value.dict_type.put(Dynamic.initStr("page_size"), Dynamic.initInt(4096));
        try dict.value.dict_type.put(Dynamic.initStr("committed_pages"), Dynamic.initInt(1));
        try dict.value.dict_type.put(Dynamic.initStr("total_pages"), Dynamic.initInt(1));
    }
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

pub fn sparse_page_map(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (!buf.is_sparse_vm or buf.sparse_vm_ptr == null) return error.NotSparseBuffer;

    const svm: *sparse_vm.SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));
    var list = std.ArrayList(Dynamic).empty;

    for (svm.entries, 0..) |entry, idx| {
        if (entry.is_committed or entry.is_compressed) {
            var item = Dynamic.initDict(std.heap.c_allocator);
            try item.value.dict_type.put(Dynamic.initStr("page_idx"), Dynamic.initInt(@intCast(idx)));
            try item.value.dict_type.put(Dynamic.initStr("is_committed"), Dynamic.initBool(entry.is_committed));
            try item.value.dict_type.put(Dynamic.initStr("is_compressed"), Dynamic.initBool(entry.is_compressed));
            try item.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(entry.physical_dev_ptr)));
            try item.value.dict_type.put(Dynamic.initStr("access_count"), Dynamic.initInt(@intCast(entry.access_count)));
            try list.append(std.heap.c_allocator, item);
        }
    }
    return Dynamic.initList(list);
}

pub fn commit_virtual_range(buf_dyn: Dynamic, start_dyn: Dynamic, count_dyn: Dynamic) anyerror!Dynamic {
    return sparse_vm.sparse_commit(buf_dyn, start_dyn, count_dyn);
}
