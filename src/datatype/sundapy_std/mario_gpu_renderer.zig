const std = @import("std");
const dynamic = @import("../dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("../gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

// ============================================================================
// NES Classic Color Palette (RGB 0.0 .. 255.0)
// ============================================================================

const COLOR_SKY = [3]f32{ 92.0, 148.0, 252.0 };
const COLOR_SKY_HORIZON = [3]f32{ 148.0, 192.0, 252.0 };
const COLOR_CLOUD_WHITE = [3]f32{ 252.0, 252.0, 252.0 };
const COLOR_CLOUD_SHADOW = [3]f32{ 216.0, 224.0, 252.0 };
const COLOR_HILL_DARK = [3]f32{ 0.0, 100.0, 0.0 };
const COLOR_HILL_LIGHT = [3]f32{ 0.0, 168.0, 0.0 };
const COLOR_HILL_SPOT = [3]f32{ 0.0, 80.0, 0.0 };
const COLOR_BUSH_GREEN = [3]f32{ 0.0, 168.0, 0.0 };
const COLOR_BUSH_DARK = [3]f32{ 0.0, 80.0, 0.0 };
const COLOR_BLACK = [3]f32{ 0.0, 0.0, 0.0 };
const COLOR_WHITE = [3]f32{ 252.0, 252.0, 252.0 };

// Mario palette
const COLOR_MARIO_RED = [3]f32{ 216.0, 40.0, 0.0 };
const COLOR_MARIO_BROWN = [3]f32{ 108.0, 64.0, 0.0 };
const COLOR_MARIO_SKIN = [3]f32{ 252.0, 200.0, 140.0 };
const COLOR_MARIO_YELLOW = [3]f32{ 252.0, 224.0, 0.0 };

// Goomba palette
const COLOR_GOOMBA_BROWN = [3]f32{ 168.0, 64.0, 0.0 };
const COLOR_GOOMBA_TAN = [3]f32{ 252.0, 200.0, 140.0 };

// Coin palette
const COLOR_COIN_GOLD = [3]f32{ 252.0, 188.0, 0.0 };
const COLOR_COIN_HIGHLIGHT = [3]f32{ 252.0, 240.0, 160.0 };

// ============================================================================
// Procedural Tile Generators (16x16 pixels per tile)
// ============================================================================

fn getGroundPixel(sx: usize, sy: usize) [3]f32 {
    const is_mortar = (sy == 0 or sy == 8 or sx == 0 or (sy < 8 and sx == 8) or (sy >= 8 and (sx == 4 or sx == 12)));
    if (is_mortar) return COLOR_BLACK;
    const is_hi = (sy == 1 or sy == 9 or sx == 1 or (sy < 8 and sx == 9) or (sy >= 8 and (sx == 5 or sx == 13)));
    if (is_hi) return [3]f32{ 252.0, 152.0, 56.0 };
    if (sy == 7 or sy == 15) return [3]f32{ 136.0, 48.0, 8.0 };
    return [3]f32{ 200.0, 76.0, 12.0 };
}

fn getBrickPixel(sx: usize, sy: usize) [3]f32 {
    const row = sy / 4;
    const is_row_mortar = (sy % 4 == 0);
    var is_col_mortar = false;
    if (row == 0 or row == 2) {
        is_col_mortar = (sx == 0 or sx == 8);
    } else {
        is_col_mortar = (sx == 4 or sx == 12);
    }
    if (is_row_mortar or is_col_mortar) return COLOR_BLACK;
    if (sy % 4 == 1) return [3]f32{ 240.0, 140.0, 48.0 };
    if (sy % 4 == 3) return [3]f32{ 116.0, 40.0, 8.0 };
    return [3]f32{ 180.0, 68.0, 16.0 };
}

fn getQuestionPixel(sx: usize, sy: usize, anim_t: f32) [3]f32 {
    if (sx == 0 or sx == 15 or sy == 0 or sy == 15) return COLOR_BLACK;
    if ((sx == 1 or sx == 14) and (sy == 1 or sy == 14)) return COLOR_BLACK;
    if (sx == 1 or sy == 1) return [3]f32{ 252.0, 224.0, 168.0 };
    if (sx == 14 or sy == 14) return [3]f32{ 136.0, 80.0, 0.0 };

    const pulse = 0.5 + 0.5 * @sin(anim_t * 6.0);
    const gold_g = 160.0 + 30.0 * pulse;
    const gold_b = 25.0 * pulse;

    const q_pattern = [10][6]u8{
        [_]u8{ 0, 1, 1, 1, 1, 0 },
        [_]u8{ 1, 1, 0, 0, 1, 1 },
        [_]u8{ 1, 1, 0, 0, 1, 1 },
        [_]u8{ 0, 0, 0, 1, 1, 0 },
        [_]u8{ 0, 0, 1, 1, 0, 0 },
        [_]u8{ 0, 0, 1, 1, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 1, 1, 0, 0 },
        [_]u8{ 0, 0, 1, 1, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 0, 0 },
    };
    if (sy >= 3 and sy < 13 and sx >= 5 and sx < 11) {
        if (q_pattern[sy - 3][sx - 5] == 1) {
            return COLOR_WHITE;
        }
    }

    return [3]f32{ 252.0, gold_g, gold_b };
}

fn getEmptyBlockPixel(sx: usize, sy: usize) [3]f32 {
    if (sx == 0 or sx == 15 or sy == 0 or sy == 15) return COLOR_BLACK;
    if ((sx == 1 or sx == 14) and (sy == 1 or sy == 14)) return COLOR_BLACK;
    if (sx == 1 or sy == 1) return [3]f32{ 180.0, 120.0, 60.0 };
    if (sx == 14 or sy == 14) return [3]f32{ 80.0, 48.0, 16.0 };
    return [3]f32{ 140.0, 88.0, 36.0 };
}

fn getStoneStepPixel(sx: usize, sy: usize) [3]f32 {
    if (sx == 0 or sx == 15 or sy == 0 or sy == 15) return COLOR_BLACK;
    if (sx == 1 or sy == 1) return [3]f32{ 252.0, 176.0, 120.0 };
    if (sx == 14 or sy == 14) return [3]f32{ 80.0, 32.0, 0.0 };
    return [3]f32{ 188.0, 84.0, 24.0 };
}

fn getPipeTopLeft(sx: usize, sy: usize) [3]f32 {
    if (sx == 0 or sy == 0 or sy == 15) return COLOR_BLACK;
    if (sy == 1) return [3]f32{ 128.0, 208.0, 16.0 };
    if (sx == 1 or sx == 2) return [3]f32{ 220.0, 252.0, 120.0 };
    if (sx >= 3 and sx <= 7) return [3]f32{ 0.0, 168.0, 0.0 };
    return [3]f32{ 0.0, 100.0, 0.0 };
}

fn getPipeTopRight(sx: usize, sy: usize) [3]f32 {
    if (sx == 15 or sy == 0 or sy == 15) return COLOR_BLACK;
    if (sy == 1) return [3]f32{ 0.0, 168.0, 0.0 };
    if (sx <= 6) return [3]f32{ 0.0, 168.0, 0.0 };
    return [3]f32{ 0.0, 80.0, 0.0 };
}

fn getPipeShaftLeft(sx: usize, sy: usize) [3]f32 {
    _ = sy;
    if (sx == 0 or sx == 1) return COLOR_BLACK;
    if (sx == 2 or sx == 3) return [3]f32{ 220.0, 252.0, 120.0 };
    if (sx >= 4 and sx <= 9) return [3]f32{ 0.0, 168.0, 0.0 };
    return [3]f32{ 0.0, 100.0, 0.0 };
}

fn getPipeShaftRight(sx: usize, sy: usize) [3]f32 {
    _ = sy;
    if (sx == 14 or sx == 15) return COLOR_BLACK;
    if (sx <= 7) return [3]f32{ 0.0, 168.0, 0.0 };
    return [3]f32{ 0.0, 80.0, 0.0 };
}

fn getFlagpoleTop(sx: usize, sy: usize) [3]f32 {
    const dx = @as(f32, @floatFromInt(sx)) - 7.5;
    const dy = @as(f32, @floatFromInt(sy)) - 8.0;
    const r2 = dx * dx + dy * dy;
    if (r2 <= 16.0) {
        if (dx < -1.0 and dy < -1.0) return COLOR_WHITE;
        return COLOR_COIN_GOLD;
    }
    if (sy >= 12 and (sx == 7 or sx == 8)) return [3]f32{ 200.0, 200.0, 200.0 };
    return [3]f32{ -1.0, 0.0, 0.0 };
}

fn getFlagpoleShaft(sx: usize, sy: usize) [3]f32 {
    _ = sy;
    if (sx == 7) return [3]f32{ 240.0, 240.0, 240.0 };
    if (sx == 8) return [3]f32{ 120.0, 120.0, 120.0 };
    return [3]f32{ -1.0, 0.0, 0.0 };
}

fn getCastleWall(sx: usize, sy: usize) [3]f32 {
    const is_mortar = (sy == 0 or sy == 8 or sx == 0 or (sy < 8 and sx == 8) or (sy >= 8 and (sx == 4 or sx == 12)));
    if (is_mortar) return COLOR_BLACK;
    return [3]f32{ 216.0, 216.0, 216.0 };
}

fn getCastleBattlement(sx: usize, sy: usize) [3]f32 {
    if (sy < 6 and (sx >= 4 and sx <= 11)) return [3]f32{ -1.0, 0.0, 0.0 };
    return getCastleWall(sx, sy);
}

fn getCastleGate(sx: usize, sy: usize) [3]f32 {
    _ = sx;
    _ = sy;
    return COLOR_BLACK;
}

fn getTilePixel(tile_id: u8, sx: usize, sy: usize, anim_t: f32) [3]f32 {
    return switch (tile_id) {
        1 => getGroundPixel(sx, sy),
        2 => getQuestionPixel(sx, sy, anim_t),
        3 => getEmptyBlockPixel(sx, sy),
        4 => getBrickPixel(sx, sy),
        5 => getStoneStepPixel(sx, sy),
        6 => getPipeTopLeft(sx, sy),
        7 => getPipeTopRight(sx, sy),
        8 => getPipeShaftLeft(sx, sy),
        9 => getPipeShaftRight(sx, sy),
        10 => getFlagpoleTop(sx, sy),
        11 => getFlagpoleShaft(sx, sy),
        12 => getCastleWall(sx, sy),
        13 => getCastleBattlement(sx, sy),
        14 => getCastleGate(sx, sy),
        else => [3]f32{ -1.0, 0.0, 0.0 },
    };
}

// ============================================================================
// Mario 16x16 Sprite Pixel Map
// ============================================================================

const MARIO_IDLE = [16][16]u8{
    [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 3, 3, 1, 2, 4, 2, 2, 4, 2, 1, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 3, 3, 3, 2, 2, 2, 2, 2, 2, 3, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 2, 2, 2, 0, 0, 2, 2, 2, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 2, 2, 2, 2, 0, 0 },
};

const MARIO_WALK1 = [16][16]u8{
    [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 2, 1, 1, 2, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 3, 3, 1, 2, 4, 2, 2, 4, 2, 1, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 3, 3, 3, 2, 2, 2, 2, 2, 2, 3, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 2, 2, 2, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0 },
    [_]u8{ 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0 },
};

const MARIO_JUMP = [16][16]u8{
    [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 0, 3, 3, 1, 1, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 3, 3, 3, 1, 1, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 3, 3, 0, 2, 2, 2, 2, 2, 2, 1, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 2, 2, 4, 2, 2, 4, 1, 3, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 3, 3, 0, 0, 0, 0 },
    [_]u8{ 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 2, 2, 2, 2, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 2, 2, 2, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0 },
};

fn getMarioPixel(frame_idx: usize, sx: usize, sy: usize) [3]f32 {
    const code = switch (frame_idx) {
        0 => MARIO_IDLE[sy][sx],
        1 => MARIO_WALK1[sy][sx],
        2 => MARIO_IDLE[sy][sx],
        3 => MARIO_WALK1[sy][sx],
        4 => MARIO_JUMP[sy][sx],
        5 => MARIO_JUMP[sy][sx],
        else => MARIO_IDLE[sy][sx],
    };
    return switch (code) {
        1 => COLOR_MARIO_RED,
        2 => COLOR_MARIO_BROWN,
        3 => COLOR_MARIO_SKIN,
        4 => COLOR_MARIO_YELLOW,
        else => [3]f32{ -1.0, 0.0, 0.0 }, // Transparent
    };
}

// ============================================================================
// Goomba 16x16 Sprite Pixel Map
// ============================================================================

const GOOMBA_WALK1 = [16][16]u8{
    [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
    [_]u8{ 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 1, 1, 1, 3, 3, 1, 1, 1, 1, 3, 3, 1, 1, 1, 0 },
    [_]u8{ 1, 1, 1, 3, 4, 3, 1, 1, 1, 1, 3, 4, 3, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 3, 4, 3, 1, 1, 1, 1, 3, 4, 3, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 1, 3, 3, 1, 1, 1, 1, 3, 3, 1, 1, 1, 1 },
    [_]u8{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
    [_]u8{ 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0 },
    [_]u8{ 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0 },
    [_]u8{ 0, 4, 4, 4, 4, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 0 },
    [_]u8{ 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 4, 4, 4, 4, 4, 4 },
    [_]u8{ 4, 4, 4, 4, 4, 4, 0, 0, 0, 0, 4, 4, 4, 4, 4, 4 },
    [_]u8{ 0, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 4, 4, 4, 4, 0 },
};

fn getGoombaPixel(is_squashed: bool, anim_f: usize, sx: usize, sy: usize) [3]f32 {
    if (is_squashed) {
        if (sy < 10) return [3]f32{ -1.0, 0.0, 0.0 };
        if (sx == 0 or sx == 15) return [3]f32{ -1.0, 0.0, 0.0 };
        if (sy == 10 or sy == 11) return COLOR_GOOMBA_BROWN;
        if (sy >= 12 and sy <= 14) return COLOR_GOOMBA_TAN;
        return COLOR_BLACK;
    }
    const actual_x = if (anim_f % 2 == 1) (15 - sx) else sx;
    const code = GOOMBA_WALK1[sy][actual_x];
    return switch (code) {
        1 => COLOR_GOOMBA_BROWN,
        2 => COLOR_GOOMBA_TAN,
        3 => COLOR_WHITE,
        4 => COLOR_BLACK,
        else => [3]f32{ -1.0, 0.0, 0.0 },
    };
}

// ============================================================================
// Coin 10x14 Sprite Pixel Map
// ============================================================================

fn getCoinPixel(frame: usize, sx: usize, sy: usize) [3]f32 {
    if (sx >= 10 or sy >= 14) return [3]f32{ -1.0, 0.0, 0.0 };
    const f = frame % 4;
    const mid_x: f32 = 4.5;
    const radius_x: f32 = switch (f) {
        0 => 4.0,
        1 => 2.8,
        2 => 1.2,
        else => 2.8,
    };
    const dx = @abs(@as(f32, @floatFromInt(sx)) - mid_x);
    const dy = @abs(@as(f32, @floatFromInt(sy)) - 6.5);
    if (dy <= 6.0 and dx <= radius_x) {
        if (dx <= 0.8 and dy <= 4.0) return COLOR_COIN_HIGHLIGHT;
        if (dx >= radius_x - 0.9 or dy >= 5.2) return [3]f32{ 180.0, 100.0, 0.0 };
        return COLOR_COIN_GOLD;
    }
    return [3]f32{ -1.0, 0.0, 0.0 };
}

// ============================================================================
// Retro 8x8 Bitmap Font Table
// ============================================================================

fn getCharBitmap(c: u8) [8]u8 {
    return switch (c) {
        '0' => [8]u8{ 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00 },
        '1' => [8]u8{ 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
        '2' => [8]u8{ 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00 },
        '3' => [8]u8{ 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 },
        '4' => [8]u8{ 0x0C, 0x1C, 0x34, 0x64, 0x7E, 0x0C, 0x0C, 0x00 },
        '5' => [8]u8{ 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 },
        '6' => [8]u8{ 0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 },
        '7' => [8]u8{ 0x7E, 0x66, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x00 },
        '8' => [8]u8{ 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 },
        '9' => [8]u8{ 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00 },
        '-' => [8]u8{ 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00 },
        'A', 'a' => [8]u8{ 0x18, 0x3C, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 },
        'C', 'c' => [8]u8{ 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00 },
        'D', 'd' => [8]u8{ 0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00 },
        'E', 'e' => [8]u8{ 0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x7E, 0x00 },
        'G', 'g' => [8]u8{ 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3C, 0x00 },
        'I', 'i' => [8]u8{ 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
        'L', 'l' => [8]u8{ 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00 },
        'M', 'm' => [8]u8{ 0x66, 0x7E, 0x5A, 0x42, 0x42, 0x42, 0x42, 0x00 },
        'O', 'o' => [8]u8{ 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
        'P', 'p' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00 },
        'R', 'r' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x66, 0x00 },
        'S', 's' => [8]u8{ 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00 },
        'T', 't' => [8]u8{ 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
        'W', 'w' => [8]u8{ 0x42, 0x42, 0x42, 0x42, 0x5A, 0x7E, 0x66, 0x00 },
        'X', 'x' => [8]u8{ 0x00, 0x00, 0x42, 0x24, 0x18, 0x24, 0x42, 0x00 },
        '*' => [8]u8{ 0x00, 0x3C, 0x7E, 0x66, 0x66, 0x7E, 0x3C, 0x00 },
        '!' => [8]u8{ 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00 },
        else => [_]u8{0} ** 8,
    };
}

// ============================================================================
// Multi-Threaded Parallel Frame Composer
// ============================================================================

pub const MarioEntity = struct {
    e_type: i32,
    x: f32,
    y: f32,
    state: i32,
    anim: i32,
    facing: i32,
};

pub const MarioPlayer = struct {
    x: f32,
    y: f32,
    facing: i32,
    state: i32,
    invuln: i32,
};

pub const RenderJob = struct {
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    cam_x: f32,
    cam_y: f32,
    mario: MarioPlayer,
    entities: []const MarioEntity,
    tiles: []const u8,
    tiles_w: usize,
    tiles_h: usize,
    anim_t: f32,
    score: i32,
    coins: i32,
    time_left: i32,
};

fn renderScanlines(job: RenderJob) void {
    var py = job.start_y;
    while (py < job.end_y) : (py += 1) {
        var px: usize = 0;
        while (px < job.w) : (px += 1) {
            const out_idx = (py * job.w + px) * 3;

            // 1. Background (Sky gradient + Parallax elements)
            const sky_t = @as(f32, @floatFromInt(py)) / @as(f32, @floatFromInt(job.h));
            var r: f32 = COLOR_SKY[0] * (1.0 - sky_t * 0.3) + COLOR_SKY_HORIZON[0] * (sky_t * 0.3);
            var g: f32 = COLOR_SKY[1] * (1.0 - sky_t * 0.3) + COLOR_SKY_HORIZON[1] * (sky_t * 0.3);
            var b: f32 = COLOR_SKY[2] * (1.0 - sky_t * 0.3) + COLOR_SKY_HORIZON[2] * (sky_t * 0.3);

            // Parallax Clouds (slow scroll)
            const cloud_x = (@as(f32, @floatFromInt(px)) + job.cam_x * 0.25) + job.anim_t * 5.0;
            const c_mod = @mod(cloud_x, 320.0);
            if (py >= 28 and py <= 60 and c_mod >= 40.0 and c_mod <= 110.0) {
                const c_dx = c_mod - 75.0;
                const c_dy = @as(f32, @floatFromInt(py)) - 46.0;
                if ((c_dx * c_dx) / 1000.0 + (c_dy * c_dy) / 120.0 <= 1.0) {
                    r = COLOR_CLOUD_WHITE[0];
                    g = COLOR_CLOUD_WHITE[1];
                    b = COLOR_CLOUD_WHITE[2];
                }
            }

            // Parallax Rolling Hills (mid scroll)
            if (py >= 150 and py <= 208) {
                const hill_x = (@as(f32, @floatFromInt(px)) + job.cam_x * 0.5);
                const h_mod = @mod(hill_x, 380.0);
                if (h_mod <= 120.0) {
                    const h_dx = (h_mod - 60.0) / 60.0;
                    const hill_top_y = 208.0 - (1.0 - h_dx * h_dx) * 44.0;
                    if (@as(f32, @floatFromInt(py)) >= hill_top_y) {
                        r = COLOR_HILL_LIGHT[0];
                        g = COLOR_HILL_LIGHT[1];
                        b = COLOR_HILL_LIGHT[2];
                    }
                }
            }

            // Parallax Bushes along the ground
            if (py >= 192 and py <= 208) {
                const bush_x = (@as(f32, @floatFromInt(px)) + job.cam_x);
                const b_mod = @mod(bush_x, 260.0);
                if (b_mod <= 64.0) {
                    const b_dx = (b_mod - 32.0) / 32.0;
                    const bush_top_y = 208.0 - (1.0 - b_dx * b_dx) * 16.0;
                    if (@as(f32, @floatFromInt(py)) >= bush_top_y) {
                        r = COLOR_BUSH_GREEN[0];
                        g = COLOR_BUSH_GREEN[1];
                        b = COLOR_BUSH_GREEN[2];
                    }
                }
            }

            // 2. Tilemap Layer
            const world_x = @as(f32, @floatFromInt(px)) + job.cam_x;
            const world_y = @as(f32, @floatFromInt(py)) + job.cam_y;

            if (world_x >= 0.0 and world_y >= 0.0) {
                const tile_x: usize = @intFromFloat(world_x / 16.0);
                const tile_y: usize = @intFromFloat(world_y / 16.0);

                if (tile_x < job.tiles_w and tile_y < job.tiles_h) {
                    const tid = job.tiles[tile_y * job.tiles_w + tile_x];
                    if (tid > 0) {
                        const sub_x: usize = @intFromFloat(@mod(world_x, 16.0));
                        const sub_y: usize = @intFromFloat(@mod(world_y, 16.0));
                        const tile_col = getTilePixel(tid, sub_x, sub_y, job.anim_t);
                        if (tile_col[0] >= 0.0) {
                            r = tile_col[0];
                            g = tile_col[1];
                            b = tile_col[2];
                        }
                    }
                }
            }

            // 3. Active Entity Sprites (Goombas, Coins, Flag)
            for (job.entities) |ent| {
                const ent_scr_x = ent.x - job.cam_x;
                const ent_scr_y = ent.y - job.cam_y;
                const fpx = @as(f32, @floatFromInt(px));
                const fpy = @as(f32, @floatFromInt(py));

                if (ent.e_type == 1) {
                    // Goomba (16x16)
                    if (fpx >= ent_scr_x and fpx < ent_scr_x + 16.0 and fpy >= ent_scr_y and fpy < ent_scr_y + 16.0) {
                        const sx: usize = @intFromFloat(fpx - ent_scr_x);
                        const sy: usize = @intFromFloat(fpy - ent_scr_y);
                        const col = getGoombaPixel(ent.state == 1, @intCast(ent.anim), sx, sy);
                        if (col[0] >= 0.0) {
                            r = col[0];
                            g = col[1];
                            b = col[2];
                        }
                    }
                } else if (ent.e_type == 2) {
                    // Coin (10x14)
                    if (fpx >= ent_scr_x and fpx < ent_scr_x + 10.0 and fpy >= ent_scr_y and fpy < ent_scr_y + 14.0) {
                        const sx: usize = @intFromFloat(fpx - ent_scr_x);
                        const sy: usize = @intFromFloat(fpy - ent_scr_y);
                        const col = getCoinPixel(@intCast(ent.anim), sx, sy);
                        if (col[0] >= 0.0) {
                            r = col[0];
                            g = col[1];
                            b = col[2];
                        }
                    }
                } else if (ent.e_type == 4) {
                    // Flag cloth sliding on pole
                    if (fpx >= ent_scr_x - 14.0 and fpx <= ent_scr_x and fpy >= ent_scr_y and fpy <= ent_scr_y + 14.0) {
                        const fx = ent_scr_x - fpx;
                        const fy = fpy - ent_scr_y;
                        if (fy <= (14.0 - fx)) {
                            r = 0.0;
                            g = 168.0;
                            b = 0.0;
                        }
                    }
                }
            }

            // 4. Mario Player Sprite (16x16)
            const mario_scr_x = job.mario.x - job.cam_x;
            const mario_scr_y = job.mario.y - job.cam_y;
            const fpx = @as(f32, @floatFromInt(px));
            const fpy = @as(f32, @floatFromInt(py));

            if (fpx >= mario_scr_x and fpx < mario_scr_x + 16.0 and fpy >= mario_scr_y and fpy < mario_scr_y + 16.0) {
                var sx: usize = @intFromFloat(fpx - mario_scr_x);
                const sy: usize = @intFromFloat(fpy - mario_scr_y);
                if (job.mario.facing < 0) {
                    sx = 15 - sx; // Horizontal flip when facing left
                }
                const m_col = getMarioPixel(@intCast(job.mario.state), sx, sy);
                if (m_col[0] >= 0.0) {
                    r = m_col[0];
                    g = m_col[1];
                    b = m_col[2];
                }
            }

            // 5. Store composed pixel into GPU frame buffer
            job.buf.data[out_idx] = r;
            job.buf.data[out_idx + 1] = g;
            job.buf.data[out_idx + 2] = b;
        }
    }
}

fn drawHudText(buf: *GpuBuffer, w: usize, h: usize, text: []const u8, start_x: usize, start_y: usize) void {
    var cur_x = start_x;
    for (text) |ch| {
        if (ch == ' ') {
            cur_x += 8;
            continue;
        }
        const bmp = getCharBitmap(ch);
        var row: usize = 0;
        while (row < 8) : (row += 1) {
            const py = start_y + row;
            if (py >= h) continue;
            var col: usize = 0;
            while (col < 8) : (col += 1) {
                const px = cur_x + col;
                if (px >= w) continue;
                const mask = @as(u8, 0x80) >> @intCast(col);
                if ((bmp[row] & mask) != 0) {
                    // Dropshadow (black)
                    if (px + 1 < w and py + 1 < h) {
                        const s_idx = ((py + 1) * w + px + 1) * 3;
                        buf.data[s_idx] = 0.0;
                        buf.data[s_idx + 1] = 0.0;
                        buf.data[s_idx + 2] = 0.0;
                    }
                    // Text pixel (white)
                    const p_idx = (py * w + px) * 3;
                    buf.data[p_idx] = 252.0;
                    buf.data[p_idx + 1] = 252.0;
                    buf.data[p_idx + 2] = 252.0;
                }
            }
        }
        cur_x += 8;
    }
}

// ============================================================================
// Exported Engine API
// ============================================================================

pub fn renderMarioFrame(allocator: std.mem.Allocator, args: []const Dynamic, _: ?Dynamic) anyerror!Dynamic {
    if (args.len < 10) return error.TypeError;

    const buf_dyn = args[0];
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var w: usize = 256;
    var h: usize = 240;
    var arg_offset: usize = 1;

    if (args.len >= 12) {
        if (args[1].value == .i64_type) w = @intCast(@max(1, args[1].value.i64_type));
        if (args[2].value == .i64_type) h = @intCast(@max(1, args[2].value.i64_type));
        arg_offset = 3;
    }

    var cam_x: f32 = 0.0;
    var cam_y: f32 = 0.0;
    if (args[arg_offset].value == .float_type) cam_x = @floatCast(args[arg_offset].value.float_type) else if (args[arg_offset].value == .i64_type) cam_x = @floatFromInt(args[arg_offset].value.i64_type);
    if (args[arg_offset + 1].value == .float_type) cam_y = @floatCast(args[arg_offset + 1].value.float_type) else if (args[arg_offset + 1].value == .i64_type) cam_y = @floatFromInt(args[arg_offset + 1].value.i64_type);

    // Unpack Mario Player
    const mario_dyn = args[arg_offset + 2];
    var mario = MarioPlayer{ .x = 40.0, .y = 192.0, .facing = 1, .state = 0, .invuln = 0 };
    if (mario_dyn.value == .dict_type) {
        const d = mario_dyn.value.dict_type;
        if (d.get(Dynamic.initStr("x"))) |v| {
            if (v.value == .float_type) mario.x = @floatCast(v.value.float_type) else if (v.value == .i64_type) mario.x = @floatFromInt(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("y"))) |v| {
            if (v.value == .float_type) mario.y = @floatCast(v.value.float_type) else if (v.value == .i64_type) mario.y = @floatFromInt(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("facing"))) |v| {
            if (v.value == .i64_type) mario.facing = @intCast(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("state"))) |v| {
            if (v.value == .i64_type) mario.state = @intCast(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("invulnerable"))) |v| {
            if (v.value == .i64_type) mario.invuln = @intCast(v.value.i64_type);
        }
    }

    // Unpack Entities
    const entities_dyn = args[arg_offset + 3];
    var entity_list: std.ArrayList(MarioEntity) = .empty;
    defer entity_list.deinit(allocator);

    if (entities_dyn.value == .list_type) {
        for (entities_dyn.value.list_type.items.items) |item| {
            if (item.value == .list_type and item.value.list_type.items.items.len >= 5) {
                const itms = item.value.list_type.items.items;
                var e_type: i32 = 1;
                var ex: f32 = 0.0;
                var ey: f32 = 0.0;
                var e_state: i32 = 0;
                var e_anim: i32 = 0;

                if (itms[0].value == .i64_type) e_type = @intCast(itms[0].value.i64_type);
                if (itms[1].value == .float_type) ex = @floatCast(itms[1].value.float_type) else if (itms[1].value == .i64_type) ex = @floatFromInt(itms[1].value.i64_type);
                if (itms[2].value == .float_type) ey = @floatCast(itms[2].value.float_type) else if (itms[2].value == .i64_type) ey = @floatFromInt(itms[2].value.i64_type);
                if (itms[3].value == .i64_type) e_state = @intCast(itms[3].value.i64_type);
                if (itms[4].value == .i64_type) e_anim = @intCast(itms[4].value.i64_type);

                try entity_list.append(allocator, .{
                    .e_type = e_type,
                    .x = ex,
                    .y = ey,
                    .state = e_state,
                    .anim = e_anim,
                    .facing = 1,
                });
            }
        }
    }

    // Unpack Tiles
    const tiles_dyn = args[arg_offset + 4];
    var tiles_w: usize = 224;
    var tiles_h: usize = 15;
    if (args[arg_offset + 5].value == .i64_type) tiles_w = @intCast(@max(1, args[arg_offset + 5].value.i64_type));
    if (args[arg_offset + 6].value == .i64_type) tiles_h = @intCast(@max(1, args[arg_offset + 6].value.i64_type));

    const total_tiles = tiles_w * tiles_h;
    const tile_bytes = try allocator.alloc(u8, total_tiles);
    defer allocator.free(tile_bytes);
    @memset(tile_bytes, 0);

    if (tiles_dyn.value == .list_type) {
        const t_items = tiles_dyn.value.list_type.items.items;
        const count = @min(total_tiles, t_items.len);
        for (0..count) |i| {
            if (t_items[i].value == .i64_type) {
                tile_bytes[i] = @intCast(t_items[i].value.i64_type & 0xFF);
            }
        }
    }

    // Unpack HUD
    const hud_dyn = args[arg_offset + 7];
    var score: i32 = 0;
    var coins: i32 = 0;
    var time_left: i32 = 400;

    if (hud_dyn.value == .dict_type) {
        const d = hud_dyn.value.dict_type;
        if (d.get(Dynamic.initStr("score"))) |v| {
            if (v.value == .i64_type) score = @intCast(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("coins"))) |v| {
            if (v.value == .i64_type) coins = @intCast(v.value.i64_type);
        }
        if (d.get(Dynamic.initStr("time"))) |v| {
            if (v.value == .i64_type) time_left = @intCast(v.value.i64_type);
        }
    }

    var anim_t: f32 = 0.0;
    if (args[arg_offset + 8].value == .float_type) anim_t = @floatCast(args[arg_offset + 8].value.float_type);

    // Multi-core GPU parallel rasterizer
    const cpu_count = std.Thread.getCpuCount() catch 4;
    const num_threads = @min(h, @max(1, cpu_count));

    if (num_threads <= 1) {
        renderScanlines(RenderJob{
            .buf = buf,
            .w = w,
            .h = h,
            .start_y = 0,
            .end_y = h,
            .cam_x = cam_x,
            .cam_y = cam_y,
            .mario = mario,
            .entities = entity_list.items,
            .tiles = tile_bytes,
            .tiles_w = tiles_w,
            .tiles_h = tiles_h,
            .anim_t = anim_t,
            .score = score,
            .coins = coins,
            .time_left = time_left,
        });
    } else {
        var threads = try allocator.alloc(std.Thread, num_threads);
        defer allocator.free(threads);

        const rows_per_thread = (h + num_threads - 1) / num_threads;
        var start_y: usize = 0;
        var spawned: usize = 0;

        for (0..num_threads) |_| {
            if (start_y >= h) break;
            const end_y = @min(h, start_y + rows_per_thread);
            threads[spawned] = try std.Thread.spawn(.{}, renderScanlines, .{RenderJob{
                .buf = buf,
                .w = w,
                .h = h,
                .start_y = start_y,
                .end_y = end_y,
                .cam_x = cam_x,
                .cam_y = cam_y,
                .mario = mario,
                .entities = entity_list.items,
                .tiles = tile_bytes,
                .tiles_w = tiles_w,
                .tiles_h = tiles_h,
                .anim_t = anim_t,
                .score = score,
                .coins = coins,
                .time_left = time_left,
            }});
            spawned += 1;
            start_y = end_y;
        }

        for (0..spawned) |i| {
            threads[i].join();
        }
    }

    // Render HUD Text Overlay directly at top
    var score_buf: [32]u8 = undefined;
    const score_str = std.fmt.bufPrint(&score_buf, "{d:0>6}", .{score}) catch "000000";

    var coins_buf: [32]u8 = undefined;
    const coins_str = std.fmt.bufPrint(&coins_buf, "*{d:0>2}", .{coins}) catch "*00";

    var time_buf: [32]u8 = undefined;
    const time_str = std.fmt.bufPrint(&time_buf, "{d:0>3}", .{time_left}) catch "400";

    drawHudText(buf, w, h, "MARIO          WORLD   TIME", 24, 10);
    drawHudText(buf, w, h, score_str, 24, 20);
    drawHudText(buf, w, h, coins_str, 96, 20);
    drawHudText(buf, w, h, "1-1", 144, 20);
    drawHudText(buf, w, h, time_str, 200, 20);

    buf.toDevice();
    return Dynamic.initNone();
}
