const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");

// ============================================================================
// VRAM & Pinned Host Memory Arena Sub-Allocator (256-Byte Aligned)
// Slab-Pooled GpuBuffer Objects for Zero-Malloc High-Frequency Allocations
// ============================================================================

pub const DEFAULT_CHUNK_SIZE: usize = 64 * 1024 * 1024; // 64 MB
pub const ALIGNMENT_256: usize = 256;
pub const SLAB_CAPACITY: usize = 256;

pub const GpuMemoryBlock = struct {
    dev_ptr: u64 = 0,
    host_slice: []f32 = &[_]f32{},
    total_bytes: usize = 0,
    allocated_bytes: usize = 0,
    is_managed: bool = false,

    pub fn init(size_bytes: usize) !GpuMemoryBlock {
        driver.initGpuDriver(null);
        var block = GpuMemoryBlock{
            .total_bytes = size_bytes,
            .allocated_bytes = 0,
        };

        if (driver.active_backend == .cuda and driver.cuda_api != null and driver.cuda_api.?.cuMemAllocManaged != null) {
            var cu_ptr: driver.CUdeviceptr = 0;
            // CU_MEM_ATTACH_GLOBAL = 1
            if (driver.cuda_api.?.cuMemAllocManaged.?(&cu_ptr, size_bytes, 1) == driver.CUDA_SUCCESS) {
                const host_ptr: [*]f32 = @ptrFromInt(cu_ptr);
                const elem_count = size_bytes / @sizeOf(f32);
                @memset(host_ptr[0..elem_count], 0.0);
                block.dev_ptr = cu_ptr;
                block.host_slice = host_ptr[0..elem_count];
                block.is_managed = true;
                return block;
            }
        }

        const elem_count = size_bytes / @sizeOf(f32);
        const host_mem = try std.heap.c_allocator.alloc(f32, elem_count);
        @memset(host_mem, 0.0);
        block.host_slice = host_mem;

        if (driver.active_backend == .cuda and driver.cuda_api != null) {
            var cu_ptr: driver.CUdeviceptr = 0;
            if (driver.cuda_api.?.cuMemAlloc(&cu_ptr, size_bytes) == driver.CUDA_SUCCESS) {
                block.dev_ptr = cu_ptr;
            }
        }

        return block;
    }

    pub fn canFit(self: *const GpuMemoryBlock, num_floats: usize) bool {
        const req_bytes = num_floats * @sizeOf(f32);
        const aligned_alloc = (self.allocated_bytes + (ALIGNMENT_256 - 1)) & ~(ALIGNMENT_256 - 1);
        return (aligned_alloc + req_bytes <= self.total_bytes);
    }

    pub fn allocOffset(self: *GpuMemoryBlock, num_floats: usize) ?struct { offset: usize, aligned_bytes: usize } {
        const req_bytes = num_floats * @sizeOf(f32);
        const aligned_alloc = (self.allocated_bytes + (ALIGNMENT_256 - 1)) & ~(ALIGNMENT_256 - 1);
        if (aligned_alloc + req_bytes > self.total_bytes) return null;

        const float_offset = aligned_alloc / @sizeOf(f32);
        self.allocated_bytes = aligned_alloc + req_bytes;
        return .{ .offset = float_offset, .aligned_bytes = aligned_alloc };
    }

    pub fn reset(self: *GpuMemoryBlock) void {
        self.allocated_bytes = 0;
    }

    pub fn deinit(self: *GpuMemoryBlock) void {
        if (self.is_managed) {
            driver.freeCudaDevicePtr(self.dev_ptr);
        } else {
            if (self.dev_ptr != 0) driver.freeCudaDevicePtr(self.dev_ptr);
            std.heap.c_allocator.free(self.host_slice);
        }
        self.total_bytes = 0;
        self.allocated_bytes = 0;
    }
};

