const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");
const buddy = @import("gpu_slab_buddy.zig");

// ============================================================================
// Ultra-Fast VRAM Slab & Buddy Sub-Allocator (Zero-Driver Calls, 256B Aligned)
// ============================================================================

pub const GPU_ALIGNMENT: usize = 256;
pub const SLAB_PAGE_BYTES: usize = 256 * 1024; // 256 KB per slab page
pub const MASTER_POOL_BYTES: usize = 64 * 1024 * 1024; // 64 MB Master Pool

pub const SIZE_CLASSES = [_]usize{
    64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536,
};

pub const SlabSlot = struct {
    page_idx: u32,
    slot_idx: u32,
    size_class_idx: u32,
};

pub const SlabPage = struct {
    slot_size: usize,
    total_slots: u32,
    allocated_count: u32 = 0,
    free_slots: std.ArrayList(u32),
    dev_ptr: u64,
    host_slice: []u8,

    pub fn init(slot_sz: usize, dev_base: u64, host_mem: []u8) !SlabPage {
        const slots_count: u32 = @intCast(host_mem.len / slot_sz);
        var free_stk = std.ArrayList(u32).empty;
        for (0..slots_count) |i| {
            try free_stk.append(std.heap.c_allocator, @intCast(i));
        }
        return .{
            .slot_size = slot_sz,
            .total_slots = slots_count,
            .allocated_count = 0,
            .free_slots = free_stk,
            .dev_ptr = dev_base,
            .host_slice = host_mem,
        };
    }

    pub fn allocSlot(self: *SlabPage) ?struct { dev_ptr: u64, host_ptr: [*]u8, slot_idx: u32 } {
        if (self.free_slots.items.len == 0) return null;
        const slot_idx = self.free_slots.pop() orelse return null;
        self.allocated_count += 1;
        const offset = @as(usize, slot_idx) * self.slot_size;
        return .{
            .dev_ptr = if (self.dev_ptr != 0) self.dev_ptr + offset else 0,
            .host_ptr = self.host_slice.ptr + offset,
            .slot_idx = slot_idx,
        };
    }

    pub fn freeSlot(self: *SlabPage, slot_idx: u32) void {
        self.free_slots.append(std.heap.c_allocator, slot_idx) catch {};
        if (self.allocated_count > 0) self.allocated_count -= 1;
    }
};

pub const SpinLock = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinLock) void {
        while (self.state.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.state.store(false, .release);
    }
};

