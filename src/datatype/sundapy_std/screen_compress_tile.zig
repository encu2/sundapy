const std = @import("std");

// ============================================================================
// Tile-Level Compression Codecs (Ultra-High Density Block Encoders)
// Clean (0B), Solid (4B), Palette-2 (40B), Palette-4 (80B), Delta-RLE, RLE, Raw
// ============================================================================

pub const TILE_SIZE: usize = 16;
pub const TILE_PIXELS: usize = TILE_SIZE * TILE_SIZE; // 256 pixels
pub const TILE_RAW_BYTES: usize = TILE_PIXELS * 4; // 1024 bytes

pub const TileType = enum(u8) {
    clean = 0,
    solid = 1,
    palette2 = 2,
    palette4 = 3,
    rle = 4,
    delta_rle = 5,
    raw = 6,
};

pub fn checkTileEqual(a: [*]const u32, b: [*]const u32, w: usize, h: usize, sa: usize, sb: usize) bool {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const ra = a + y * sa;
        const rb = b + y * sb;
        var x: usize = 0;
        while (x + 2 <= w) : (x += 2) {
            const p64_a: *const u64 = @ptrCast(@alignCast(ra + x));
            const p64_b: *const u64 = @ptrCast(@alignCast(rb + x));
            if (p64_a.* != p64_b.*) return false;
        }
        while (x < w) : (x += 1) {
            if (ra[x] != rb[x]) return false;
        }
    }
    return true;
}

pub fn checkTileSolid(src: [*]const u32, w: usize, h: usize, stride: usize) ?u32 {
    const first = src[0];
    const first64: u64 = (@as(u64, first) << 32) | @as(u64, first);
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const row = src + y * stride;
        var x: usize = 0;
        while (x + 2 <= w) : (x += 2) {
            const p64: *const u64 = @ptrCast(@alignCast(row + x));
            if (p64.* != first64) return null;
        }
        while (x < w) : (x += 1) {
            if (row[x] != first) return null;
        }
    }
    return first;
}

pub fn compressTilePalette2(src: [*]const u32, w: usize, h: usize, stride: usize, out: []u8) ?usize {
    if (w != TILE_SIZE or h != TILE_SIZE or out.len < 40) return null;
    var colors = [2]u32{ src[0], 0 };
    var num_colors: usize = 1;

    for (0..TILE_SIZE) |y| {
        const row = src + y * stride;
        for (0..TILE_SIZE) |x| {
            const px = row[x];
            if (px != colors[0]) {
                if (num_colors == 1) {
                    colors[1] = px;
                    num_colors = 2;
                } else if (px != colors[1]) return null;
            }
        }
    }
    if (num_colors != 2) return null;

    std.mem.writeInt(u32, out[0..4], colors[0], .little);
    std.mem.writeInt(u32, out[4..8], colors[1], .little);
    var bitmask = out[8..40];
    @memset(bitmask, 0);

    var bit_idx: usize = 0;
    for (0..TILE_SIZE) |y| {
        const row = src + y * stride;
        for (0..TILE_SIZE) |x| {
            if (row[x] == colors[1]) {
                bitmask[bit_idx / 8] |= (@as(u8, 1) << @as(u3, @intCast(bit_idx % 8)));
            }
            bit_idx += 1;
        }
    }
    return 40;
}

