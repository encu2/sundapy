const std = @import("std");
const quant = @import("gpu_quant.zig");
const sparse = @import("gpu_sparse.zig");
const compact = @import("gpu_compaction.zig");

// ============================================================================
// Production GPU Ultra-High Compression Codecs
// Formats: FP8 (E4M3 / E5M2), FP4 (E2M1), BF16, NVFP4 Microscaling,
// Bit-Level Compressed Sparse (BCSR), and Zero-Copy Cacheline Compaction.
// ============================================================================

pub const NVFP4_BLOCK_SIZE: usize = 16;

// --- FP8 E4M3 (Hopper Architecture: 4.0x compression, 1 byte/element) ---
pub fn fp8E4m3Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const out = try allocator.alloc(u8, 4 + count);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(count), .little);
    for (data, 0..) |v, i| {
        out[4 + i] = quant.f32_to_fp8_e4m3(v);
    }
    return out;
}

pub fn fp8E4m3DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (comp_data.len < 4 + count) return error.TruncatedStream;

    const payload = comp_data[4 .. 4 + count];
    for (payload, 0..) |b, i| {
        out_slice[i] = quant.fp8_e4m3_to_f32(b);
    }
}

// --- FP8 E5M2 (OCP standard: 4.0x compression, wider dynamic range) ---
pub fn fp8E5m2Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const out = try allocator.alloc(u8, 4 + count);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(count), .little);
    for (data, 0..) |v, i| {
        out[4 + i] = quant.f32_to_fp8_e5m2(v);
    }
    return out;
}

pub fn fp8E5m2DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (comp_data.len < 4 + count) return error.TruncatedStream;

    const payload = comp_data[4 .. 4 + count];
    for (payload, 0..) |b, i| {
        out_slice[i] = quant.fp8_e5m2_to_f32(b);
    }
}

// --- FP4 E2M1 (NVIDIA Blackwell NVFP4: 8.0x compression, 0.5 bytes/element) ---
pub fn fp4E2m1Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const packed_len = (count + 1) / 2;
    const out = try allocator.alloc(u8, 4 + packed_len);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(count), .little);
    var i: usize = 0;
    while (i < count) : (i += 2) {
        const v0 = data[i];
        const v1 = if (i + 1 < count) data[i + 1] else 0.0;
        out[4 + (i / 2)] = quant.pack_fp4_pair(v0, v1);
    }
    return out;
}

pub fn fp4E2m1DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    const packed_len = (count + 1) / 2;
    if (comp_data.len < 4 + packed_len) return error.TruncatedStream;

    const payload = comp_data[4 .. 4 + packed_len];
    var out_idx: usize = 0;
    for (payload) |b| {
        const pair = quant.unpack_fp4_pair(b);
        if (out_idx < count) {
            out_slice[out_idx] = pair[0];
            out_idx += 1;
        }
        if (out_idx < count) {
            out_slice[out_idx] = pair[1];
            out_idx += 1;
        }
    }
}

// --- BF16 (Brain Floating Point 16: 2.0x compression, 2 bytes/element) ---
pub fn bf16Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const out = try allocator.alloc(u8, 4 + count * 2);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(count), .little);
    for (data, 0..) |v, i| {
        const u = quant.f32_to_bf16(v);
        std.mem.writeInt(u16, out[4 + i * 2 .. 6 + i * 2][0..2], u, .little);
    }
    return out;
}

pub fn bf16DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (comp_data.len < 4 + count * 2) return error.TruncatedStream;

    for (0..count) |i| {
        const u = std.mem.readInt(u16, comp_data[4 + i * 2 .. 6 + i * 2][0..2], .little);
        out_slice[i] = quant.bf16_to_f32(u);
    }
}

