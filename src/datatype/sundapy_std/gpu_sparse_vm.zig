const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const slab = @import("gpu_slab.zig");
const codec_lz = @import("gpu_codec_lz.zig");
// Sparse Virtual Memory & Page Table Paging Subsystem (Production-Grade)

pub const VM_PAGE_BYTES: usize = 64 * 1024; // 64 KB per virtual page
pub const VM_PAGE_FLOATS: usize = VM_PAGE_BYTES / @sizeOf(f32); // 16,384 floats
pub const ALIGNMENT_GPU: usize = 256;
pub const ALIGNMENT_CACHE_LINE: usize = 64;

pub const PageTableEntry = struct {
    physical_dev_ptr: u64 = 0,
    physical_host_ptr: ?[*]u8 = null,
    is_committed: bool = false,
    is_dirty: bool = false,
    access_count: u32 = 0,
    is_compressed: bool = false,
    compressed_bytes: ?[]u8 = null,
};

pub const SparseVirtualBuffer = struct {
    allocator: std.mem.Allocator,
    virtual_elem_count: usize,
    virtual_size_bytes: usize,
    page_size_bytes: usize,
    page_size_floats: usize,
    total_pages: usize,
    committed_pages: usize = 0,
    entries: []PageTableEntry,
    lock: slab.SpinLock = .{},

    pub fn init(allocator: std.mem.Allocator, elem_count: usize, custom_page_bytes: ?usize) !*SparseVirtualBuffer {
        const page_bytes = if (custom_page_bytes) |cpb| @max(VM_PAGE_BYTES, cpb) else VM_PAGE_BYTES;
        const page_floats = page_bytes / @sizeOf(f32);
        const pages = if (elem_count == 0) 1 else (elem_count + page_floats - 1) / page_floats;

        const self = try allocator.create(SparseVirtualBuffer);
        errdefer allocator.destroy(self);

        const table = try allocator.alloc(PageTableEntry, pages);
        errdefer allocator.free(table);

        for (table) |*entry| {
            entry.* = PageTableEntry{};
        }

        self.* = SparseVirtualBuffer{
            .allocator = allocator,
            .virtual_elem_count = elem_count,
            .virtual_size_bytes = elem_count * @sizeOf(f32),
            .page_size_bytes = page_bytes,
            .page_size_floats = page_floats,
            .total_pages = pages,
            .committed_pages = 0,
            .entries = table,
        };
        return self;
    }

    pub fn deinit(self: *SparseVirtualBuffer) void {
        self.lock.lock();
        defer self.lock.unlock();

        const slab_mgr = slab.getGlobalSlabManager();
        for (self.entries) |*entry| {
            if (entry.is_committed and entry.physical_host_ptr != null) {
                slab_mgr.free(entry.physical_host_ptr.?);
                entry.physical_host_ptr = null;
            }
            if (entry.compressed_bytes) |cb| {
                self.allocator.free(cb);
                entry.compressed_bytes = null;
            }
        }
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }

    pub fn commitPage(self: *SparseVirtualBuffer, page_idx: usize) !void {
        self.lock.lock();
        defer self.lock.unlock();

        if (page_idx >= self.total_pages) return error.IndexError;
        var entry = &self.entries[page_idx];
        if (entry.is_committed) return;

        const slab_mgr = slab.getGlobalSlabManager();
        const alloc_res = try slab_mgr.alloc(self.page_size_bytes);

        // If page was compressed, decompress existing content into the new page
        if (entry.is_compressed and entry.compressed_bytes != null) {
            const f_slice: [*]f32 = @ptrCast(@alignCast(alloc_res.host_ptr));
            codec_lz.rleDecompressFloatsInto(entry.compressed_bytes.?, f_slice[0..self.page_size_floats]) catch {
                @memset(alloc_res.host_ptr[0..self.page_size_bytes], 0);
            };
            self.allocator.free(entry.compressed_bytes.?);
            entry.compressed_bytes = null;
            entry.is_compressed = false;
        } else {
            @memset(alloc_res.host_ptr[0..self.page_size_bytes], 0);
        }

        entry.physical_dev_ptr = alloc_res.dev_ptr;
        entry.physical_host_ptr = alloc_res.host_ptr;
        entry.is_committed = true;
        entry.access_count += 1;
        self.committed_pages += 1;
    }

    pub fn decommitPage(self: *SparseVirtualBuffer, page_idx: usize) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (page_idx >= self.total_pages) return;
        var entry = &self.entries[page_idx];
        if (!entry.is_committed or entry.physical_host_ptr == null) return;

        const slab_mgr = slab.getGlobalSlabManager();
        slab_mgr.free(entry.physical_host_ptr.?);
        entry.physical_host_ptr = null;
        entry.physical_dev_ptr = 0;
        entry.is_committed = false;
        entry.is_dirty = false;
        entry.access_count = 0;
        if (self.committed_pages > 0) self.committed_pages -= 1;
    }

    pub fn isPageCommitted(self: *SparseVirtualBuffer, page_idx: usize) bool {
        self.lock.lock();
        defer self.lock.unlock();
        if (page_idx >= self.total_pages) return false;
        return self.entries[page_idx].is_committed;
    }

    pub fn readFloat(self: *SparseVirtualBuffer, idx: usize) !f32 {
        if (idx >= self.virtual_elem_count) return error.IndexError;
        const page_idx = idx / self.page_size_floats;
        const offset = idx % self.page_size_floats;

        self.lock.lock();
        defer self.lock.unlock();

        const entry = &self.entries[page_idx];
        if (!entry.is_committed) {
            // Uncommitted pages return 0.0 without allocating physical VRAM
            return 0.0;
        }

        const host_floats: [*]const f32 = @ptrCast(@alignCast(entry.physical_host_ptr.?));
        return host_floats[offset];
    }

    pub fn writeFloat(self: *SparseVirtualBuffer, idx: usize, val: f32) !void {
        if (idx >= self.virtual_elem_count) return error.IndexError;
        const page_idx = idx / self.page_size_floats;
        const offset = idx % self.page_size_floats;

        // On-demand page fault backing
        if (!self.isPageCommitted(page_idx)) {
            try self.commitPage(page_idx);
        }

        self.lock.lock();
        defer self.lock.unlock();

        var entry = &self.entries[page_idx];
        const host_floats: [*]f32 = @ptrCast(@alignCast(entry.physical_host_ptr.?));
        host_floats[offset] = val;
        entry.is_dirty = true;
        entry.access_count += 1;
    }

    pub fn commitRange(self: *SparseVirtualBuffer, start_elem: usize, count: usize) !void {
        const end_elem = @min(self.virtual_elem_count, start_elem + count);
        if (start_elem >= end_elem) return;

        const start_page = start_elem / self.page_size_floats;
        const end_page = (end_elem + self.page_size_floats - 1) / self.page_size_floats;

        for (start_page..end_page) |p| {
            try self.commitPage(p);
        }
    }

    pub fn decommitRange(self: *SparseVirtualBuffer, start_elem: usize, count: usize) void {
        const end_elem = @min(self.virtual_elem_count, start_elem + count);
        if (start_elem >= end_elem) return;

        const start_page = start_elem / self.page_size_floats;
        const end_page = (end_elem + self.page_size_floats - 1) / self.page_size_floats;

        for (start_page..end_page) |p| {
            self.decommitPage(p);
        }
    }

    pub fn compressIdlePages(self: *SparseVirtualBuffer, min_idle_threshold: u32) !usize {
        self.lock.lock();
        defer self.lock.unlock();

        var reclaimed_bytes: usize = 0;
        const slab_mgr = slab.getGlobalSlabManager();

        for (self.entries) |*entry| {
            if (entry.is_committed and entry.access_count <= min_idle_threshold and entry.physical_host_ptr != null) {
                const host_floats: [*]const f32 = @ptrCast(@alignCast(entry.physical_host_ptr.?));
                const slice = host_floats[0..self.page_size_floats];

                const comp = codec_lz.rleCompressFloats(self.allocator, slice) catch continue;
                if (comp.len < self.page_size_bytes) {
                    slab_mgr.free(entry.physical_host_ptr.?);
                    entry.physical_host_ptr = null;
                    entry.physical_dev_ptr = 0;
                    entry.is_committed = false;
                    entry.is_compressed = true;
                    entry.compressed_bytes = comp;
                    if (self.committed_pages > 0) self.committed_pages -= 1;
                    reclaimed_bytes += (self.page_size_bytes - comp.len);
                } else {
                    self.allocator.free(comp);
                }
            }
        }
        return reclaimed_bytes;
    }

    pub fn getPhysicalBytes(self: *SparseVirtualBuffer) usize {
        self.lock.lock();
        defer self.lock.unlock();
        var comp_b: usize = 0;
        for (self.entries) |entry| {
            if (entry.compressed_bytes) |cb| comp_b += cb.len;
        }
        return (self.committed_pages * self.page_size_bytes) + comp_b;
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
        try dict.value.dict_type.put(Dynamic.initStr("total_pages"), Dynamic.initInt(@intCast(self.total_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("committed_pages"), Dynamic.initInt(@intCast(self.committed_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("vram_savings_pct"), Dynamic.initFloat(savings));
        return dict;
    }

    pub fn toGpuBuffer(self: *SparseVirtualBuffer) !*GpuBuffer {
        const buf = try std.heap.c_allocator.create(GpuBuffer);
        buf.* = GpuBuffer{
            .allocator = self.allocator,
            .size = self.virtual_elem_count,
            .data = &[_]f32{},
            .dtype = .f32,
            .dev_ptr = 0,
            .is_device_allocated = false,
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

// ============================================================================
// Python API Callbacks
// ============================================================================

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