pub fn compressTilePalette4(src: [*]const u32, w: usize, h: usize, stride: usize, out: []u8) ?usize {
    if (w != TILE_SIZE or h != TILE_SIZE or out.len < 80) return null;
    var colors = [4]u32{ src[0], 0, 0, 0 };
    var num_colors: usize = 1;

    for (0..TILE_SIZE) |y| {
        const row = src + y * stride;
        for (0..TILE_SIZE) |x| {
            const px = row[x];
            var found = false;
            for (0..num_colors) |ci| {
                if (colors[ci] == px) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                if (num_colors < 4) {
                    colors[num_colors] = px;
                    num_colors += 1;
                } else return null;
            }
        }
    }
    if (num_colors < 3) return null;

    for (0..4) |i| std.mem.writeInt(u32, out[i * 4 .. (i + 1) * 4][0..4], colors[i], .little);
    var indices = out[16..80];
    @memset(indices, 0);

    var px_idx: usize = 0;
    for (0..TILE_SIZE) |y| {
        const row = src + y * stride;
        for (0..TILE_SIZE) |x| {
            const px = row[x];
            var ci: u2 = 0;
            if (px == colors[1]) ci = 1 else if (px == colors[2]) ci = 2 else if (px == colors[3]) ci = 3;
            indices[px_idx / 4] |= (@as(u8, ci) << @as(u3, @intCast((px_idx % 4) * 2)));
            px_idx += 1;
        }
    }
    return 80;
}

pub fn compressTileRle(src: [*]const u32, w: usize, h: usize, stride: usize, out: []u8) usize {
    if (out.len < 5) return 0;
    var out_pos: usize = 0;
    var val: u32 = src[0];
    var len: u16 = 0;

    var y: usize = 0;
    while (y < h) : (y += 1) {
        const row = src + y * stride;
        var x: usize = 0;
        while (x < w) : (x += 1) {
            const cur = row[x];
            if (cur == val and len < 255) {
                len += 1;
            } else {
                if (len > 0) {
                    if (out_pos + 5 > out.len) return 0;
                    out[out_pos] = @intCast(len);
                    std.mem.writeInt(u32, out[out_pos + 1 .. out_pos + 5][0..4], val, .little);
                    out_pos += 5;
                }
                val = cur;
                len = 1;
            }
        }
    }
    if (len > 0 and out_pos + 5 <= out.len) {
        out[out_pos] = @intCast(len);
        std.mem.writeInt(u32, out[out_pos + 1 .. out_pos + 5][0..4], val, .little);
        out_pos += 5;
    }
    return out_pos;
}

pub fn compressTileDeltaRle(c: [*]const u32, p: [*]const u32, w: usize, h: usize, sc: usize, sp: usize, out: []u8) usize {
    if (out.len < 5) return 0;
    var out_pos: usize = 0;
    var delta: u32 = c[0] ^ p[0];
    var len: u16 = 0;

    var y: usize = 0;
    while (y < h) : (y += 1) {
        const rc = c + y * sc;
        const rp = p + y * sp;
        var x: usize = 0;
        while (x < w) : (x += 1) {
            const d = rc[x] ^ rp[x];
            if (d == delta and len < 255) {
                len += 1;
            } else {
                if (len > 0) {
                    if (out_pos + 5 > out.len) return 0;
                    out[out_pos] = @intCast(len);
                    std.mem.writeInt(u32, out[out_pos + 1 .. out_pos + 5][0..4], delta, .little);
                    out_pos += 5;
                }
                delta = d;
                len = 1;
            }
        }
    }
    if (len > 0 and out_pos + 5 <= out.len) {
        out[out_pos] = @intCast(len);
        std.mem.writeInt(u32, out[out_pos + 1 .. out_pos + 5][0..4], delta, .little);
        out_pos += 5;
    }
    return out_pos;
}