// --- Blackwell NVFP4 Microscaling (7.11x compression with block scale factor) ---
pub fn nvfp4MicroscaleCompress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const num_blocks = (count + NVFP4_BLOCK_SIZE - 1) / NVFP4_BLOCK_SIZE;
    // Header: count (4 bytes), block_size (2 bytes) = 6 bytes
    // Per block: scale (1 byte fp8_e4m3), packed nibbles (8 bytes) = 9 bytes
    const total_bytes = 6 + num_blocks * 9;
    const out = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(count), .little);
    std.mem.writeInt(u16, out[4..6], @intCast(NVFP4_BLOCK_SIZE), .little);

    var offset: usize = 6;
    for (0..num_blocks) |b_idx| {
        const start = b_idx * NVFP4_BLOCK_SIZE;
        const end = @min(start + NVFP4_BLOCK_SIZE, count);
        const blk = data[start..end];

        var max_abs: f32 = 0.0;
        for (blk) |v| {
            const a = @abs(v);
            if (a > max_abs) max_abs = a;
        }

        // Scale maps max_abs to 6.0 (the max code in FP4 E2M1)
        const scale = if (max_abs > 1e-12) max_abs / 6.0 else 1.0;
        const scale_fp8 = quant.f32_to_fp8_e4m3(scale);
        out[offset] = scale_fp8;
        offset += 1;

        const inv_scale = 1.0 / scale;
        var k: usize = 0;
        while (k < NVFP4_BLOCK_SIZE) : (k += 2) {
            const v0 = if (start + k < count) data[start + k] else 0.0;
            const v1 = if (start + k + 1 < count) data[start + k + 1] else 0.0;
            out[offset + (k / 2)] = quant.pack_fp4_pair(v0 * inv_scale, v1 * inv_scale);
        }
        offset += (NVFP4_BLOCK_SIZE / 2);
    }
    return out;
}

pub fn nvfp4MicroscaleDecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 6) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (count == 0) return;

    const blk_size: usize = std.mem.readInt(u16, comp_data[4..6], .little);
    if (blk_size != NVFP4_BLOCK_SIZE) return error.UnsupportedBlockSize;
    const num_blocks = (count + blk_size - 1) / blk_size;

    var offset: usize = 6;
    for (0..num_blocks) |b_idx| {
        if (offset + 9 > comp_data.len) return error.TruncatedStream;
        const scale_fp8 = comp_data[offset];
        offset += 1;
        const scale = quant.fp8_e4m3_to_f32(scale_fp8);

        const start = b_idx * blk_size;
        var k: usize = 0;
        while (k < blk_size) : (k += 2) {
            const b = comp_data[offset + (k / 2)];
            const pair = quant.unpack_fp4_pair(b);
            if (start + k < count) out_slice[start + k] = pair[0] * scale;
            if (start + k + 1 < count) out_slice[start + k + 1] = pair[1] * scale;
        }
        offset += (blk_size / 2);
    }
}

// --- BCSR Sparse Serialized Container ---
pub fn bcsrCompressSlice(allocator: std.mem.Allocator, data: []const f32, rows: usize, cols: usize, threshold: f32) ![]u8 {
    const mat = try sparse.compress_dense_to_bcsr(allocator, data, rows, cols, threshold);
    defer mat.deinit();

    // Header: rows (4 bytes), cols (4 bytes), words_per_row (4 bytes), nnz (4 bytes) = 16 bytes
    const row_off_bytes = (rows + 1) * @sizeOf(u32);
    const bitmask_bytes = rows * mat.words_per_row * @sizeOf(u64);
    const val_bytes = mat.nnz * @sizeOf(f32);
    const total_bytes = 16 + row_off_bytes + bitmask_bytes + val_bytes;

    const out = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(rows), .little);
    std.mem.writeInt(u32, out[4..8], @intCast(cols), .little);
    std.mem.writeInt(u32, out[8..12], @intCast(mat.words_per_row), .little);
    std.mem.writeInt(u32, out[12..16], @intCast(mat.nnz), .little);

    var cur: usize = 16;
    for (mat.row_offsets) |ro| {
        std.mem.writeInt(u32, out[cur .. cur + 4][0..4], @intCast(ro), .little);
        cur += 4;
    }

    for (mat.bitmasks) |bm| {
        std.mem.writeInt(u64, out[cur .. cur + 8][0..8], bm, .little);
        cur += 8;
    }

    for (mat.values) |v| {
        std.mem.writeInt(u32, out[cur .. cur + 4][0..4], @bitCast(v), .little);
        cur += 4;
    }
    return out;
}

