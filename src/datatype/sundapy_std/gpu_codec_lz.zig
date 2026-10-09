const std = @import("std");

// ============================================================================
// High-Speed Lossless RLE and Dictionary LZ Compression Codecs
// Pure native Zig implementations optimized for framebuffers, screen buffers,
// sparse tensors, indices, and homogeneous simulation grids
// ============================================================================

const HASH_TABLE_SIZE: usize = 2048;

// ----------------------------------------------------------------------------
// Run-Length Encoding (RLE) for Floats & Framebuffers
// ----------------------------------------------------------------------------

pub fn rleCompressFloats(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const count = data.len;
    if (count == 0) {
        const out = try allocator.alloc(u8, 4);
        std.mem.writeInt(u32, out[0..4], 0, .little);
        return out;
    }

    // Allocate worst-case: 4 bytes count + count * (2 bytes len + 4 bytes val)
    var out_buf = try allocator.alloc(u8, 4 + count * 6);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(count), .little);
    var out_pos: usize = 4;

    var i: usize = 0;
    while (i < count) {
        const curr_val = data[i];
        var run_len: usize = 1;
        while (i + run_len < count and data[i + run_len] == curr_val and run_len < 65535) {
            run_len += 1;
        }

        std.mem.writeInt(u16, out_buf[out_pos .. out_pos + 2][0..2], @intCast(run_len), .little);
        const u_val: u32 = @bitCast(curr_val);
        std.mem.writeInt(u32, out_buf[out_pos + 2 .. out_pos + 6][0..4], u_val, .little);
        out_pos += 6;
        i += run_len;
    }

    return try allocator.realloc(out_buf, out_pos);
}

pub fn rleDecompressFloatsInto(comp_data: []const u8, out_slice: []f32) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const count: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (count > out_slice.len) return error.BufferTooSmall;
    if (count == 0) return;

    var pos: usize = 4;
    var dest_idx: usize = 0;

    while (pos + 6 <= comp_data.len and dest_idx < count) {
        const run_len: usize = std.mem.readInt(u16, comp_data[pos .. pos + 2][0..2], .little);
        const u_val = std.mem.readInt(u32, comp_data[pos + 2 .. pos + 6][0..4], .little);
        const f_val: f32 = @bitCast(u_val);
        pos += 6;

        const end_idx = @min(dest_idx + run_len, count);
        @memset(out_slice[dest_idx..end_idx], f_val);
        dest_idx = end_idx;
    }
}

// ----------------------------------------------------------------------------
// Fast LZ Byte-Level Dictionary Compressor
// ----------------------------------------------------------------------------

