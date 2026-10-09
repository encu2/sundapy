const std = @import("std");

// ============================================================================
// Dirty-Region Partial Update Tracker & Scanout Planner
// Zero-allocation tile bitset, bounding-box consolidation & multi-rect planner
// ============================================================================

pub const TILE_SIZE: usize = 16;
pub const MAX_TILES_HORIZ: usize = 256;
pub const MAX_TILES_VERT: usize = 144;
pub const MAX_TILES: usize = MAX_TILES_HORIZ * MAX_TILES_VERT;
pub const BITSET_WORDS: usize = (MAX_TILES + 63) / 64;

pub const DirtyRect = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

pub var dirty_bitset: [BITSET_WORDS]u64 = [_]u64{0} ** BITSET_WORDS;
pub var grid_tiles_w: usize = 0;
pub var grid_tiles_h: usize = 0;
pub var grid_pixels_w: usize = 0;
pub var grid_pixels_h: usize = 0;
pub var dirty_tile_count: usize = 0;
pub var force_full_redraw: bool = true;

// Telemetry & scanout bandwidth tracking
pub var stats_total_frames: u64 = 0;
pub var stats_clean_frames: u64 = 0;
pub var stats_partial_frames: u64 = 0;
pub var stats_saved_scanout_pixels: u64 = 0;

pub fn initGrid(width: usize, height: usize) void {
    grid_pixels_w = width;
    grid_pixels_h = height;
    grid_tiles_w = (width + TILE_SIZE - 1) / TILE_SIZE;
    grid_tiles_h = (height + TILE_SIZE - 1) / TILE_SIZE;
    if (grid_tiles_w > MAX_TILES_HORIZ) grid_tiles_w = MAX_TILES_HORIZ;
    if (grid_tiles_h > MAX_TILES_VERT) grid_tiles_h = MAX_TILES_VERT;
    markAllDirty();
}

pub fn markAllDirty() void {
    const total_tiles = grid_tiles_w * grid_tiles_h;
    const words_needed = (total_tiles + 63) / 64;
    for (0..@min(words_needed, BITSET_WORDS)) |i| {
        dirty_bitset[i] = ~@as(u64, 0);
    }
    dirty_tile_count = total_tiles;
    force_full_redraw = true;
}

pub fn clearDirty() void {
    @memset(&dirty_bitset, 0);
    dirty_tile_count = 0;
    force_full_redraw = false;
}

pub fn markTileDirty(tx: usize, ty: usize) void {
    if (tx >= grid_tiles_w or ty >= grid_tiles_h) return;
    const idx = ty * grid_tiles_w + tx;
    const word_idx = idx / 64;
    const bit_offset: u6 = @intCast(idx % 64);
    const mask = @as(u64, 1) << bit_offset;
    if ((dirty_bitset[word_idx] & mask) == 0) {
        dirty_bitset[word_idx] |= mask;
        dirty_tile_count += 1;
    }
}

pub fn isTileDirty(tx: usize, ty: usize) bool {
    if (tx >= grid_tiles_w or ty >= grid_tiles_h) return false;
    const idx = ty * grid_tiles_w + tx;
    const word_idx = idx / 64;
    const bit_offset: u6 = @intCast(idx % 64);
    return ((dirty_bitset[word_idx] >> bit_offset) & 1) != 0;
}

pub fn isClean() bool {
    return !force_full_redraw and (dirty_tile_count == 0);
}

pub fn markPixelRectDirty(rx: usize, ry: usize, rw: usize, rh: usize) void {
    if (rw == 0 or rh == 0) return;
    const t_start_x = rx / TILE_SIZE;
    const t_start_y = ry / TILE_SIZE;
    const t_end_x = @min(grid_tiles_w, (rx + rw + TILE_SIZE - 1) / TILE_SIZE);
    const t_end_y = @min(grid_tiles_h, (ry + rh + TILE_SIZE - 1) / TILE_SIZE);

    var ty = t_start_y;
    while (ty < t_end_y) : (ty += 1) {
        var tx = t_start_x;
        while (tx < t_end_x) : (tx += 1) {
            markTileDirty(tx, ty);
        }
    }
}

