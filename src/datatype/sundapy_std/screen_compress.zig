const std = @import("std");
pub const tile = @import("screen_compress_tile.zig");

// ============================================================================
// Screen & Framebuffer Memory Compression Engine
// Ultra-high compression: Delta frame, Tile Palettes, RLE, Zero-Copy Scanout
// ============================================================================

pub const TILE_SIZE: usize = tile.TILE_SIZE;
pub const TileType = tile.TileType;

pub var stats_total_uncompressed: u64 = 0;
pub var stats_total_compressed: u64 = 0;
pub var stats_saved_bandwidth: u64 = 0;
pub var stats_clean_tiles: u32 = 0;
pub var stats_solid_tiles: u32 = 0;
pub var stats_palette2_tiles: u32 = 0;
pub var stats_palette4_tiles: u32 = 0;
pub var stats_rle_tiles: u32 = 0;
pub var stats_raw_tiles: u32 = 0;
pub var stats_last_ratio: f64 = 1.0;

pub fn getCompressionRatio() f64 {
    if (stats_total_compressed == 0) return 1.0;
    return @as(f64, @floatFromInt(stats_total_uncompressed)) / @as(f64, @floatFromInt(stats_total_compressed));
}

pub fn getSavedBandwidthMb() f64 {
    return @as(f64, @floatFromInt(stats_saved_bandwidth)) / (1024.0 * 1024.0);
}

pub fn resetStats() void {
    stats_total_uncompressed = 0;
    stats_total_compressed = 0;
    stats_saved_bandwidth = 0;
    stats_clean_tiles = 0;
    stats_solid_tiles = 0;
    stats_palette2_tiles = 0;
    stats_palette4_tiles = 0;
    stats_rle_tiles = 0;
    stats_raw_tiles = 0;
    stats_last_ratio = 1.0;
}

pub const checkTileEqual = tile.checkTileEqual;
pub const checkTileSolid = tile.checkTileSolid;
pub const compressTilePalette2 = tile.compressTilePalette2;
pub const compressTilePalette4 = tile.compressTilePalette4;
pub const compressTileRle = tile.compressTileRle;
pub const compressTileDeltaRle = tile.compressTileDeltaRle;
pub const decompressTile = tile.decompressTile;

pub fn compressTile(
    curr: [*]const u32,
    prev: ?[*]const u32,
    tile_w: usize,
    tile_h: usize,
    stride_curr: usize,
    stride_prev: usize,
    out: []u8,
) struct { tile_type: TileType, bytes_written: usize } {
    const raw_bytes = tile_w * tile_h * 4;
    stats_total_uncompressed += raw_bytes;

    // 1. Delta check (identical clean tile)
    if (prev) |p| {
        if (checkTileEqual(curr, p, tile_w, tile_h, stride_curr, stride_prev)) {
            stats_clean_tiles += 1;
            stats_saved_bandwidth += raw_bytes;
            return .{ .tile_type = .clean, .bytes_written = 0 };
        }
    }

    // 2. Solid color check (1024 bytes -> 4 bytes, 256:1)
    if (checkTileSolid(curr, tile_w, tile_h, stride_curr)) |solid_color| {
        if (out.len >= 4) {
            std.mem.writeInt(u32, out[0..4], solid_color, .little);
            stats_solid_tiles += 1;
            stats_total_compressed += 4;
            stats_saved_bandwidth += (raw_bytes - 4);
            return .{ .tile_type = .solid, .bytes_written = 4 };
        }
    }

    // 3. 2-Color Palette (1024 bytes -> 40 bytes, 25.6:1)
    if (tile_w == TILE_SIZE and tile_h == TILE_SIZE) {
        if (compressTilePalette2(curr, tile_w, tile_h, stride_curr, out)) |p2_len| {
            stats_palette2_tiles += 1;
            stats_total_compressed += p2_len;
            stats_saved_bandwidth += (raw_bytes - p2_len);
            return .{ .tile_type = .palette2, .bytes_written = p2_len };
        }
    }

    // 4. 4-Color Palette (1024 bytes -> 80 bytes, 12.8:1)
    if (tile_w == TILE_SIZE and tile_h == TILE_SIZE) {
        if (compressTilePalette4(curr, tile_w, tile_h, stride_curr, out)) |p4_len| {
            stats_palette4_tiles += 1;
            stats_total_compressed += p4_len;
            stats_saved_bandwidth += (raw_bytes - p4_len);
            return .{ .tile_type = .palette4, .bytes_written = p4_len };
        }
    }

    // 5. Delta-RLE check if previous frame exists
    if (prev) |p| {
        const delta_len = compressTileDeltaRle(curr, p, tile_w, tile_h, stride_curr, stride_prev, out);
        if (delta_len > 0 and delta_len < raw_bytes) {
            stats_rle_tiles += 1;
            stats_total_compressed += delta_len;
            stats_saved_bandwidth += (raw_bytes - delta_len);
            return .{ .tile_type = .delta_rle, .bytes_written = delta_len };
        }
    }

    // 6. Standard RLE check
    const rle_len = compressTileRle(curr, tile_w, tile_h, stride_curr, out);
    if (rle_len > 0 and rle_len < raw_bytes) {
        stats_rle_tiles += 1;
        stats_total_compressed += rle_len;
        stats_saved_bandwidth += (raw_bytes - rle_len);
        return .{ .tile_type = .rle, .bytes_written = rle_len };
    }

    // 7. Raw uncompressed fallback
    var out_pos: usize = 0;
    for (0..tile_h) |y| {
        const row = curr + y * stride_curr;
        const row_bytes = tile_w * 4;
        if (out_pos + row_bytes <= out.len) {
            @memcpy(out[out_pos .. out_pos + row_bytes], @as([*]const u8, @ptrCast(row))[0..row_bytes]);
            out_pos += row_bytes;
        }
    }
    stats_raw_tiles += 1;
    stats_total_compressed += out_pos;
    return .{ .tile_type = .raw, .bytes_written = out_pos };
}

