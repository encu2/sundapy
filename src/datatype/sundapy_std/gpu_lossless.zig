const std = @import("std");

// ============================================================================
// GPU VRAM Lossless Compression Engine
// Implements: Hardware Bit-Plane Compression (BPC) and Delta-ZigZag-RLE
// ============================================================================

pub const MAGIC_LOSSLESS: u32 = 0x5350435A; // "SPCZ" (SundaPy Compressed ZigZag)

pub const LosslessMethod = enum(u8) {
    bpc = 1,
    delta_rle = 2,
};

// Checksum helper (FNV-1a 32-bit)
pub fn compute_checksum(data: []const u8) u32 {
    var hash: u32 = 0x811C9DC5;
    for (data) |b| {
        hash ^= b;
        hash = hash *% 0x01000193;
    }
    return hash;
}

// --- Bit-Plane Compression (BPC) for 32x32-bit Words ---
// Transposes 32 words into 32 bit-planes, detecting zero/one planes and deltas.

pub fn compress_bpc_block(words: *const [32]u32, out: *std.ArrayList(u8)) !void {
    // 1. Bit-Plane Transposition
    var planes: [32]u32 = [_]u32{0} ** 32;
    for (0..32) |w| {
        const word = words[w];
        for (0..32) |p| {
            if (((word >> @intCast(p)) & 1) != 0) {
                planes[p] |= (@as(u32, 1) << @intCast(w));
            }
        }
    }

    // 2. Encode 32 bit-planes
    // Tags: 00: all-zeros, 01: all-ones, 10: delta-identical to prev, 11: raw 32-bit word
    var tag_bits: u64 = 0;
    var raw_planes: [32]u32 = undefined;
    var raw_count: usize = 0;

    var prev_plane: u32 = 0;
    for (planes, 0..) |plane, p| {
        const shift: u6 = @intCast(p * 2);
        if (plane == 0) {
            // tag 00
        } else if (plane == 0xFFFFFFFF) {
            tag_bits |= (@as(u64, 1) << shift); // tag 01
        } else if (p > 0 and plane == prev_plane) {
            tag_bits |= (@as(u64, 2) << shift); // tag 10
        } else {
            tag_bits |= (@as(u64, 3) << shift); // tag 11
            raw_planes[raw_count] = plane;
            raw_count += 1;
        }
        prev_plane = plane;
    }

    // Write 8-byte tag mask
    var tag_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &tag_bytes, tag_bits, .little);
    try out.appendSlice(std.heap.c_allocator, &tag_bytes);

    // Write raw planes
    for (0..raw_count) |i| {
        var word_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &word_bytes, raw_planes[i], .little);
        try out.appendSlice(std.heap.c_allocator, &word_bytes);
    }
}

pub fn decompress_bpc_block(in: []const u8, in_offset: *usize, words: *[32]u32) !void {
    if (in_offset.* + 8 > in.len) return error.UnexpectedEof;
    const tag_bits = std.mem.readInt(u64, in[in_offset.*..][0..8], .little);
    in_offset.* += 8;

    var planes: [32]u32 = [_]u32{0} ** 32;
    var prev_plane: u32 = 0;
    for (0..32) |p| {
        const shift: u6 = @intCast(p * 2);
        const tag: u2 = @truncate((tag_bits >> shift) & 0x03);
        const plane: u32 = switch (tag) {
            0 => 0,
            1 => 0xFFFFFFFF,
            2 => prev_plane,
            3 => blk: {
                if (in_offset.* + 4 > in.len) return error.UnexpectedEof;
                const rw = std.mem.readInt(u32, in[in_offset.*..][0..4], .little);
                in_offset.* += 4;
                break :blk rw;
            },
        };
        planes[p] = plane;
        prev_plane = plane;
    }

    // Inverse Bit-Plane Transposition
    for (0..32) |w| {
        var word: u32 = 0;
        for (0..32) |p| {
            if (((planes[p] >> @intCast(w)) & 1) != 0) {
                word |= (@as(u32, 1) << @intCast(p));
            }
        }
        words[w] = word;
    }
}

// --- Delta-ZigZag-RLE Encoder for High-Throughput Memory Buffers ---

inline fn zigzag_encode(val: i32) u32 {
    return @bitCast((val << 1) ^ (val >> 31));
}

inline fn zigzag_decode(val: u32) i32 {
    const v: i32 = @bitCast(val);
    return (v >> 1) ^ -(v & 1);
}

