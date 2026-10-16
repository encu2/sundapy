const std = @import("std");
const slab = @import("gpu_slab.zig");
const codec_lz = @import("gpu_codec_lz.zig");

pub const VM_PAGE_BYTES: usize = 64 * 1024;
pub const VM_PAGE_FLOATS: usize = VM_PAGE_BYTES / @sizeOf(f32);

pub const PageTableEntry = struct {
    physical_dev_ptr: u64 = 0,
    physical_host_ptr: ?[*]u8 = null,
    is_committed: bool = false,
    is_dirty: bool = false,
    access_count: u32 = 0,
    is_compressed: bool = false,
    compressed_bytes: ?[]u8 = null,
};

pub const SoftwarePageTable = struct {
    allocator: std.mem.Allocator,
    entries: []PageTableEntry,
    page_size_bytes: usize,
    page_size_floats: usize,
    total_pages: usize,
    committed_pages: usize = 0,

    pub fn init(allocator: std.mem.Allocator, pages: usize, page_bytes: usize) !*SoftwarePageTable {
        const self = try allocator.create(SoftwarePageTable);
        errdefer allocator.destroy(self);

        const table = try allocator.alloc(PageTableEntry, pages);
        errdefer allocator.free(table);

        for (table) |*entry| {
            entry.* = PageTableEntry{};
        }

        self.* = SoftwarePageTable{
            .allocator = allocator,
            .entries = table,
            .page_size_bytes = page_bytes,
            .page_size_floats = page_bytes / @sizeOf(f32),
            .total_pages = pages,
            .committed_pages = 0,
        };
        return self;
    }

    pub fn deinit(self: *SoftwarePageTable) void {
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

    pub fn commitPage(self: *SoftwarePageTable, page_idx: usize) !void {
        if (page_idx >= self.total_pages) return error.IndexError;
        var entry = &self.entries[page_idx];
        if (entry.is_committed) return;

        const slab_mgr = slab.getGlobalSlabManager();
        const alloc_res = try slab_mgr.alloc(self.page_size_bytes);

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

    pub fn decommitPage(self: *SoftwarePageTable, page_idx: usize) void {
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

    pub fn isPageCommitted(self: *SoftwarePageTable, page_idx: usize) bool {
        if (page_idx >= self.total_pages) return false;
        return self.entries[page_idx].is_committed;
    }

    pub fn readFloat(self: *SoftwarePageTable, idx: usize) !f32 {
        const page_idx = idx / self.page_size_floats;
        const offset = idx % self.page_size_floats;
        if (page_idx >= self.total_pages) return error.IndexError;

        const entry = &self.entries[page_idx];
        if (!entry.is_committed) return 0.0;

        const host_floats: [*]const f32 = @ptrCast(@alignCast(entry.physical_host_ptr.?));
        return host_floats[offset];
    }

    pub fn writeFloat(self: *SoftwarePageTable, idx: usize, val: f32) !void {
        const page_idx = idx / self.page_size_floats;
        const offset = idx % self.page_size_floats;
        if (page_idx >= self.total_pages) return error.IndexError;

        if (!self.isPageCommitted(page_idx)) {
            try self.commitPage(page_idx);
        }

        var entry = &self.entries[page_idx];
        const host_floats: [*]f32 = @ptrCast(@alignCast(entry.physical_host_ptr.?));
        host_floats[offset] = val;
        entry.is_dirty = true;
        entry.access_count += 1;
    }

    pub fn compressIdlePages(self: *SoftwarePageTable, min_idle_threshold: u32) !usize {
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

    pub fn getPhysicalBytes(self: *SoftwarePageTable) usize {
        var comp_b: usize = 0;
        for (self.entries) |entry| {
            if (entry.compressed_bytes) |cb| comp_b += cb.len;
        }
        return (self.committed_pages * self.page_size_bytes) + comp_b;
    }
};