pub fn compressFrame(
    curr: [*]const u32,
    prev: ?[*]const u32,
    w: usize,
    h: usize,
    out: []u8,
) !usize {
    const tiles_x = (w + TILE_SIZE - 1) / TILE_SIZE;
    const tiles_y = (h + TILE_SIZE - 1) / TILE_SIZE;
    const total_tiles = tiles_x * tiles_y;

    // Header: Magic 'SPCZ' (4B) + w (2B) + h (2B) + total_tiles (4B) = 12B
    if (out.len < 12 + total_tiles * 2) return error.BufferTooSmall;

    @memcpy(out[0..4], "SPCZ");
    std.mem.writeInt(u16, out[4..6], @intCast(w), .little);
    std.mem.writeInt(u16, out[6..8], @intCast(h), .little);
    std.mem.writeInt(u32, out[8..12], @intCast(total_tiles), .little);

    var write_pos: usize = 12;
    var tile_temp: [TILE_SIZE * TILE_SIZE * 4]u8 = undefined;

    for (0..tiles_y) |ty| {
        const py = ty * TILE_SIZE;
        const th = @min(TILE_SIZE, h - py);
        for (0..tiles_x) |tx| {
            const px = tx * TILE_SIZE;
            const tw = @min(TILE_SIZE, w - px);

            const curr_ptr = curr + py * w + px;
            const prev_ptr: ?[*]const u32 = if (prev) |p| p + py * w + px else null;

            const res = compressTile(curr_ptr, prev_ptr, tw, th, w, w, &tile_temp);

            if (write_pos + 3 + res.bytes_written > out.len) return error.BufferTooSmall;
            out[write_pos] = @intFromEnum(res.tile_type);
            std.mem.writeInt(u16, out[write_pos + 1 .. write_pos + 3][0..2], @intCast(res.bytes_written), .little);
            write_pos += 3;

            if (res.bytes_written > 0) {
                @memcpy(out[write_pos .. write_pos + res.bytes_written], tile_temp[0..res.bytes_written]);
                write_pos += res.bytes_written;
            }
        }
    }

    stats_last_ratio = getCompressionRatio();
    return write_pos;
}