pub const VramSlabManager = struct {
    master_host_mem: []u8 = &[_]u8{},
    master_dev_ptr: u64 = 0,
    is_managed: bool = false,
    buddy_allocator: buddy.BuddyAllocator = undefined,
    pages_per_class: [SIZE_CLASSES.len]std.ArrayList(SlabPage),

    active_allocations: std.AutoHashMap(usize, SlabSlot),
    total_allocated_bytes: usize = 0,
    total_alloc_count: usize = 0,
    total_free_count: usize = 0,
    lock: SpinLock = .{},
    is_init: bool = false,

    pub fn init(self: *VramSlabManager) !void {
        if (self.is_init) return;
        self.lock.lock();
        defer self.lock.unlock();
        if (self.is_init) return;

        driver.initGpuDriver(null);
        if (driver.active_backend == .cuda and driver.cuda_api != null and driver.cuda_api.?.cuMemAllocManaged != null) {
            var cu_ptr: driver.CUdeviceptr = 0;
            if (driver.cuda_api.?.cuMemAllocManaged.?(&cu_ptr, MASTER_POOL_BYTES, 1) == driver.CUDA_SUCCESS) {
                const host_ptr: [*]u8 = @ptrFromInt(cu_ptr);
                self.master_host_mem = host_ptr[0..MASTER_POOL_BYTES];
                self.master_dev_ptr = cu_ptr;
                self.is_managed = true;
            }
        }

        if (self.master_host_mem.len == 0) {
            self.master_host_mem = try std.heap.c_allocator.alloc(u8, MASTER_POOL_BYTES);
            if (driver.active_backend == .cuda and driver.cuda_api != null) {
                var cu_ptr: driver.CUdeviceptr = 0;
                if (driver.cuda_api.?.cuMemAlloc(&cu_ptr, MASTER_POOL_BYTES) == driver.CUDA_SUCCESS) {
                    self.master_dev_ptr = cu_ptr;
                }
            }
        }
        @memset(self.master_host_mem, 0);

        try self.buddy_allocator.init(MASTER_POOL_BYTES);
        for (0..SIZE_CLASSES.len) |i| {
            self.pages_per_class[i] = .empty;
        }
        self.active_allocations = std.AutoHashMap(usize, SlabSlot).init(std.heap.c_allocator);
        self.is_init = true;
    }

    fn findSizeClass(bytes: usize) ?usize {
        for (SIZE_CLASSES, 0..) |sc, idx| {
            if (bytes <= sc) return idx;
        }
        return null;
    }

    pub fn alloc(self: *VramSlabManager, req_bytes: usize) !struct { dev_ptr: u64, host_ptr: [*]u8, size_bytes: usize } {
        self.lock.lock();
        defer self.lock.unlock();

        self.total_alloc_count += 1;
        // 1. Slab sub-allocation for small blocks <= 64KB
        if (findSizeClass(req_bytes)) |sc_idx| {
            const slot_size = SIZE_CLASSES[sc_idx];
            var page_list = &self.pages_per_class[sc_idx];

            for (page_list.items, 0..) |*page, p_idx| {
                if (page.allocSlot()) |slot_res| {
                    const host_addr = @intFromPtr(slot_res.host_ptr);
                    self.active_allocations.put(host_addr, .{
                        .page_idx = @intCast(p_idx),
                        .slot_idx = slot_res.slot_idx,
                        .size_class_idx = @intCast(sc_idx),
                    }) catch {};
                    self.total_allocated_bytes += slot_size;
                    return .{ .dev_ptr = slot_res.dev_ptr, .host_ptr = slot_res.host_ptr, .size_bytes = slot_size };
                }
            }

            // Allocate a new SlabPage from Buddy Allocator
            const buddy_res = self.buddy_allocator.alloc(SLAB_PAGE_BYTES) orelse return error.OutOfMemory;
            const dev_base = if (self.master_dev_ptr != 0) self.master_dev_ptr + buddy_res.offset else 0;
            const host_slice = self.master_host_mem[buddy_res.offset .. buddy_res.offset + SLAB_PAGE_BYTES];

            var new_page = try SlabPage.init(slot_size, dev_base, host_slice);
            const slot_res = new_page.allocSlot().?;
            const new_p_idx = page_list.items.len;
            try page_list.append(std.heap.c_allocator, new_page);

            const host_addr = @intFromPtr(slot_res.host_ptr);
            self.active_allocations.put(host_addr, .{
                .page_idx = @intCast(new_p_idx),
                .slot_idx = slot_res.slot_idx,
                .size_class_idx = @intCast(sc_idx),
            }) catch {};
            self.total_allocated_bytes += slot_size;
            return .{ .dev_ptr = slot_res.dev_ptr, .host_ptr = slot_res.host_ptr, .size_bytes = slot_size };
        }

        // 2. Direct Buddy allocation for blocks > 64KB
        const aligned_req = (req_bytes + (GPU_ALIGNMENT - 1)) & ~(GPU_ALIGNMENT - 1);
        const buddy_res = self.buddy_allocator.alloc(aligned_req) orelse return error.OutOfMemory;
        const dev_base = if (self.master_dev_ptr != 0) self.master_dev_ptr + buddy_res.offset else 0;
        const host_ptr = self.master_host_mem.ptr + buddy_res.offset;

        self.total_allocated_bytes += buddy_res.allocated_bytes;
        return .{ .dev_ptr = dev_base, .host_ptr = host_ptr, .size_bytes = buddy_res.allocated_bytes };
    }

    pub fn free(self: *VramSlabManager, host_ptr: [*]u8) void {
        self.lock.lock();
        defer self.lock.unlock();

        self.total_free_count += 1;
        const addr = @intFromPtr(host_ptr);
        if (self.active_allocations.fetchRemove(addr)) |entry| {
            const sc_idx = entry.value.size_class_idx;
            const p_idx = entry.value.page_idx;
            const s_idx = entry.value.slot_idx;
            if (sc_idx < SIZE_CLASSES.len and p_idx < self.pages_per_class[sc_idx].items.len) {
                self.pages_per_class[sc_idx].items[p_idx].freeSlot(s_idx);
                if (self.total_allocated_bytes >= SIZE_CLASSES[sc_idx]) {
                    self.total_allocated_bytes -= SIZE_CLASSES[sc_idx];
                }
            }
            return;
        }

        // Must be a Buddy block
        const offset = addr - @intFromPtr(self.master_host_mem.ptr);
        if (offset < MASTER_POOL_BYTES) {
            _ = self.buddy_allocator.free(offset);
        }
    }

    pub fn defragment(self: *VramSlabManager) !Dynamic {
        self.lock.lock();
        defer self.lock.unlock();

        var reclaimed_pages: usize = 0;
        var reclaimed_bytes: usize = 0;

        for (0..SIZE_CLASSES.len) |sc_idx| {
            var page_list = &self.pages_per_class[sc_idx];
            var i: usize = 0;
            while (i < page_list.items.len) {
                if (page_list.items[i].allocated_count == 0) {
                    var p = page_list.swapRemove(i);
                    p.free_slots.deinit(std.heap.c_allocator);
                    const offset = @intFromPtr(p.host_slice.ptr) - @intFromPtr(self.master_host_mem.ptr);
                    _ = self.buddy_allocator.free(offset);
                    reclaimed_pages += 1;
                    reclaimed_bytes += SLAB_PAGE_BYTES;
                } else {
                    i += 1;
                }
            }
        }

        const total_free = self.buddy_allocator.getTotalFree();
        const max_contig = self.buddy_allocator.getMaxContiguousFree();
        const frag_ratio = if (total_free > 0) (1.0 - (@as(f64, @floatFromInt(max_contig)) / @as(f64, @floatFromInt(total_free)))) * 100.0 else 0.0;

        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("reclaimed_pages"), Dynamic.initInt(@intCast(reclaimed_pages)));
        try dict.value.dict_type.put(Dynamic.initStr("reclaimed_bytes"), Dynamic.initInt(@intCast(reclaimed_bytes)));
        try dict.value.dict_type.put(Dynamic.initStr("fragmentation_ratio"), Dynamic.initFloat(frag_ratio));
        try dict.value.dict_type.put(Dynamic.initStr("total_free_bytes"), Dynamic.initInt(@intCast(total_free)));
        return dict;
    }

    pub fn getStats(self: *VramSlabManager) !Dynamic {
        self.lock.lock();
        defer self.lock.unlock();

        const total_free = self.buddy_allocator.getTotalFree();
        const max_contig = self.buddy_allocator.getMaxContiguousFree();
        const frag_ratio = if (total_free > 0) (1.0 - (@as(f64, @floatFromInt(max_contig)) / @as(f64, @floatFromInt(total_free)))) * 100.0 else 0.0;

        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("master_pool_bytes"), Dynamic.initInt(@intCast(MASTER_POOL_BYTES)));
        try dict.value.dict_type.put(Dynamic.initStr("allocated_bytes"), Dynamic.initInt(@intCast(self.total_allocated_bytes)));
        try dict.value.dict_type.put(Dynamic.initStr("total_free_bytes"), Dynamic.initInt(@intCast(total_free)));
        try dict.value.dict_type.put(Dynamic.initStr("fragmentation_ratio"), Dynamic.initFloat(frag_ratio));
        try dict.value.dict_type.put(Dynamic.initStr("alloc_count"), Dynamic.initInt(@intCast(self.total_alloc_count)));
        try dict.value.dict_type.put(Dynamic.initStr("free_count"), Dynamic.initInt(@intCast(self.total_free_count)));
        return dict;
    }
};