pub fn decompressTile(t: TileType, in: []const u8, prev: ?[*]const u32, dst: [*]u32, w: usize, h: usize, d_str: usize, p_str: usize) void {
    switch (t) {
        .clean => if (prev) |p| {
            for (0..h) |y| @memcpy(@as([*]u8, @ptrCast(dst + y * d_str))[0 .. w * 4], @as([*]const u8, @ptrCast(p + y * p_str))[0 .. w * 4]);
        },
        .solid => if (in.len >= 4) {
            const col = std.mem.readInt(u32, in[0..4], .little);
            for (0..h) |y| {
                const r = dst + y * d_str;
                for (0..w) |x| r[x] = col;
            }
        },
        .palette2 => if (in.len >= 40 and w == TILE_SIZE and h == TILE_SIZE) {
            const c0 = std.mem.readInt(u32, in[0..4], .little);
            const c1 = std.mem.readInt(u32, in[4..8], .little);
            const bm = in[8..40];
            var bi: usize = 0;
            for (0..TILE_SIZE) |y| {
                const r = dst + y * d_str;
                for (0..TILE_SIZE) |x| {
                    r[x] = if (((bm[bi / 8] >> @as(u3, @intCast(bi % 8))) & 1) != 0) c1 else c0;
                    bi += 1;
                }
            }
        },
        .palette4 => if (in.len >= 80 and w == TILE_SIZE and h == TILE_SIZE) {
            var cols: [4]u32 = undefined;
            for (0..4) |i| cols[i] = std.mem.readInt(u32, in[i * 4 .. (i + 1) * 4][0..4], .little);
            const idxs = in[16..80];
            var pi: usize = 0;
            for (0..TILE_SIZE) |y| {
                const r = dst + y * d_str;
                for (0..TILE_SIZE) |x| {
                    r[x] = cols[(idxs[pi / 4] >> @as(u3, @intCast((pi % 4) * 2))) & 3];
                    pi += 1;
                }
            }
        },
        .rle => {
            var ip: usize = 0;
            var cur: usize = 0;
            const tot = w * h;
            while (ip + 5 <= in.len and cur < tot) {
                const rlen = in[ip];
                const col = std.mem.readInt(u32, in[ip + 1 .. ip + 5][0..4], .little);
                ip += 5;
                for (0..rlen) |_| {
                    if (cur >= tot) break;
                    dst[(cur / w) * d_str + (cur % w)] = col;
                    cur += 1;
                }
            }
        },
        .delta_rle => if (prev) |p| {
            var ip: usize = 0;
            var cur: usize = 0;
            const tot = w * h;
            while (ip + 5 <= in.len and cur < tot) {
                const rlen = in[ip];
                const d = std.mem.readInt(u32, in[ip + 1 .. ip + 5][0..4], .little);
                ip += 5;
                for (0..rlen) |_| {
                    if (cur >= tot) break;
                    const dy = cur / w;
                    const dx = cur % w;
                    dst[dy * d_str + dx] = p[dy * p_str + dx] ^ d;
                    cur += 1;
                }
            }
        },
        .raw => {
            var ip: usize = 0;
            for (0..h) |y| {
                const bytes = w * 4;
                if (ip + bytes <= in.len) {
                    @memcpy(@as([*]u8, @ptrCast(dst + y * d_str))[0..bytes], in[ip .. ip + bytes]);
                    ip += bytes;
                }
            }
        },
    }
}

test "tile codecs roundtrip test" {
    var src = [_]u32{0xFF112233} ** 256;
    for (0..128) |i| src[i] = 0xFFAABBCC;
    var dst = [_]u32{0} ** 256;
    var out_buf: [1024]u8 = undefined;

    const p2_len = compressTilePalette2(&src, 16, 16, 16, &out_buf);
    try std.testing.expect(p2_len != null);
    try std.testing.expectEqual(@as(usize, 40), p2_len.?);

    decompressTile(.palette2, out_buf[0..p2_len.?], null, &dst, 16, 16, 16, 16);
    try std.testing.expectEqualSlices(u32, &src, &dst);

    for (0..64) |i| src[i] = 0xFF010203;
    for (64..128) |i| src[i] = 0xFF040506;
    for (128..192) |i| src[i] = 0xFF070809;
    for (192..256) |i| src[i] = 0xFF0A0B0C;
    @memset(&dst, 0);

    const p4_len = compressTilePalette4(&src, 16, 16, 16, &out_buf);
    try std.testing.expect(p4_len != null);
    try std.testing.expectEqual(@as(usize, 80), p4_len.?);

    decompressTile(.palette4, out_buf[0..p4_len.?], null, &dst, 16, 16, 16, 16);
    try std.testing.expectEqualSlices(u32, &src, &dst);
}
