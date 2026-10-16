const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const slab = @import("gpu_slab.zig");
const sparse_vmm = @import("gpu_sparse_vmm.zig");
const VmmPageTable = sparse_vmm.VmmPageTable;
const sparse_soft = @import("gpu_sparse_software.zig");
const SoftwarePageTable = sparse_soft.SoftwarePageTable;

// Sparse Virtual Memory & Hardware VMM Stitching Subsystem (Production-Grade)

pub const VM_PAGE_BYTES: usize = sparse_soft.VM_PAGE_BYTES;
pub const VM_PAGE_FLOATS: usize = sparse_soft.VM_PAGE_FLOATS;
pub const PageTableEntry = sparse_soft.PageTableEntry;

pub const SparseVirtualBuffer = struct {
    allocator: std.mem.Allocator,
    virtual_elem_count: usize,
    virtual_size_bytes: usize,
    page_size_bytes: usize,
    page_size_floats: usize,
    total_pages: usize,
    committed_pages: usize = 0,
    vmm_table: ?*VmmPageTable = null,
    soft_table: ?*SoftwarePageTable = null,
    lock: slab.SpinLock = .{},

    pub fn init(allocator: std.mem.Allocator, elem_count: usize, custom_page_bytes: ?usize) !*SparseVirtualBuffer {
        const self = try allocator.create(SparseVirtualBuffer);
        errdefer allocator.destroy(self);

        // 1. Hardware VMM path
        if (VmmPageTable.init(allocator, elem_count, custom_page_bytes) catch null) |vt| {
            self.* = SparseVirtualBuffer{
                .allocator = allocator,
                .virtual_elem_count = elem_count,
                .virtual_size_bytes = vt.aligned_virtual_bytes,
                .page_size_bytes = vt.page_size_bytes,
                .page_size_floats = vt.page_size_floats,
                .total_pages = vt.total_pages,
                .committed_pages = 0,
                .vmm_table = vt,
                .soft_table = null,
            };
            return self;
        }

        // 2. Software emulation fallback path
        const page_bytes = if (custom_page_bytes) |cpb| @max(VM_PAGE_BYTES, cpb) else VM_PAGE_BYTES;
        const page_floats = page_bytes / @sizeOf(f32);
        const pages = if (elem_count == 0) 1 else (elem_count + page_floats - 1) / page_floats;

        const st = try SoftwarePageTable.init(allocator, pages, page_bytes);
        errdefer st.deinit();

        self.* = SparseVirtualBuffer{
            .allocator = allocator,
            .virtual_elem_count = elem_count,
            .virtual_size_bytes = elem_count * @sizeOf(f32),
            .page_size_bytes = page_bytes,
            .page_size_floats = page_floats,
            .total_pages = pages,
            .committed_pages = 0,
            .vmm_table = null,
            .soft_table = st,
        };
        return self;
    }

    pub fn deinit(self: *SparseVirtualBuffer) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.vmm_table) |vt| {
            vt.deinit();
            self.vmm_table = null;
        } else if (self.soft_table) |st| {
            st.deinit();
            self.soft_table = null;
        }
        self.allocator.destroy(self);
    }

    pub fn commitPage(self: *SparseVirtualBuffer, page_idx: usize) !void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.vmm_table) |vt| {
            try vt.commitPage(page_idx);
            self.committed_pages = vt.committed_pages;
        } else if (self.soft_table) |st| {
            try st.commitPage(page_idx);
            self.committed_pages = st.committed_pages;
        }
    }

    pub fn decommitPage(self: *SparseVirtualBuffer, page_idx: usize) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.vmm_table) |vt| {
            vt.decommitPage(page_idx);
            self.committed_pages = vt.committed_pages;
        } else if (self.soft_table) |st| {
            st.decommitPage(page_idx);
            self.committed_pages = st.committed_pages;
        }
    }

    pub fn isPageCommitted(self: *SparseVirtualBuffer, page_idx: usize) bool {
        self.lock.lock();
        defer self.lock.unlock();
        if (self.vmm_table) |vt| return vt.isPageCommitted(page_idx);
        if (self.soft_table) |st| return st.isPageCommitted(page_idx);
        return false;
    }

    pub fn readFloat(self: *SparseVirtualBuffer, idx: usize) !f32 {
        if (idx >= self.virtual_elem_count) return error.IndexError;
        if (self.vmm_table) |vt| return vt.readFloat(idx);
        if (self.soft_table) |st| {
            self.lock.lock();
            defer self.lock.unlock();
            return st.readFloat(idx);
        }
        return 0.0;
    }

    pub fn writeFloat(self: *SparseVirtualBuffer, idx: usize, val: f32) !void {
        if (idx >= self.virtual_elem_count) return error.IndexError;
        if (self.vmm_table) |vt| {
            try vt.writeFloat(idx, val);
            self.committed_pages = vt.committed_pages;
            return;
        }
        if (self.soft_table) |st| {
            self.lock.lock();
            defer self.lock.unlock();
            try st.writeFloat(idx, val);
            self.committed_pages = st.committed_pages;
        }
    }

    pub fn commitRange(self: *SparseVirtualBuffer, start_elem: usize, count: usize) !void {
        const end_elem = @min(self.virtual_elem_count, start_elem + count);
        if (start_elem >= end_elem) return;
        const start_page = start_elem / self.page_size_floats;
        const end_page = (end_elem + self.page_size_floats - 1) / self.page_size_floats;
        for (start_page..end_page) |p| try self.commitPage(p);
    }

    pub fn decommitRange(self: *SparseVirtualBuffer, start_elem: usize, count: usize) void {
        const end_elem = @min(self.virtual_elem_count, start_elem + count);
        if (start_elem >= end_elem) return;
        const start_page = start_elem / self.page_size_floats;
        const end_page = (end_elem + self.page_size_floats - 1) / self.page_size_floats;
        for (start_page..end_page) |p| self.decommitPage(p);
    }

    pub fn compressIdlePages(self: *SparseVirtualBuffer, min_idle_threshold: u32) !usize {
        if (self.vmm_table != null) return 0;
        if (self.soft_table) |st| {
            self.lock.lock();
            defer self.lock.unlock();
            const rec = try st.compressIdlePages(min_idle_threshold);
            self.committed_pages = st.committed_pages;
            return rec;
        }
        return 0;
    }

    pub fn getPhysicalBytes(self: *SparseVirtualBuffer) usize {
        self.lock.lock();
        defer self.lock.unlock();
        if (self.vmm_table != null) return self.committed_pages * self.page_size_bytes;
        if (self.soft_table) |st| return st.getPhysicalBytes();
        return 0;
    }

    pub fn getVirtualBytes(self: *SparseVirtualBuffer) usize {
        return self.virtual_size_bytes;
    }

    pub fn getStats(self: *SparseVirtualBuffer) !Dynamic {
        const phys = self.getPhysicalBytes();
        const virt = self.getVirtualBytes();
        const savings: f64 = if (virt > 0) (1.0 - (@as(f64, @floatFromInt(phys)) / @as(f64, @floatFromInt(virt)))) * 100.0 else 0.0;

        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("virtual_bytes"), Dynamic.initInt(@intCast(virt)));
        try dict.value.dict_type.put(Dynamic.initStr("physical_bytes"), Dynamic.initInt(@intCast(phys)));
        try dict.value.dict_type.put(Dynamic.initStr("virtual_elements"), Dynamic.initInt(@intCast(self.virtual_elem_count)));
        try dict.value.dict_type.put(Dynamic.initStr("page_size_bytes"), Dynamic.initInt(@intCast(self.page_size_bytes)));
        const comm_pages = if (self.vmm_table) |vt| vt.committed_pages else self.committed_pages;
        try dict.value.dict_type.put(Dynamic.initStr("total_pages"), Dynamic.initInt(@intCast(self.total_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("committed_pages"), Dynamic.initInt(@intCast(comm_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("vram_savings_pct"), Dynamic.initFloat(savings));
        try dict.value.dict_type.put(Dynamic.initStr("is_hardware_vmm"), Dynamic.initBool(self.vmm_table != null));
        if (self.vmm_table) |vt| {
            try dict.value.dict_type.put(Dynamic.initStr("va_base"), Dynamic.initInt(@intCast(vt.va_base)));
        }
        return dict;
    }

    pub fn getPageMap(self: *SparseVirtualBuffer, alloc: std.mem.Allocator) !Dynamic {
        self.lock.lock();
        defer self.lock.unlock();
        var list = std.ArrayList(Dynamic).empty;
        if (self.vmm_table) |vt| {
            for (0..vt.total_pages) |p| {
                if (vt.is_committed[p]) {
                    var item = Dynamic.initDict(alloc);
                    try item.value.dict_type.put(Dynamic.initStr("page_idx"), Dynamic.initInt(@intCast(p)));
                    try item.value.dict_type.put(Dynamic.initStr("is_committed"), Dynamic.initBool(true));
                    try item.value.dict_type.put(Dynamic.initStr("is_compressed"), Dynamic.initBool(false));
                    try item.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(vt.va_base + p * vt.page_size_bytes)));
                    try item.value.dict_type.put(Dynamic.initStr("access_count"), Dynamic.initInt(1));
                    try list.append(alloc, item);
                }
            }
        } else if (self.soft_table) |st| {
            for (st.entries, 0..) |entry, idx| {
                if (entry.is_committed or entry.is_compressed) {
                    var item = Dynamic.initDict(alloc);
                    try item.value.dict_type.put(Dynamic.initStr("page_idx"), Dynamic.initInt(@intCast(idx)));
                    try item.value.dict_type.put(Dynamic.initStr("is_committed"), Dynamic.initBool(entry.is_committed));
                    try item.value.dict_type.put(Dynamic.initStr("is_compressed"), Dynamic.initBool(entry.is_compressed));
                    try item.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(entry.physical_dev_ptr)));
                    try item.value.dict_type.put(Dynamic.initStr("access_count"), Dynamic.initInt(@intCast(entry.access_count)));
                    try list.append(alloc, item);
                }
            }
        }
        return Dynamic.initList(list);
    }

    pub fn toGpuBuffer(self: *SparseVirtualBuffer) !*GpuBuffer {
        const buf = try std.heap.c_allocator.create(GpuBuffer);
        const dev_va: u64 = if (self.vmm_table) |vt| vt.va_base else 0;
        buf.* = GpuBuffer{
            .allocator = self.allocator,
            .size = self.virtual_elem_count,
            .data = &[_]f32{},
            .dtype = .f32,
            .dev_ptr = dev_va,
            .is_device_allocated = (dev_va != 0),
            .is_managed = false,
            .shape = [_]usize{ self.virtual_elem_count, 1, 1, 1 },
            .strides = [_]usize{ 1, 1, 1, 1 },
            .ndim = 1,
            .is_sparse_vm = true,
            .sparse_vm_ptr = @ptrCast(self),
        };
        return buf;
    }
};