var global_slab_manager: VramSlabManager = .{
    .pages_per_class = undefined,
    .active_allocations = undefined,
};

pub fn getGlobalSlabManager() *VramSlabManager {
    if (!global_slab_manager.is_init) {
        global_slab_manager.init() catch {};
    }
    return &global_slab_manager;
}

pub fn slabFreeRaw(ptr: [*]u8) void {
    const mgr = getGlobalSlabManager();
    mgr.free(ptr);
}

pub fn slab_alloc(size_dyn: Dynamic) anyerror!Dynamic {
    if (size_dyn.value != .i64_type) return error.TypeError;
    const num_floats: usize = @intCast(@max(1, size_dyn.value.i64_type));
    const byte_size = num_floats * @sizeOf(f32);

    const mgr = getGlobalSlabManager();
    const res = try mgr.alloc(byte_size);

    const host_floats: [*]f32 = @ptrCast(@alignCast(res.host_ptr));
    const gbuf = try std.heap.c_allocator.create(GpuBuffer);
    gbuf.* = GpuBuffer{
        .allocator = std.heap.c_allocator,
        .size = num_floats,
        .data = host_floats[0..num_floats],
        .dtype = .f32,
        .dev_ptr = res.dev_ptr,
        .is_device_allocated = (res.dev_ptr != 0),
        .is_managed = mgr.is_managed,
        .shape = [_]usize{ num_floats, 1, 1, 1 },
        .strides = [_]usize{ 1, 1, 1, 1 },
        .ndim = 1,
        .is_suballocated = true,
    };
    return gbuf.asDynamic();
}

pub fn slab_free(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    if (buf.data.len > 0) {
        const mgr = getGlobalSlabManager();
        mgr.free(@ptrCast(buf.data.ptr));
    }
    buf.deinit();
    return Dynamic.initNone();
}

pub fn slab_stats() anyerror!Dynamic {
    const mgr = getGlobalSlabManager();
    return mgr.getStats();
}

pub fn defragment() anyerror!Dynamic {
    const mgr = getGlobalSlabManager();
    return mgr.defragment();
}
