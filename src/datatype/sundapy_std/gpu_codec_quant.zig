const std = @import("std");

// ============================================================================
// High-Ratio Dynamic Range Quantization Codecs (INT8, INT4, FP16, Block-Quant)
// Yields 2x to 8x VRAM reduction with high numerical fidelity
// ============================================================================

pub const BLOCK_SIZE: usize = 16;

// ----------------------------------------------------------------------------
// INT8 Linear Dynamic Range Quantization (4.0x compression)
// ----------------------------------------------------------------------------

pub fn quant8Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    if (count == 0) {
        const out = try allocator.alloc(u8, 12);
        std.mem.writeInt(u32, out[0..4], 0, .little);
        @memset(out[4..12], 0);
        return out;
    }

    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    for (data[1..]) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }

    const out_buf = try allocator.alloc(u8, 12 + count);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(count), .little);
    const min_u32: u32 = @bitCast(min_val);
    const max_u32: u32 = @bitCast(max_val);
    std.mem.writeInt(u32, out_buf[4..8], min_u32, .little);
    std.mem.writeInt(u32, out_buf[8..12], max_u32, .little);

    const range = max_val - min_val;
    if (range <= 1e-12) {
        @memset(out_buf[12 .. 12 + count], 0);
        return out_buf;
    }

    const inv_scale: f32 = 255.0 / range;
    for (data, 0..) |v, idx| {
        const normalized = (v - min_val) * inv_scale;
        const clamped = @min(255.0, @max(0.0, normalized));
        out_buf[12 + idx] = @intFromFloat(@round(clamped));
    }

    return out_buf;
}

pub fn quant8DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 12) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (count == 0) return;

    const min_u32 = std.mem.readInt(u32, comp_data[4..8], .little);
    const max_u32 = std.mem.readInt(u32, comp_data[8..12], .little);
    const min_val: f32 = @bitCast(min_u32);
    const max_val: f32 = @bitCast(max_u32);

    if (comp_data.len < 12 + count) return error.TruncatedStream;
    const payload = comp_data[12 .. 12 + count];

    const range = max_val - min_val;
    if (range <= 1e-12) {
        @memset(out_slice[0..count], min_val);
        return;
    }

    const scale: f32 = range / 255.0;
    for (payload, 0..) |q, idx| {
        out_slice[idx] = min_val + (@as(f32, @floatFromInt(q)) * scale);
    }
}

// ----------------------------------------------------------------------------
// INT4 Packed Nibble Quantization (8.0x compression)
// ----------------------------------------------------------------------------

pub fn quant4Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    if (count == 0) {
        const out = try allocator.alloc(u8, 12);
        std.mem.writeInt(u32, out[0..4], 0, .little);
        @memset(out[4..12], 0);
        return out;
    }

    var min_val: f32 = data[0];
    var max_val: f32 = data[0];
    for (data[1..]) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }

    const packed_len = (count + 1) / 2;
    const out_buf = try allocator.alloc(u8, 12 + packed_len);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(count), .little);
    const min_u32: u32 = @bitCast(min_val);
    const max_u32: u32 = @bitCast(max_val);
    std.mem.writeInt(u32, out_buf[4..8], min_u32, .little);
    std.mem.writeInt(u32, out_buf[8..12], max_u32, .little);

    const range = max_val - min_val;
    if (range <= 1e-12) {
        @memset(out_buf[12 .. 12 + packed_len], 0);
        return out_buf;
    }

    const inv_scale: f32 = 15.0 / range;
    var i: usize = 0;
    while (i < count) : (i += 2) {
        const v0 = data[i];
        const n0 = (v0 - min_val) * inv_scale;
        const q0: u8 = @intFromFloat(@round(@min(15.0, @max(0.0, n0))));

        var q1: u8 = 0;
        if (i + 1 < count) {
            const v1 = data[i + 1];
            const n1 = (v1 - min_val) * inv_scale;
            q1 = @intFromFloat(@round(@min(15.0, @max(0.0, n1))));
        }

        out_buf[12 + (i / 2)] = (q0 & 0x0F) | ((q1 & 0x0F) << 4);
    }

    return out_buf;
}

pub fn quant4DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 12) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (count == 0) return;

    const min_u32 = std.mem.readInt(u32, comp_data[4..8], .little);
    const max_u32 = std.mem.readInt(u32, comp_data[8..12], .little);
    const min_val: f32 = @bitCast(min_u32);
    const max_val: f32 = @bitCast(max_u32);

    const packed_len = (count + 1) / 2;
    if (comp_data.len < 12 + packed_len) return error.TruncatedStream;
    const payload = comp_data[12 .. 12 + packed_len];

    const range = max_val - min_val;
    if (range <= 1e-12) {
        @memset(out_slice[0..count], min_val);
        return;
    }

    const scale: f32 = range / 15.0;
    var i: usize = 0;
    while (i < count) : (i += 2) {
        const b = payload[i / 2];
        const q0 = b & 0x0F;
        const q1 = (b >> 4) & 0x0F;

        out_slice[i] = min_val + (@as(f32, @floatFromInt(q0)) * scale);
        if (i + 1 < count) {
            out_slice[i + 1] = min_val + (@as(f32, @floatFromInt(q1)) * scale);
        }
    }
}

