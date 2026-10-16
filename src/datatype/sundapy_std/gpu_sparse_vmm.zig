const std = @import("std");
const vmm = @import("gpu_driver_vmm.zig");
const driver = @import("gpu_driver.zig");

// ============================================================================
// Hardware Virtual Memory Management (VMM) Stitching Engine
// Replaces software emulation with hardware page table mapping via CUDA MMU
// ============================================================================

pub const VmmPageTable = struct {
    allocator: std.mem.Allocator,
    va_base: u64 = 0,
    aligned_virtual_bytes: usize = 0,
    page_size_bytes: usize = 0,
    page_size_floats: usize = 0,
    total_pages: usize = 0,
    committed_pages: usize = 0,
    handles: []u64,
    is_committed: []bool,

    pub fn init(allocator: std.mem.Allocator, elem_count: usize, custom_page_bytes: ?usize) !?*VmmPageTable {
        driver.initGpuDriver(null);
        if (!vmm.isVmmSupported() or driver.active_backend != .cuda) return null;

        const gran = if (vmm.vmm_granularity > 0) vmm.vmm_granularity else 2 * 1024 * 1024;
        const page_bytes = if (custom_page_bytes) |cpb|
            if (cpb == 0) gran else ((cpb + gran - 1) / gran) * gran
        else
            gran;

        const raw_bytes = elem_count * @sizeOf(f32);
        const aligned_bytes = if (raw_bytes == 0) page_bytes else ((raw_bytes + page_bytes - 1) / page_bytes) * page_bytes;
        const pages = aligned_bytes / page_bytes;

        const va = vmm.reserveVirtualAddress(aligned_bytes, gran) catch {
            return null;
        };

        const handles = allocator.alloc(u64, pages) catch {
            vmm.freeVirtualAddress(va, aligned_bytes);
            return null;
        };
        @memset(handles, 0);

        const committed = allocator.alloc(bool, pages) catch {
            allocator.free(handles);
            vmm.freeVirtualAddress(va, aligned_bytes);
            return null;
        };
        @memset(committed, false);

        const self = allocator.create(VmmPageTable) catch {
            allocator.free(committed);
            allocator.free(handles);
            vmm.freeVirtualAddress(va, aligned_bytes);
            return null;
        };

        self.* = VmmPageTable{
            .allocator = allocator,
            .va_base = va,
            .aligned_virtual_bytes = aligned_bytes,
            .page_size_bytes = page_bytes,
            .page_size_floats = page_bytes / @sizeOf(f32),
            .total_pages = pages,
            .committed_pages = 0,
            .handles = handles,
            .is_committed = committed,
        };
        return self;
    }

    pub fn deinit(self: *VmmPageTable) void {
        for (0..self.total_pages) |p| {
            if (self.is_committed[p]) {
                self.decommitPage(p);
            }
        }
        vmm.freeVirtualAddress(self.va_base, self.aligned_virtual_bytes);
        self.allocator.free(self.handles);
        self.allocator.free(self.is_committed);
        self.allocator.destroy(self);
    }

    pub fn commitPage(self: *VmmPageTable, page_idx: usize) !void {
        if (page_idx >= self.total_pages) return error.IndexError;
        if (self.is_committed[page_idx]) return;

        const handle = try vmm.createPhysicalAllocation(self.page_size_bytes, driver.cuda_device);
        errdefer vmm.releasePhysicalAllocation(handle);

        const page_offset = page_idx * self.page_size_bytes;
        try vmm.mapVirtualPage(self.va_base, self.page_size_bytes, page_offset, handle);
        try vmm.setVirtualPageAccess(self.va_base + page_offset, self.page_size_bytes, driver.cuda_device);

        self.handles[page_idx] = handle;
        self.is_committed[page_idx] = true;
        self.committed_pages += 1;
    }

    pub fn decommitPage(self: *VmmPageTable, page_idx: usize) void {
        if (page_idx >= self.total_pages) return;
        if (!self.is_committed[page_idx]) return;

        const page_offset = page_idx * self.page_size_bytes;
        vmm.unmapVirtualPage(self.va_base + page_offset, self.page_size_bytes);
        vmm.releasePhysicalAllocation(self.handles[page_idx]);

        self.handles[page_idx] = 0;
        self.is_committed[page_idx] = false;
        if (self.committed_pages > 0) self.committed_pages -= 1;
    }

    pub fn isPageCommitted(self: *VmmPageTable, page_idx: usize) bool {
        if (page_idx >= self.total_pages) return false;
        return self.is_committed[page_idx];
    }

    pub fn readFloat(self: *VmmPageTable, idx: usize) !f32 {
        const page_idx = idx / self.page_size_floats;
        if (page_idx >= self.total_pages) return error.IndexError;
        if (!self.is_committed[page_idx]) return 0.0;

        if (driver.cuda_api) |api| {
            var val: f32 = 0.0;
            const offset = idx * @sizeOf(f32);
            const res = api.cuMemcpyDtoH(&val, self.va_base + offset, @sizeOf(f32));
            if (res == driver.CUDA_SUCCESS) return val;
        }
        return 0.0;
    }

    pub fn writeFloat(self: *VmmPageTable, idx: usize, val: f32) !void {
        const page_idx = idx / self.page_size_floats;
        if (page_idx >= self.total_pages) return error.IndexError;

        if (!self.is_committed[page_idx]) {
            try self.commitPage(page_idx);
        }

        if (driver.cuda_api) |api| {
            const offset = idx * @sizeOf(f32);
            const res = api.cuMemcpyHtoD(self.va_base + offset, &val, @sizeOf(f32));
            if (res != driver.CUDA_SUCCESS) return error.GpuWriteFailed;
        }
    }
};