pub fn compress_delta_rle(input: []const u8, out: *std.ArrayList(u8)) !void {
    if (input.len == 0) return;
    const num_words = input.len / 4;

    var prev: i32 = 0;
    var i: usize = 0;
    while (i < num_words) {
        const curr = std.mem.readInt(i32, input[i * 4 ..][0..4], .little);
        const diff = curr -% prev;
        prev = curr;
        const z = zigzag_encode(diff);

        // Check for run of identical words (delta = 0)
        if (z == 0) {
            var run: usize = 1;
            while (i + run < num_words and std.mem.readInt(i32, input[(i + run) * 4 ..][0..4], .little) == curr and run < 255) {
                run += 1;
            }
            if (run >= 3) {
                // Emit RLE token: 0x80 | run
                try out.append(std.heap.c_allocator, 0x80 | @as(u8, @intCast(run)));
                i += run;
                continue;
            }
        }

        // Variable length integer encoding (LEB-like)
        if (z < 0x80) {
            try out.append(std.heap.c_allocator, @intCast(z));
        } else if (z < 0x4000) {
            try out.append(std.heap.c_allocator, @as(u8, @intCast(0x80 | (z & 0x7F))));
            try out.append(std.heap.c_allocator, @as(u8, @intCast((z >> 7) & 0x7F)));
        } else {
            try out.append(std.heap.c_allocator, 0xFF);
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, &buf, z, .little);
            try out.appendSlice(std.heap.c_allocator, &buf);
        }
        i += 1;
    }

    // Remainder bytes
    const rem = input.len % 4;
    if (rem > 0) {
        const tail = input[num_words * 4 ..];
        try out.appendSlice(std.heap.c_allocator, tail);
    }
}

pub fn decompress_delta_rle(compressed: []const u8, out: []u8) !void {
    if (out.len == 0) return;
    const num_words = out.len / 4;

    var in_pos: usize = 0;
    var out_pos: usize = 0;
    var prev: i32 = 0;

    while (in_pos < compressed.len and out_pos < num_words) {
        const b = compressed[in_pos];
        in_pos += 1;

        if ((b & 0x80) != 0 and b != 0xFF) {
            // Run of identical values
            const run_len: usize = b & 0x7F;
            for (0..run_len) |_| {
                if (out_pos < num_words) {
                    std.mem.writeInt(i32, out[out_pos * 4 ..][0..4], prev, .little);
                    out_pos += 1;
                }
            }
            continue;
        }

        var z: u32 = 0;
        if (b == 0xFF) {
            if (in_pos + 4 > compressed.len) return error.CorruptData;
            z = std.mem.readInt(u32, compressed[in_pos..][0..4], .little);
            in_pos += 4;
        } else {
            z = b;
        }

        const diff = zigzag_decode(z);
        prev = prev +% diff;
        std.mem.writeInt(i32, out[out_pos * 4 ..][0..4], prev, .little);
        out_pos += 1;
    }

    const rem = out.len % 4;
    if (rem > 0 and in_pos + rem <= compressed.len) {
        @memcpy(out[num_words * 4 ..], compressed[in_pos .. in_pos + rem]);
    }
}

// --- Top-Level Lossless VRAM Compress / Decompress Routines ---

pub fn compress_lossless(allocator: std.mem.Allocator, input: []const u8, method: LosslessMethod) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    // 1. Write Header: Magic (4B), Method (1B), Reserved (3B), Original Size (8B), Checksum (4B)
    var hdr: [20]u8 = undefined;
    std.mem.writeInt(u32, hdr[0..4], MAGIC_LOSSLESS, .little);
    hdr[4] = @intFromEnum(method);
    hdr[5] = 0;
    hdr[6] = 0;
    hdr[7] = 0;
    std.mem.writeInt(u64, hdr[8..16], input.len, .little);
    const checksum = compute_checksum(input);
    std.mem.writeInt(u32, hdr[16..20], checksum, .little);
    try out.appendSlice(allocator, &hdr);

    // 2. Encode Payload
    if (method == .bpc and input.len >= 128) {
        const full_blocks = input.len / 128;
        const words_ptr: [*]const [32]u32 = @ptrCast(@alignCast(input.ptr));
        for (0..full_blocks) |b| {
            try compress_bpc_block(&words_ptr[b], &out);
        }
        const rem_bytes = input[full_blocks * 128 ..];
        if (rem_bytes.len > 0) {
            try compress_delta_rle(rem_bytes, &out);
        }
    } else {
        try compress_delta_rle(input, &out);
    }

    return out.toOwnedSlice(allocator);
}

pub fn decompress_lossless(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    if (compressed.len < 20) return error.InvalidHeader;
    const magic = std.mem.readInt(u32, compressed[0..4], .little);
    if (magic != MAGIC_LOSSLESS) return error.InvalidMagic;

    const method: LosslessMethod = @enumFromInt(compressed[4]);
    const orig_size: usize = @intCast(std.mem.readInt(u64, compressed[8..16], .little));
    const expected_checksum = std.mem.readInt(u32, compressed[16..20], .little);

    const out = try allocator.alloc(u8, orig_size);
    errdefer allocator.free(out);

    const payload = compressed[20..];
    if (method == .bpc and orig_size >= 128) {
        const full_blocks = orig_size / 128;
        const words_ptr: [*][32]u32 = @ptrCast(@alignCast(out.ptr));
        var in_pos: usize = 0;
        for (0..full_blocks) |b| {
            try decompress_bpc_block(payload, &in_pos, &words_ptr[b]);
        }
        const rem_len = orig_size - full_blocks * 128;
        if (rem_len > 0 and in_pos < payload.len) {
            try decompress_delta_rle(payload[in_pos..], out[full_blocks * 128 ..]);
        }
    } else {
        try decompress_delta_rle(payload, out);
    }

    const actual_checksum = compute_checksum(out);
    if (actual_checksum != expected_checksum) {
        return error.ChecksumMismatch;
    }
    return out;
}