pub fn lzCompressBytes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const in_len = input.len;
    if (in_len == 0) {
        const out = try allocator.alloc(u8, 4);
        std.mem.writeInt(u32, out[0..4], 0, .little);
        return out;
    }

    var out_buf = try allocator.alloc(u8, 4 + in_len + (in_len / 4) + 64);
    errdefer allocator.free(out_buf);

    std.mem.writeInt(u32, out_buf[0..4], @intCast(in_len), .little);
    var out_pos: usize = 4;

    var hash_table: [HASH_TABLE_SIZE]u32 = [_]u32{0} ** HASH_TABLE_SIZE;
    var in_pos: usize = 0;
    var anchor: usize = 0;

    while (in_pos + 4 < in_len) {
        const word = std.mem.readInt(u32, input[in_pos .. in_pos + 4][0..4], .little);
        const h = ((word *% 2654435761) >> 21) & (HASH_TABLE_SIZE - 1);
        const ref_pos = hash_table[h];
        hash_table[h] = @intCast(in_pos);

        if (ref_pos < in_pos and (in_pos - ref_pos) < 65535 and
            std.mem.readInt(u32, input[ref_pos .. ref_pos + 4][0..4], .little) == word)
        {
            var match_len: usize = 4;
            while (in_pos + match_len < in_len and input[ref_pos + match_len] == input[in_pos + match_len] and match_len < 65535) {
                match_len += 1;
            }

            // Emit literals from anchor .. in_pos
            const lit_len = in_pos - anchor;
            // Token: bit 7 = has_match (1), lower 7 bits = min(lit_len, 127)
            const lit_token: u8 = @intCast(@min(127, lit_len));
            out_buf[out_pos] = 0x80 | lit_token;
            out_pos += 1;

            if (lit_token == 127) {
                // Write remaining lit_len as u16
                const rem = lit_len - 127;
                std.mem.writeInt(u16, out_buf[out_pos .. out_pos + 2][0..2], @intCast(rem), .little);
                out_pos += 2;
            }

            @memcpy(out_buf[out_pos .. out_pos + lit_len], input[anchor .. anchor + lit_len]);
            out_pos += lit_len;

            // Emit match: offset (u16) and match_len (u16)
            const offset: u16 = @intCast(in_pos - ref_pos);
            std.mem.writeInt(u16, out_buf[out_pos .. out_pos + 2][0..2], offset, .little);
            std.mem.writeInt(u16, out_buf[out_pos + 2 .. out_pos + 4][0..2], @intCast(match_len), .little);
            out_pos += 4;

            in_pos += match_len;
            anchor = in_pos;
            continue;
        }

        in_pos += 1;
    }

    // Emit remaining literals
    const rem_len = in_len - anchor;
    if (rem_len > 0) {
        const lit_token: u8 = @intCast(@min(127, rem_len));
        out_buf[out_pos] = lit_token; // bit 7 = 0 (no match follows)
        out_pos += 1;

        if (lit_token == 127) {
            const extra = rem_len - 127;
            std.mem.writeInt(u16, out_buf[out_pos .. out_pos + 2][0..2], @intCast(extra), .little);
            out_pos += 2;
        }

        @memcpy(out_buf[out_pos .. out_pos + rem_len], input[anchor .. anchor + rem_len]);
        out_pos += rem_len;
    }

    return try allocator.realloc(out_buf, out_pos);
}

pub fn lzDecompressBytesInto(comp_data: []const u8, out_bytes: []u8) !void {
    if (comp_data.len < 4) return error.InvalidData;
    const orig_len: usize = std.mem.readInt(u32, comp_data[0..4], .little);
    if (orig_len > out_bytes.len) return error.BufferTooSmall;
    if (orig_len == 0) return;

    var in_pos: usize = 4;
    var out_pos: usize = 0;

    while (in_pos < comp_data.len and out_pos < orig_len) {
        const token = comp_data[in_pos];
        in_pos += 1;

        const has_match = (token & 0x80) != 0;
        var lit_len: usize = token & 0x7F;
        if (lit_len == 127) {
            if (in_pos + 2 > comp_data.len) return error.TruncatedStream;
            const extra = std.mem.readInt(u16, comp_data[in_pos .. in_pos + 2][0..2], .little);
            in_pos += 2;
            lit_len += extra;
        }

        if (lit_len > 0) {
            if (in_pos + lit_len > comp_data.len or out_pos + lit_len > orig_len) return error.TruncatedStream;
            @memcpy(out_bytes[out_pos .. out_pos + lit_len], comp_data[in_pos .. in_pos + lit_len]);
            in_pos += lit_len;
            out_pos += lit_len;
        }

        if (has_match) {
            if (in_pos + 4 > comp_data.len) return error.TruncatedStream;
            const offset: usize = std.mem.readInt(u16, comp_data[in_pos .. in_pos + 2][0..2], .little);
            const match_len: usize = std.mem.readInt(u16, comp_data[in_pos + 2 .. in_pos + 4][0..2], .little);
            in_pos += 4;

            if (offset == 0 or offset > out_pos or out_pos + match_len > orig_len) return error.CorruptMatchOffset;
            const match_src = out_pos - offset;
            for (0..match_len) |m| {
                out_bytes[out_pos + m] = out_bytes[match_src + m];
            }
            out_pos += match_len;
        }
    }
}

pub fn lzCompressFloats(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    const byte_slice: []const u8 = @as([*]const u8, @ptrCast(data.ptr))[0 .. data.len * @sizeOf(f32)];
    return lzCompressBytes(allocator, byte_slice);
}

pub fn lzDecompressFloatsInto(comp_data: []const u8, out_slice: []f32) !void {
    const byte_slice: []u8 = @as([*]u8, @ptrCast(out_slice.ptr))[0 .. out_slice.len * @sizeOf(f32)];
    return lzDecompressBytesInto(comp_data, byte_slice);
}