pub fn decompressFrame(
    in: []const u8,
    prev: ?[*]const u32,
    dst: [*]u32,
    w: usize,
    h: usize,
) !void {
    if (in.len < 12) return error.InvalidData;
    if (!std.mem.eql(u8, in[0..4], "SPCZ")) return error.InvalidData;

    const fw = std.mem.readInt(u16, in[4..6], .little);
    const fh = std.mem.readInt(u16, in[6..8], .little);
    if (fw != w or fh != h) return error.DimensionMismatch;

    const tiles_x = (w + TILE_SIZE - 1) / TILE_SIZE;
    const tiles_y = (h + TILE_SIZE - 1) / TILE_SIZE;

    var read_pos: usize = 12;
    for (0..tiles_y) |ty| {
        const py = ty * TILE_SIZE;
        const th = @min(TILE_SIZE, h - py);
        for (0..tiles_x) |tx| {
            const px = tx * TILE_SIZE;
            const tw = @min(TILE_SIZE, w - px);

            if (read_pos + 3 > in.len) return error.InvalidData;
            const tile_type: TileType = @enumFromInt(in[read_pos]);
            const payload_len = std.mem.readInt(u16, in[read_pos + 1 .. read_pos + 3][0..2], .little);
            read_pos += 3;

            if (read_pos + payload_len > in.len) return error.InvalidData;
            const tile_payload = in[read_pos .. read_pos + payload_len];
            read_pos += payload_len;

            const dst_ptr = dst + py * w + px;
            const prev_ptr: ?[*]const u32 = if (prev) |p| p + py * w + px else null;

            decompressTile(tile_type, tile_payload, prev_ptr, dst_ptr, tw, th, w, w);
        }
    }
}

test "tile solid compression round-trip" {
    resetStats();
    var src = [_]u32{0xFF112233} ** 256;
    var dst = [_]u32{0} ** 256;
    var out_buf: [1024]u8 = undefined;

    const res = compressTile(&src, null, 16, 16, 16, 16, &out_buf);
    try std.testing.expectEqual(TileType.solid, res.tile_type);
    try std.testing.expectEqual(@as(usize, 4), res.bytes_written);

    decompressTile(res.tile_type, out_buf[0..res.bytes_written], null, &dst, 16, 16, 16, 16);
    try std.testing.expectEqualSlices(u32, &src, &dst);
}

test "tile palette2 compression round-trip" {
    resetStats();
    var src = [_]u32{0xFF112233} ** 256;
    for (0..128) |i| src[i] = 0xFFAABBCC;
    var dst = [_]u32{0} ** 256;
    var out_buf: [1024]u8 = undefined;

    const res = compressTile(&src, null, 16, 16, 16, 16, &out_buf);
    try std.testing.expectEqual(TileType.palette2, res.tile_type);
    try std.testing.expectEqual(@as(usize, 40), res.bytes_written);

    decompressTile(res.tile_type, out_buf[0..res.bytes_written], null, &dst, 16, 16, 16, 16);
    try std.testing.expectEqualSlices(u32, &src, &dst);
}

test "tile delta clean detection" {
    resetStats();
    var src = [_]u32{0xFF556677} ** 256;
    var prev = [_]u32{0xFF556677} ** 256;
    var out_buf: [1024]u8 = undefined;

    const res = compressTile(&src, &prev, 16, 16, 16, 16, &out_buf);
    try std.testing.expectEqual(TileType.clean, res.tile_type);
    try std.testing.expectEqual(@as(usize, 0), res.bytes_written);
}

test "frame compress and decompress round-trip" {
    resetStats();
    const w = 32;
    const h = 32;
    var frame_src = [_]u32{0xFF00AA55} ** (w * h);
    // Add some variation in quadrant 1
    for (0..16) |y| {
        for (0..16) |x| {
            frame_src[y * w + x] = if ((x + y) % 2 == 0) 0xFFFFFFFF else 0xFF000000;
        }
    }
    var frame_dst = [_]u32{0} ** (w * h);
    var compressed: [4096]u8 = undefined;

    const comp_size = try compressFrame(&frame_src, null, w, h, &compressed);
    try std.testing.expect(comp_size > 0 and comp_size < w * h * 4);

    try decompressFrame(compressed[0..comp_size], null, &frame_dst, w, h);
    try std.testing.expectEqualSlices(u32, &frame_src, &frame_dst);
}