// Bridge Interface with GpuBuffer Function Pointers

pub fn sparseVmDeinitRaw(ptr: *anyopaque) void {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    svm.deinit();
}

pub fn sparseVmGetRaw(ptr: *anyopaque, idx: usize) anyerror!f32 {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    return svm.readFloat(idx);
}

pub fn sparseVmSetRaw(ptr: *anyopaque, idx: usize, val: f32) anyerror!void {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    return svm.writeFloat(idx, val);
}

pub fn sparseVmCommitRaw(ptr: *anyopaque, page_idx: usize) anyerror!void {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    try svm.commitPage(page_idx);
}

pub fn sparseVmDecommitRaw(ptr: *anyopaque, page_idx: usize) void {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    svm.decommitPage(page_idx);
}

pub fn sparseVmIsCommittedRaw(ptr: *anyopaque, page_idx: usize) bool {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    return svm.isPageCommitted(page_idx);
}

pub fn sparseVmCompressIdleRaw(ptr: *anyopaque) anyerror!usize {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    return svm.compressIdlePages(10);
}

pub fn sparseVmStatsRaw(ptr: *anyopaque) anyerror!Dynamic {
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(ptr));
    return svm.getStats();
}

pub fn initSparseVmBridge() void {
    gpu_types.buffer_sparse_deinit_fn = sparseVmDeinitRaw;
    gpu_types.buffer_sparse_get_fn = sparseVmGetRaw;
    gpu_types.buffer_sparse_set_fn = sparseVmSetRaw;
    gpu_types.buffer_sparse_stats_fn = sparseVmStatsRaw;
    gpu_types.buffer_sparse_commit_fn = sparseVmCommitRaw;
    gpu_types.buffer_sparse_decommit_fn = sparseVmDecommitRaw;
    gpu_types.buffer_sparse_is_committed_fn = sparseVmIsCommittedRaw;
    gpu_types.buffer_sparse_compress_idle_fn = sparseVmCompressIdleRaw;
    gpu_types.buffer_slab_free_fn = slab.slabFreeRaw;
}

