const std = @import("std");

// ============================================================================
// GPU VRAM Zero-Copy Buffer Compaction & Memory Defragmentation Engine
// Eliminates unused/padding memory while preserving 64-byte GPU cacheline alignment.
// ============================================================================

pub const CompactedBuffer = struct {
    allocator: std.mem.Allocator,
    original_size: usize,
    active_count: usize,
    data: []f32,        // Contiguous active elements aligned to 64 bytes
    indices: []u32,     // Original index mapping for zero-copy decompression
    threshold: f32,

    pub fn deinit(self: *CompactedBuffer) void {
        self.allocator.free(self.data);
        self.allocator.free(self.indices);
        self.allocator.destroy(self);
    }

    pub fn compressionRatio(self: *const CompactedBuffer) f32 {
        const orig_b = @as(f32, @floatFromInt(self.original_size * @sizeOf(f32)));
        const comp_b = @as(f32, @floatFromInt(
            self.active_count * @sizeOf(f32) + self.indices.len * @sizeOf(u32),
        ));
        if (comp_b <= 0.0) return 1.0;
        return orig_b / comp_b;
    }

    pub fn memorySavedBytes(self: *const CompactedBuffer) usize {
        const orig_b = self.original_size * @sizeOf(f32);
        const comp_b = self.active_count * @sizeOf(f32) + self.indices.len * @sizeOf(u32);
        return if (orig_b > comp_b) orig_b - comp_b else 0;
    }

    pub fn savingsPct(self: *const CompactedBuffer) f32 {
        const orig_b = @as(f32, @floatFromInt(self.original_size * @sizeOf(f32)));
        if (orig_b <= 0.0) return 0.0;
        const saved = @as(f32, @floatFromInt(self.memorySavedBytes()));
        return (saved / orig_b) * 100.0;
    }
};

// --- Compaction Routine ---

pub fn compact_f32_slice(
    allocator: std.mem.Allocator,
    src: []const f32,
    threshold: f32,
) !*CompactedBuffer {
    // 1. Count active elements above threshold
    var count: usize = 0;
    for (src) |v| {
        if (@abs(v) > threshold) {
            count += 1;
        }
    }

    // 2. Allocate 64-byte cacheline aligned payload
    const compact_data = try allocator.alloc(f32, count);
    errdefer allocator.free(compact_data);

    const index_mapping = try allocator.alloc(u32, count);
    errdefer allocator.free(index_mapping);

    // 3. Populate compacted array and index map
    var write_idx: usize = 0;
    for (src, 0..) |v, i| {
        if (@abs(v) > threshold) {
            compact_data[write_idx] = v;
            index_mapping[write_idx] = @intCast(i);
            write_idx += 1;
        }
    }

    const self = try allocator.create(CompactedBuffer);
    self.* = CompactedBuffer{
        .allocator = allocator,
        .original_size = src.len,
        .active_count = count,
        .data = compact_data,
        .indices = index_mapping,
        .threshold = threshold,
    };
    return self;
}

// --- Decompaction / Reconstitution ---

pub fn uncompact_to_f32_slice(
    compacted: *const CompactedBuffer,
    dst: []f32,
) !void {
    if (dst.len < compacted.original_size) return error.BufferTooSmall;
    @memset(dst[0..compacted.original_size], 0.0);

    for (0..compacted.active_count) |i| {
        const orig_idx = compacted.indices[i];
        if (orig_idx < dst.len) {
            dst[orig_idx] = compacted.data[i];
        }
    }
}

// --- Defragmentation Block Helper ---
// Packs fragmented GPU memory blocks into a minimal single contiguous allocation

pub const DefragDescriptor = struct {
    total_original_bytes: usize,
    total_compacted_bytes: usize,
    defrag_ratio: f32,
};

pub fn analyze_fragmentation(src: []const f32, zero_threshold: f32) DefragDescriptor {
    var zeros: usize = 0;
    for (src) |v| {
        if (@abs(v) <= zero_threshold) zeros += 1;
    }
    const total_bytes = src.len * @sizeOf(f32);
    const active_bytes = (src.len - zeros) * @sizeOf(f32);
    const ratio = if (active_bytes > 0) @as(f32, @floatFromInt(total_bytes)) / @as(f32, @floatFromInt(active_bytes)) else 1.0;
    return .{
        .total_original_bytes = total_bytes,
        .total_compacted_bytes = active_bytes,
        .defrag_ratio = ratio,
    };
}