pub fn bcsrDecompressSliceInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 16) return error.InvalidData;
    const rows: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    const cols: usize = std.mem.readInt(u32, comp_data[4..8], .little);
    const words_per_row: usize = std.mem.readInt(u32, comp_data[8..12], .little);
    const nnz: usize = std.mem.readInt(u32, comp_data[12..16], .little);

    const expected_total = 16 + (rows + 1) * 4 + (rows * words_per_row) * 8 + nnz * 4;
    if (comp_data.len < expected_total) return error.TruncatedStream;

    const total_elements = rows * cols;
    if (total_elements > out_slice.len) return error.BufferTooSmall;
    @memset(out_slice[0..total_elements], 0.0);

    var cur: usize = 16;
    const row_offsets = try std.heap.c_allocator.alloc(usize, rows + 1);
    defer std.heap.c_allocator.free(row_offsets);
    for (0..rows + 1) |r| {
        row_offsets[r] = std.mem.readInt(u32, comp_data[cur .. cur + 4][0..4], .little);
        cur += 4;
    }

    const bitmasks = try std.heap.c_allocator.alloc(u64, rows * words_per_row);
    defer std.heap.c_allocator.free(bitmasks);
    for (0..rows * words_per_row) |i| {
        bitmasks[i] = std.mem.readInt(u64, comp_data[cur .. cur + 8][0..8], .little);
        cur += 8;
    }

    const values = try std.heap.c_allocator.alloc(f32, nnz);
    defer std.heap.c_allocator.free(values);
    for (0..nnz) |i| {
        const u = std.mem.readInt(u32, comp_data[cur .. cur + 4][0..4], .little);
        values[i] = @bitCast(u);
        cur += 4;
    }

    for (0..rows) |r| {
        const row_start = r * cols;
        var val_idx = row_offsets[r];
        const end_val = row_offsets[r + 1];

        for (0..words_per_row) |w| {
            var mask = bitmasks[r * words_per_row + w];
            const col_base = w * 64;
            while (mask != 0) {
                const bit_pos = @ctz(mask);
                const c = col_base + bit_pos;
                if (c < cols and val_idx < end_val) {
                    out_slice[row_start + c] = values[val_idx];
                    val_idx += 1;
                }
                mask &= mask - 1;
            }
        }
    }
}

// --- Zero-Copy Cacheline Compaction Serialized Container ---
pub fn compactCompressSlice(allocator: std.mem.Allocator, data: []const f32, threshold: f32) ![]u8 {
    const cb = try compact.compact_f32_slice(allocator, data, threshold);
    defer cb.deinit();

    // Header: original_size (4 bytes), active_count (4 bytes), threshold (4 bytes) = 12 bytes
    const total_bytes = 12 + cb.active_count * @sizeOf(f32) + cb.active_count * @sizeOf(u32);
    const out = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(out);

    std.mem.writeInt(u32, out[0..4], @intCast(cb.original_size), .little);
    std.mem.writeInt(u32, out[4..8], @intCast(cb.active_count), .little);
    std.mem.writeInt(u32, out[8..12], @bitCast(threshold), .little);

    var cur: usize = 12;
    for (cb.data) |v| {
        std.mem.writeInt(u32, out[cur .. cur + 4][0..4], @bitCast(v), .little);
        cur += 4;
    }
    for (cb.indices) |idx| {
        std.mem.writeInt(u32, out[cur .. cur + 4][0..4], idx, .little);
        cur += 4;
    }
    return out;
}

pub fn compactDecompressSliceInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 12) return error.InvalidData;
    const orig_size: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    const active_count: usize = std.mem.readInt(u32, comp_data[4..8], .little);
    if (comp_data.len < 12 + active_count * 8) return error.TruncatedStream;
    if (orig_size > out_slice.len) return error.BufferTooSmall;

    @memset(out_slice[0..orig_size], 0.0);
    var cur: usize = 12;
    const data_start = cur;
    cur += active_count * 4;
    const idx_start = cur;

    for (0..active_count) |i| {
        const u_v = std.mem.readInt(u32, comp_data[data_start + i * 4 .. data_start + (i + 1) * 4][0..4], .little);
        const val: f32 = @bitCast(u_v);
        const orig_idx: usize = std.mem.readInt(u32, comp_data[idx_start + i * 4 .. idx_start + (i + 1) * 4][0..4], .little);
        if (orig_idx < orig_size) {
            out_slice[orig_idx] = val;
        }
    }
}