// ----------------------------------------------------------------------------
// FP16 Half-Precision Codec (2.0x compression, IEEE 754)
// ----------------------------------------------------------------------------

pub fn fp16Compress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const out_buf = try allocator.alloc(u8, 4 + count * 2);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(count), .little);
    for (data, 0..) |v, idx| {
        const h: f16 = @floatCast(v);
        const u: u16 = @bitCast(h);
        std.mem.writeInt(u16, out_buf[4 + idx * 2 ..][0..2], u, .little);
    }
    return out_buf;
}

pub fn fp16DecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (comp_data.len < 4 + count * 2) return error.TruncatedStream;

    for (0..count) |idx| {
        const u = std.mem.readInt(u16, comp_data[4 + idx * 2 ..][0..2], .little);
        const h: f16 = @bitCast(u);
        out_slice[idx] = @floatCast(h);
    }
}

// ----------------------------------------------------------------------------
// Block-Floating-Point Micro-scaling Codec (5.33x compression)
// ----------------------------------------------------------------------------

pub fn blockQuantCompress(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    const num_blocks = (count + BLOCK_SIZE - 1) / BLOCK_SIZE;
    // Header: count (4 bytes), block_size (2 bytes) = 6 bytes
    // Per block: min(2 bytes f16), max(2 bytes f16), 8 bytes nibbles = 12 bytes
    const total_bytes = 6 + num_blocks * 12;
    const out_buf = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(count), .little);
    std.mem.writeInt(u16, out_buf[4..6], @intCast(BLOCK_SIZE), .little);

    var offset: usize = 6;
    var b_idx: usize = 0;
    while (b_idx < num_blocks) : (b_idx += 1) {
        const start = b_idx * BLOCK_SIZE;
        const end = @min(start + BLOCK_SIZE, count);
        const blk_slice = data[start..end];

        var b_min: f32 = blk_slice[0];
        var b_max: f32 = blk_slice[0];
        for (blk_slice[1..]) |v| {
            if (v < b_min) b_min = v;
            if (v > b_max) b_max = v;
        }

        const h_min: f16 = @floatCast(b_min);
        const h_max: f16 = @floatCast(b_max);
        std.mem.writeInt(u16, out_buf[offset .. offset + 2][0..2], @bitCast(h_min), .little);
        std.mem.writeInt(u16, out_buf[offset + 2 .. offset + 4][0..2], @bitCast(h_max), .little);
        offset += 4;

        const b_range = b_max - b_min;
        const inv_s: f32 = if (b_range > 1e-12) 15.0 / b_range else 0.0;

        var k: usize = 0;
        while (k < BLOCK_SIZE) : (k += 2) {
            const v0 = if (start + k < count) data[start + k] else b_min;
            const q0: u8 = if (b_range > 1e-12) @intFromFloat(@round(@min(15.0, @max(0.0, (v0 - b_min) * inv_s)))) else 0;

            const v1 = if (start + k + 1 < count) data[start + k + 1] else b_min;
            const q1: u8 = if (b_range > 1e-12) @intFromFloat(@round(@min(15.0, @max(0.0, (v1 - b_min) * inv_s)))) else 0;

            out_buf[offset + (k / 2)] = (q0 & 0x0F) | ((q1 & 0x0F) << 4);
        }
        offset += (BLOCK_SIZE / 2);
    }

    return out_buf;
}

pub fn blockQuantDecompressInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 6) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (count == 0) return;

    const blk_size: usize = std.mem.readInt(u16, comp_data[4..6], .little);
    if (blk_size != BLOCK_SIZE) return error.UnsupportedBlockSize;
    const num_blocks = (count + blk_size - 1) / blk_size;

    var offset: usize = 6;
    for (0..num_blocks) |b_idx| {
        if (offset + 12 > comp_data.len) return error.TruncatedStream;
        const u_min = std.mem.readInt(u16, comp_data[offset .. offset + 2][0..2], .little);
        const u_max = std.mem.readInt(u16, comp_data[offset + 2 .. offset + 4][0..2], .little);
        offset += 4;

        const h_min: f16 = @bitCast(u_min);
        const h_max: f16 = @bitCast(u_max);
        const b_min: f32 = @floatCast(h_min);
        const b_max: f32 = @floatCast(h_max);
        const b_range = b_max - b_min;
        const s: f32 = b_range / 15.0;

        const start = b_idx * blk_size;
        var k: usize = 0;
        while (k < blk_size) : (k += 2) {
            const b = comp_data[offset + (k / 2)];
            const q0 = b & 0x0F;
            const q1 = (b >> 4) & 0x0F;

            if (start + k < count) {
                out_slice[start + k] = b_min + (@as(f32, @floatFromInt(q0)) * s);
            }
            if (start + k + 1 < count) {
                out_slice[start + k + 1] = b_min + (@as(f32, @floatFromInt(q1)) * s);
            }
        }
        offset += (blk_size / 2);
    }
}