pub const GpuArena = struct {
    blocks: std.ArrayList(GpuMemoryBlock) = .empty,
    slabs: std.ArrayList(*[SLAB_CAPACITY]GpuBuffer) = .empty,
    allocated_count: usize = 0,
    chunk_size: usize = DEFAULT_CHUNK_SIZE,
    is_init: bool = false,

    pub fn init(chunk_bytes: usize) GpuArena {
        return .{
            .chunk_size = if (chunk_bytes > 0) chunk_bytes else DEFAULT_CHUNK_SIZE,
            .blocks = .empty,
            .slabs = .empty,
            .allocated_count = 0,
            .is_init = true,
        };
    }

    fn obtainBufferObject(self: *GpuArena) !*GpuBuffer {
        const slab_idx = self.allocated_count / SLAB_CAPACITY;
        const offset = self.allocated_count % SLAB_CAPACITY;

        while (slab_idx >= self.slabs.items.len) {
            const new_slab = try std.heap.c_allocator.create([SLAB_CAPACITY]GpuBuffer);
            try self.slabs.append(std.heap.c_allocator, new_slab);
        }

        self.allocated_count += 1;
        return &self.slabs.items[slab_idx][offset];
    }

    pub fn allocBuffer(self: *GpuArena, num_floats: usize) !*GpuBuffer {
        for (self.blocks.items) |*blk| {
            if (blk.allocOffset(num_floats)) |alloc_res| {
                const buf = try self.obtainBufferObject();
                buf.* = GpuBuffer{
                    .allocator = std.heap.c_allocator,
                    .size = num_floats,
                    .data = blk.host_slice[alloc_res.offset .. alloc_res.offset + num_floats],
                    .dev_ptr = if (blk.dev_ptr != 0) blk.dev_ptr + alloc_res.aligned_bytes else 0,
                    .is_device_allocated = (blk.dev_ptr != 0),
                    .is_managed = blk.is_managed,
                };
                return buf;
            }
        }

        const req_bytes = num_floats * @sizeOf(f32);
        const new_chunk_size = @max(self.chunk_size, ((req_bytes + ALIGNMENT_256 + 1024) / ALIGNMENT_256) * ALIGNMENT_256);
        var new_block = try GpuMemoryBlock.init(new_chunk_size);
        const alloc_res = new_block.allocOffset(num_floats) orelse return error.OutOfMemory;
        try self.blocks.append(std.heap.c_allocator, new_block);

        const buf = try self.obtainBufferObject();
        buf.* = GpuBuffer{
            .allocator = std.heap.c_allocator,
            .size = num_floats,
            .data = new_block.host_slice[alloc_res.offset .. alloc_res.offset + num_floats],
            .dev_ptr = if (new_block.dev_ptr != 0) new_block.dev_ptr + alloc_res.aligned_bytes else 0,
            .is_device_allocated = (new_block.dev_ptr != 0),
            .is_managed = new_block.is_managed,
        };
        return buf;
    }

    pub fn reset(self: *GpuArena) void {
        for (self.blocks.items) |*blk| {
            blk.reset();
        }
        self.allocated_count = 0;
    }

    pub fn getStats(self: *const GpuArena) !Dynamic {
        var total_capacity: usize = 0;
        var total_used: usize = 0;
        for (self.blocks.items) |blk| {
            total_capacity += blk.total_bytes;
            total_used += blk.allocated_bytes;
        }
        const free_bytes = if (total_capacity >= total_used) total_capacity - total_used else 0;
        const frag_pct: f64 = if (total_capacity > 0)
            (1.0 - (@as(f64, @floatFromInt(total_used)) / @as(f64, @floatFromInt(total_capacity)))) * 100.0
        else
            0.0;

        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("total_capacity_bytes"), Dynamic.initInt(@intCast(total_capacity)));
        try dict.value.dict_type.put(Dynamic.initStr("allocated_bytes"), Dynamic.initInt(@intCast(total_used)));
        try dict.value.dict_type.put(Dynamic.initStr("free_bytes"), Dynamic.initInt(@intCast(free_bytes)));
        try dict.value.dict_type.put(Dynamic.initStr("block_count"), Dynamic.initInt(@intCast(self.blocks.items.len)));
        try dict.value.dict_type.put(Dynamic.initStr("buffer_count"), Dynamic.initInt(@intCast(self.allocated_count)));
        try dict.value.dict_type.put(Dynamic.initStr("fragmentation_pct"), Dynamic.initFloat(frag_pct));
        return dict;
    }

    pub fn defragment(self: *GpuArena) !Dynamic {
        var reclaimed_blocks: usize = 0;
        var reclaimed_bytes: usize = 0;

        if (self.blocks.items.len > 1) {
            var i: usize = self.blocks.items.len - 1;
            while (i > 0) : (i -= 1) {
                if (self.blocks.items[i].allocated_bytes == 0) {
                    var blk = self.blocks.swapRemove(i);
                    reclaimed_bytes += blk.total_bytes;
                    blk.deinit();
                    reclaimed_blocks += 1;
                }
            }
        }

        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("reclaimed_blocks"), Dynamic.initInt(@intCast(reclaimed_blocks)));
        try dict.value.dict_type.put(Dynamic.initStr("reclaimed_bytes"), Dynamic.initInt(@intCast(reclaimed_bytes)));
        return dict;
    }

    pub fn deinit(self: *GpuArena) void {
        for (self.blocks.items) |*blk| {
            blk.deinit();
        }
        self.blocks.deinit(std.heap.c_allocator);

        for (self.slabs.items) |slab| {
            std.heap.c_allocator.destroy(slab);
        }
        self.slabs.deinit(std.heap.c_allocator);
        self.allocated_count = 0;
        self.is_init = false;
    }
};

var global_arena: ?GpuArena = null;

pub fn getGlobalArena() *GpuArena {
    if (global_arena == null) {
        global_arena = GpuArena.init(DEFAULT_CHUNK_SIZE);
    }
    return &global_arena.?;
}

pub fn arena_alloc(size_dyn: Dynamic) anyerror!Dynamic {
    if (size_dyn.value != .i64_type) return error.TypeError;
    const s: usize = @intCast(@max(0, size_dyn.value.i64_type));
    const arena = getGlobalArena();
    const buf = try arena.allocBuffer(s);
    return buf.asDynamic();
}

pub fn arena_reset() anyerror!Dynamic {
    if (global_arena) |*a| {
        a.reset();
    }
    return Dynamic.initNone();
}

pub fn arena_stats() anyerror!Dynamic {
    const arena = getGlobalArena();
    return arena.getStats();
}

pub fn arena_defragment() anyerror!Dynamic {
    const arena = getGlobalArena();
    return arena.defragment();
}

pub fn arena_sparse_alloc(size_dyn: Dynamic) anyerror!Dynamic {
    const sparse_vm = @import("gpu_sparse_vm.zig");
    return sparse_vm.sparse_buffer(size_dyn, null);
}