// Python API Callbacks

pub fn sparse_buffer(size_dyn: Dynamic, page_size_dyn: ?Dynamic) anyerror!Dynamic {
    if (size_dyn.value != .i64_type) return error.TypeError;
    const elem_count: usize = @intCast(@max(1, size_dyn.value.i64_type));
    var page_bytes: ?usize = null;
    if (page_size_dyn) |ps| {
        if (ps.value == .i64_type and ps.value.i64_type > 0) {
            page_bytes = @intCast(ps.value.i64_type);
        }
    }

    initSparseVmBridge();
    const svm = try SparseVirtualBuffer.init(std.heap.c_allocator, elem_count, page_bytes);
    const buf = try svm.toGpuBuffer();
    return buf.asDynamic();
}

pub fn sparse_stats(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (!buf.is_sparse_vm or buf.sparse_vm_ptr == null) return error.NotSparseBuffer;
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));
    return svm.getStats();
}

pub fn sparse_commit(buf_dyn: Dynamic, start_dyn: Dynamic, count_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type or start_dyn.value != .i64_type or count_dyn.value != .i64_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (!buf.is_sparse_vm or buf.sparse_vm_ptr == null) return error.NotSparseBuffer;
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));

    const start: usize = @intCast(@max(0, start_dyn.value.i64_type));
    const count: usize = @intCast(@max(0, count_dyn.value.i64_type));
    try svm.commitRange(start, count);
    return Dynamic.initNone();
}

pub fn sparse_decommit(buf_dyn: Dynamic, page_idx_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type or page_idx_dyn.value != .i64_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (!buf.is_sparse_vm or buf.sparse_vm_ptr == null) return error.NotSparseBuffer;
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));

    const p_idx: usize = @intCast(@max(0, page_idx_dyn.value.i64_type));
    svm.decommitPage(p_idx);
    return Dynamic.initNone();
}

pub fn sparse_compress_idle(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (!buf.is_sparse_vm or buf.sparse_vm_ptr == null) return error.NotSparseBuffer;
    const svm: *SparseVirtualBuffer = @ptrCast(@alignCast(buf.sparse_vm_ptr.?));

    const reclaimed = try svm.compressIdlePages(10);
    return Dynamic.initInt(@intCast(reclaimed));
}