pub fn computeDirtyTiles(
    curr: [*]const u32,
    prev: [*]const u32,
    width: usize,
    height: usize,
) usize {
    stats_total_frames += 1;

    if (force_full_redraw) {
        markAllDirty();
        stats_partial_frames += 1;
        return dirty_tile_count;
    }

    clearDirty();
    const stride = width;

    var ty: usize = 0;
    while (ty < grid_tiles_h) : (ty += 1) {
        const py = ty * TILE_SIZE;
        const th = @min(TILE_SIZE, height - py);

        var tx: usize = 0;
        while (tx < grid_tiles_w) : (tx += 1) {
            const px = tx * TILE_SIZE;
            const tw = @min(TILE_SIZE, width - px);

            var tile_changed = false;
            var dy: usize = 0;
            while (dy < th) : (dy += 1) {
                const row_curr = curr + (py + dy) * stride + px;
                const row_prev = prev + (py + dy) * stride + px;

                var dx: usize = 0;
                while (dx + 2 <= tw) : (dx += 2) {
                    const c64: *const u64 = @ptrCast(@alignCast(row_curr + dx));
                    const p64: *const u64 = @ptrCast(@alignCast(row_prev + dx));
                    if (c64.* != p64.*) {
                        tile_changed = true;
                        break;
                    }
                }
                if (tile_changed) break;

                while (dx < tw) : (dx += 1) {
                    if (row_curr[dx] != row_prev[dx]) {
                        tile_changed = true;
                        break;
                    }
                }
                if (tile_changed) break;
            }

            if (tile_changed) {
                markTileDirty(tx, ty);
            }
        }
    }

    if (dirty_tile_count == 0) {
        stats_clean_frames += 1;
        stats_saved_scanout_pixels += (grid_pixels_w * grid_pixels_h);
    } else {
        stats_partial_frames += 1;
        const total_px = grid_pixels_w * grid_pixels_h;
        const dirty_px = dirty_tile_count * (TILE_SIZE * TILE_SIZE);
        if (total_px > dirty_px) {
            stats_saved_scanout_pixels += (total_px - dirty_px);
        }
    }

    return dirty_tile_count;
}

pub fn getBoundingBox() ?DirtyRect {
    if (dirty_tile_count == 0 and !force_full_redraw) return null;

    if (force_full_redraw) {
        return DirtyRect{
            .x = 0,
            .y = 0,
            .w = @intCast(grid_pixels_w),
            .h = @intCast(grid_pixels_h),
        };
    }

    var min_tx: usize = grid_tiles_w;
    var min_ty: usize = grid_tiles_h;
    var max_tx: usize = 0;
    var max_ty: usize = 0;

    var ty: usize = 0;
    while (ty < grid_tiles_h) : (ty += 1) {
        var tx: usize = 0;
        while (tx < grid_tiles_w) : (tx += 1) {
            if (isTileDirty(tx, ty)) {
                if (tx < min_tx) min_tx = tx;
                if (ty < min_ty) min_ty = ty;
                if (tx > max_tx) max_tx = tx;
                if (ty > max_ty) max_ty = ty;
            }
        }
    }

    if (min_tx > max_tx or min_ty > max_ty) return null;

    const x: u16 = @intCast(min_tx * TILE_SIZE);
    const y: u16 = @intCast(min_ty * TILE_SIZE);
    const right: u16 = @intCast(@min(grid_pixels_w, (max_tx + 1) * TILE_SIZE));
    const bottom: u16 = @intCast(@min(grid_pixels_h, (max_ty + 1) * TILE_SIZE));

    return DirtyRect{
        .x = x,
        .y = y,
        .w = if (right > x) right - x else 0,
        .h = if (bottom > y) bottom - y else 0,
    };
}

pub fn getDirtyPercentage() f64 {
    const total = grid_tiles_w * grid_tiles_h;
    if (total == 0) return 0.0;
    return (@as(f64, @floatFromInt(dirty_tile_count)) / @as(f64, @floatFromInt(total))) * 100.0;
}

pub fn getSavedScanoutBandwidthMb() f64 {
    return @as(f64, @floatFromInt(stats_saved_scanout_pixels * 4)) / (1024.0 * 1024.0);
}

test "dirty tracker full & partial grid" {
    initGrid(64, 48); // 4x3 tiles of 16x16
    try std.testing.expect(isTileDirty(0, 0));
    try std.testing.expect(isTileDirty(3, 2));

    clearDirty();
    try std.testing.expect(isClean());
    try std.testing.expect(!isTileDirty(1, 1));

    markTileDirty(1, 1);
    try std.testing.expect(!isClean());
    try std.testing.expect(isTileDirty(1, 1));
    try std.testing.expectEqual(@as(usize, 1), dirty_tile_count);

    const bbox = getBoundingBox();
    try std.testing.expect(bbox != null);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.x);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.y);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.w);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.h);
}

test "dirty tracker pixel rect marking" {
    initGrid(80, 60);
    clearDirty();

    markPixelRectDirty(20, 20, 15, 15);
    try std.testing.expect(isTileDirty(1, 1));
    try std.testing.expect(isTileDirty(2, 1));
    try std.testing.expect(isTileDirty(1, 2));
    try std.testing.expect(isTileDirty(2, 2));

    const bbox = getBoundingBox();
    try std.testing.expect(bbox != null);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.x);
    try std.testing.expectEqual(@as(u16, 16), bbox.?.y);
    try std.testing.expectEqual(@as(u16, 32), bbox.?.w);
    try std.testing.expectEqual(@as(u16, 32), bbox.?.h);
}
