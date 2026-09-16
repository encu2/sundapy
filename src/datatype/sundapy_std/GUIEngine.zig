const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

pub const name = Dynamic.initStr("GUIEngine");

// ============================================================================
// SUNDAPY MULTI-PURPOSE MEDIA & GAME GUI ENGINE
// ============================================================================
// Provides high-performance, zero-dependency 2D canvas primitives, sprite
// blitting, alpha blending, tilemap rasterization, procedural font rendering,
// media color space conversion, and multi-core scanline rendering for both
// Native X11 and Wayland (via Xwayland wire protocol).
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Color Utilities & Palette
// ----------------------------------------------------------------------------

pub const ColorRGB = struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const COLOR_BLACK = ColorRGB{ .r = 0.0, .g = 0.0, .b = 0.0 };
pub const COLOR_WHITE = ColorRGB{ .r = 252.0, .g = 252.0, .b = 252.0 };
pub const COLOR_RED = ColorRGB{ .r = 240.0, .g = 32.0, .b = 32.0 };
pub const COLOR_GREEN = ColorRGB{ .r = 32.0, .g = 220.0, .b = 32.0 };
pub const COLOR_BLUE = ColorRGB{ .r = 32.0, .g = 96.0, .b = 240.0 };
pub const COLOR_YELLOW = ColorRGB{ .r = 252.0, .g = 224.0, .b = 0.0 };
pub const COLOR_CYAN = ColorRGB{ .r = 0.0, .g = 220.0, .b = 240.0 };
pub const COLOR_MAGENTA = ColorRGB{ .r = 240.0, .g = 32.0, .b = 220.0 };

// Classic NES 64-Color Palette (RGB)
pub const COLOR_SKY = [3]f32{ 92.0, 148.0, 252.0 };
pub const COLOR_SKY_HORIZON = [3]f32{ 148.0, 192.0, 252.0 };
pub const COLOR_CLOUD_WHITE = [3]f32{ 252.0, 252.0, 252.0 };
pub const COLOR_CLOUD_SHADOW = [3]f32{ 216.0, 224.0, 252.0 };
pub const COLOR_HILL_DARK = [3]f32{ 0.0, 100.0, 0.0 };
pub const COLOR_HILL_LIGHT = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_HILL_SPOT = [3]f32{ 0.0, 80.0, 0.0 };
pub const COLOR_BUSH_GREEN = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_BUSH_DARK = [3]f32{ 0.0, 80.0, 0.0 };

pub const COLOR_MARIO_RED = [3]f32{ 216.0, 40.0, 0.0 };
pub const COLOR_MARIO_BROWN = [3]f32{ 108.0, 64.0, 0.0 };
pub const COLOR_MARIO_SKIN = [3]f32{ 252.0, 200.0, 140.0 };
pub const COLOR_MARIO_YELLOW = [3]f32{ 252.0, 224.0, 0.0 };

pub const COLOR_GOOMBA_BROWN = [3]f32{ 168.0, 64.0, 0.0 };
pub const COLOR_GOOMBA_TAN = [3]f32{ 252.0, 200.0, 140.0 };
pub const COLOR_COIN_GOLD = [3]f32{ 252.0, 188.0, 0.0 };
pub const COLOR_COIN_HIGHLIGHT = [3]f32{ 252.0, 240.0, 160.0 };

// ----------------------------------------------------------------------------
// 2. Multi-Purpose 2D Drawing Primitives
// ----------------------------------------------------------------------------

pub fn create_surface(w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 240;
    const total_pixels = w * h * 3;
    const buf = try GpuBuffer.init(std.heap.c_allocator, total_pixels);
    return Dynamic{ .value = .{ .gpu_buffer_type = buf } };
}

pub fn clear_surface(buf_dyn: Dynamic, r_dyn: Dynamic, g_dyn: Dynamic, b_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else if (r_dyn.value == .i64_type) @floatFromInt(r_dyn.value.i64_type) else 0.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else if (g_dyn.value == .i64_type) @floatFromInt(g_dyn.value.i64_type) else 0.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else if (b_dyn.value == .i64_type) @floatFromInt(b_dyn.value.i64_type) else 0.0;

    var i: usize = 0;
    const len = buf.data.len;
    while (i + 2 < len) : (i += 3) {
        buf.data[i] = r;
        buf.data[i + 1] = g;
        buf.data[i + 2] = b;
    }
    buf.toDevice();
    return Dynamic.initNone();
}

pub fn draw_pixel_fast(buf: *GpuBuffer, w: usize, h: usize, x: i64, y: i64, r: f32, g: f32, b: f32) void {
    if (x < 0 or y < 0 or x >= @as(i64, @intCast(w)) or y >= @as(i64, @intCast(h))) return;
    const idx = (@as(usize, @intCast(y)) * w + @as(usize, @intCast(x))) * 3;
    if (idx + 2 < buf.data.len) {
        buf.data[idx] = r;
        buf.data[idx + 1] = g;
        buf.data[idx + 2] = b;
    }
}

pub fn draw_rect(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    x_dyn: Dynamic,
    y_dyn: Dynamic,
    rw_dyn: Dynamic,
    rh_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
    fill_dyn: Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 240;
    const rx = if (x_dyn.value == .i64_type) x_dyn.value.i64_type else 0;
    const ry = if (y_dyn.value == .i64_type) y_dyn.value.i64_type else 0;
    const rw = if (rw_dyn.value == .i64_type) rw_dyn.value.i64_type else 16;
    const rh = if (rh_dyn.value == .i64_type) rh_dyn.value.i64_type else 16;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else 255.0;
    const fill: bool = if (fill_dyn.value == .bool_type) fill_dyn.value.bool_type else true;

    if (fill) {
        var py = ry;
        while (py < ry + rh) : (py += 1) {
            var px = rx;
            while (px < rx + rw) : (px += 1) {
                draw_pixel_fast(buf, w, h, px, py, r, g, b);
            }
        }
    } else {
        var px = rx;
        while (px < rx + rw) : (px += 1) {
            draw_pixel_fast(buf, w, h, px, ry, r, g, b);
            draw_pixel_fast(buf, w, h, px, ry + rh - 1, r, g, b);
        }
        var py = ry;
        while (py < ry + rh) : (py += 1) {
            draw_pixel_fast(buf, w, h, rx, py, r, g, b);
            draw_pixel_fast(buf, w, h, rx + rw - 1, py, r, g, b);
        }
    }
    buf.toDevice();
    return Dynamic.initNone();
}

pub fn draw_line(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    x0_dyn: Dynamic,
    y0_dyn: Dynamic,
    x1_dyn: Dynamic,
    y1_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 240;
    var x0 = if (x0_dyn.value == .i64_type) x0_dyn.value.i64_type else 0;
    var y0 = if (y0_dyn.value == .i64_type) y0_dyn.value.i64_type else 0;
    const x1 = if (x1_dyn.value == .i64_type) x1_dyn.value.i64_type else 0;
    const y1 = if (y1_dyn.value == .i64_type) y1_dyn.value.i64_type else 0;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else 255.0;

    // Bresenham line algorithm
    const dx = @abs(x1 - x0);
    const dy = -@as(i64, @intCast(@abs(y1 - y0)));
    const sx: i64 = if (x0 < x1) 1 else -1;
    const sy: i64 = if (y0 < y1) 1 else -1;
    var err = @as(i64, @intCast(dx)) + dy;

    while (true) {
        draw_pixel_fast(buf, w, h, x0, y0, r, g, b);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= @as(i64, @intCast(dx))) {
            err += @as(i64, @intCast(dx));
            y0 += sy;
        }
    }
    buf.toDevice();
    return Dynamic.initNone();
}

pub fn draw_circle(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    cx_dyn: Dynamic,
    cy_dyn: Dynamic,
    radius_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
    fill_dyn: Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 240;
    const cx = if (cx_dyn.value == .i64_type) cx_dyn.value.i64_type else 0;
    const cy = if (cy_dyn.value == .i64_type) cy_dyn.value.i64_type else 0;
    const rad = if (radius_dyn.value == .i64_type) radius_dyn.value.i64_type else 10;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else 255.0;
    const fill = if (fill_dyn.value == .bool_type) fill_dyn.value.bool_type else true;

    if (fill) {
        var dy = -rad;
        while (dy <= rad) : (dy += 1) {
            var dx = -rad;
            while (dx <= rad) : (dx += 1) {
                if (dx * dx + dy * dy <= rad * rad) {
                    draw_pixel_fast(buf, w, h, cx + dx, cy + dy, r, g, b);
                }
            }
        }
    } else {
        // Midpoint circle algorithm
        var x: i64 = 0;
        var y: i64 = rad;
        var d: i64 = 3 - 2 * rad;
        while (y >= x) {
            draw_pixel_fast(buf, w, h, cx + x, cy + y, r, g, b);
            draw_pixel_fast(buf, w, h, cx - x, cy + y, r, g, b);
            draw_pixel_fast(buf, w, h, cx + x, cy - y, r, g, b);
            draw_pixel_fast(buf, w, h, cx - x, cy - y, r, g, b);
            draw_pixel_fast(buf, w, h, cx + y, cy + x, r, g, b);
            draw_pixel_fast(buf, w, h, cx - y, cy + x, r, g, b);
            draw_pixel_fast(buf, w, h, cx + y, cy - x, r, g, b);
            draw_pixel_fast(buf, w, h, cx - y, cy - x, r, g, b);
            x += 1;
            if (d > 0) {
                y -= 1;
                d = d + 4 * (x - y) + 10;
            } else {
                d = d + 4 * x + 6;
            }
        }
    }
    buf.toDevice();
    return Dynamic.initNone();
}

// ----------------------------------------------------------------------------
// 3. Texture / Sprite Blitting with Alpha Blending & Chroma Keying
// ----------------------------------------------------------------------------

pub fn blit_surface(
    dst_dyn: Dynamic,
    dst_w_dyn: Dynamic,
    dst_h_dyn: Dynamic,
    src_dyn: Dynamic,
    src_w_dyn: Dynamic,
    src_h_dyn: Dynamic,
    dx_dyn: Dynamic,
    dy_dyn: Dynamic,
    colorkey_dyn: Dynamic,
    alpha_dyn: Dynamic,
) anyerror!Dynamic {
    if (dst_dyn.value != .gpu_buffer_type or src_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dw: usize = if (dst_w_dyn.value == .i64_type) @intCast(dst_w_dyn.value.i64_type) else 256;
    const dh: usize = if (dst_h_dyn.value == .i64_type) @intCast(dst_h_dyn.value.i64_type) else 240;
    const sw: usize = if (src_w_dyn.value == .i64_type) @intCast(src_w_dyn.value.i64_type) else 16;
    const sh: usize = if (src_h_dyn.value == .i64_type) @intCast(src_h_dyn.value.i64_type) else 16;
    const dx = if (dx_dyn.value == .i64_type) dx_dyn.value.i64_type else 0;
    const dy = if (dy_dyn.value == .i64_type) dy_dyn.value.i64_type else 0;
    const alpha: f32 = if (alpha_dyn.value == .float_type) @floatCast(alpha_dyn.value.float_type) else 1.0;

    var use_key = false;
    var kr: f32 = 0;
    var kg: f32 = 0;
    var kb: f32 = 0;
    if (colorkey_dyn.value == .list_type) {
        const items = colorkey_dyn.value.list_type.items.items;
        if (items.len >= 3) {
            use_key = true;
            kr = if (items[0].value == .float_type) @floatCast(items[0].value.float_type) else 0.0;
            kg = if (items[1].value == .float_type) @floatCast(items[1].value.float_type) else 0.0;
            kb = if (items[2].value == .float_type) @floatCast(items[2].value.float_type) else 0.0;
        }
    }

    var sy: usize = 0;
    while (sy < sh) : (sy += 1) {
        const target_y = dy + @as(i64, @intCast(sy));
        if (target_y < 0 or target_y >= @as(i64, @intCast(dh))) continue;

        var sx: usize = 0;
        while (sx < sw) : (sx += 1) {
            const target_x = dx + @as(i64, @intCast(sx));
            if (target_x < 0 or target_x >= @as(i64, @intCast(dw))) continue;

            const s_idx = (sy * sw + sx) * 3;
            if (s_idx + 2 >= src.data.len) continue;

            const sr = src.data[s_idx];
            const sg = src.data[s_idx + 1];
            const sb = src.data[s_idx + 2];

            if (use_key and @abs(sr - kr) < 1.0 and @abs(sg - kg) < 1.0 and @abs(sb - kb) < 1.0) {
                continue;
            }

            const d_idx = (@as(usize, @intCast(target_y)) * dw + @as(usize, @intCast(target_x))) * 3;
            if (d_idx + 2 < dst.data.len) {
                if (alpha >= 0.999) {
                    dst.data[d_idx] = sr;
                    dst.data[d_idx + 1] = sg;
                    dst.data[d_idx + 2] = sb;
                } else {
                    const dr = dst.data[d_idx];
                    const dg = dst.data[d_idx + 1];
                    const db = dst.data[d_idx + 2];
                    dst.data[d_idx] = sr * alpha + dr * (1.0 - alpha);
                    dst.data[d_idx + 1] = sg * alpha + dg * (1.0 - alpha);
                    dst.data[d_idx + 2] = sb * alpha + db * (1.0 - alpha);
                }
            }
        }
    }
    dst.toDevice();
    return Dynamic.initNone();
}

// ----------------------------------------------------------------------------
// 4. Procedural Font & HUD Engine
// ----------------------------------------------------------------------------

pub fn getCharGlyph(c: u8) [8]u8 {
    return switch (c) {
        '0' => [8]u8{ 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00 },
        '1' => [8]u8{ 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00 },
        '2' => [8]u8{ 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00 },
        '3' => [8]u8{ 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 },
        '4' => [8]u8{ 0x0C, 0x1C, 0x34, 0x64, 0x7E, 0x04, 0x04, 0x00 },
        '5' => [8]u8{ 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 },
        '6' => [8]u8{ 0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 },
        '7' => [8]u8{ 0x7E, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x18, 0x00 },
        '8' => [8]u8{ 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 },
        '9' => [8]u8{ 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00 },
        'A', 'a' => [8]u8{ 0x18, 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x00 },
        'B', 'b' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00 },
        'C', 'c' => [8]u8{ 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00 },
        'D', 'd' => [8]u8{ 0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00 },
        'E', 'e' => [8]u8{ 0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x7E, 0x00 },
        'F', 'f' => [8]u8{ 0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x60, 0x00 },
        'G', 'g' => [8]u8{ 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3A, 0x00 },
        'H', 'h' => [8]u8{ 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 },
        'I', 'i' => [8]u8{ 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
        'J', 'j' => [8]u8{ 0x0E, 0x06, 0x06, 0x06, 0x06, 0x66, 0x3C, 0x00 },
        'K', 'k' => [8]u8{ 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00 },
        'L', 'l' => [8]u8{ 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00 },
        'M', 'm' => [8]u8{ 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00 },
        'N', 'n' => [8]u8{ 0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66, 0x00 },
        'O', 'o' => [8]u8{ 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
        'P', 'p' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00 },
        'Q', 'q' => [8]u8{ 0x3C, 0x66, 0x66, 0x66, 0x6A, 0x6C, 0x36, 0x00 },
        'R', 'r' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x63, 0x00 },
        'S', 's' => [8]u8{ 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00 },
        'T', 't' => [8]u8{ 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
        'U', 'u' => [8]u8{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
        'V', 'v' => [8]u8{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 },
        'W', 'w' => [8]u8{ 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00 },
        'X', 'x' => [8]u8{ 0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00 },
        'Y', 'y' => [8]u8{ 0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00 },
        'Z', 'z' => [8]u8{ 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00 },
        '-' => [8]u8{ 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00 },
        '*' => [8]u8{ 0x24, 0x66, 0x3C, 0x3C, 0x66, 0x24, 0x00, 0x00 },
        '!' => [8]u8{ 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00 },
        ':' => [8]u8{ 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00 },
        '.' => [8]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00 },
        else => [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };
}

pub fn draw_text_fast(buf: *GpuBuffer, w: usize, h: usize, str: []const u8, x: usize, y: usize, scale: usize, r: f32, g: f32, b: f32) void {
    const sc = @max(1, scale);
    for (str, 0..) |ch, i| {
        const glyph = getCharGlyph(ch);
        const char_x = x + i * (8 * sc);
        var gy: usize = 0;
        while (gy < 8) : (gy += 1) {
            const row = glyph[gy];
            var gx: usize = 0;
            while (gx < 8) : (gx += 1) {
                if ((row & (@as(u8, 0x80) >> @intCast(gx))) != 0) {
                    var sy: usize = 0;
                    while (sy < sc) : (sy += 1) {
                        var sx: usize = 0;
                        while (sx < sc) : (sx += 1) {
                            const px = char_x + gx * sc + sx;
                            const py = y + gy * sc + sy;
                            if (px < w and py < h) {
                                const idx = (py * w + px) * 3;
                                if (idx + 2 < buf.data.len) {
                                    buf.data[idx] = r;
                                    buf.data[idx + 1] = g;
                                    buf.data[idx + 2] = b;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

pub fn draw_text(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    str_dyn: Dynamic,
    x_dyn: Dynamic,
    y_dyn: Dynamic,
    scale_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type or str_dyn.value != .str_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 240;
    const s = str_dyn.value.str_type;
    const x: usize = if (x_dyn.value == .i64_type) @intCast(@max(0, x_dyn.value.i64_type)) else 0;
    const y: usize = if (y_dyn.value == .i64_type) @intCast(@max(0, y_dyn.value.i64_type)) else 0;
    const sc: usize = if (scale_dyn.value == .i64_type) @intCast(@max(1, scale_dyn.value.i64_type)) else 1;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else 255.0;

    draw_text_fast(buf, w, h, s, x, y, sc, r, g, b);
    buf.toDevice();
    return Dynamic.initNone();
}

// ----------------------------------------------------------------------------
// 5. Media Color Space Conversions (Fast Video / Frame Operations)
// ----------------------------------------------------------------------------

pub fn rgb_to_bgr(src_dyn: Dynamic, dst_dyn: Dynamic, count_dyn: Dynamic) anyerror!Dynamic {
    if (src_dyn.value != .gpu_buffer_type or dst_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const src: *GpuBuffer = @ptrCast(@alignCast(src_dyn.value.gpu_buffer_type));
    const dst: *GpuBuffer = @ptrCast(@alignCast(dst_dyn.value.gpu_buffer_type));
    const count: usize = if (count_dyn.value == .i64_type) @intCast(count_dyn.value.i64_type) else @min(src.data.len, dst.data.len) / 3;

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const idx = i * 3;
        const r = src.data[idx];
        const g = src.data[idx + 1];
        const b = src.data[idx + 2];
        dst.data[idx] = b;
        dst.data[idx + 1] = g;
        dst.data[idx + 2] = r;
    }
    dst.toDevice();
    return Dynamic.initNone();
}

// ----------------------------------------------------------------------------
// 6. NES Procedural Tile & Game Engine Rasterizer
// ----------------------------------------------------------------------------

fn getGroundPixel(sx: usize, sy: usize) [3]f32 {
    const is_mortar = (sy == 0 or sy == 8 or sx == 0 or (sy < 8 and sx == 8) or (sy >= 8 and (sx == 4 or sx == 12)));
    if (is_mortar) return [3]f32{ 0.0, 0.0, 0.0 };
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
    if (is_row_mortar or is_col_mortar) return [3]f32{ 0.0, 0.0, 0.0 };
    if (sy % 4 == 1) return [3]f32{ 240.0, 140.0, 48.0 };
    if (sy % 4 == 3) return [3]f32{ 116.0, 40.0, 8.0 };
    return [3]f32{ 180.0, 68.0, 16.0 };
}

fn getQuestionPixel(sx: usize, sy: usize, anim_t: f32) [3]f32 {
    if (sx == 0 or sx == 15 or sy == 0 or sy == 15) return [3]f32{ 0.0, 0.0, 0.0 };
    if ((sx == 1 or sx == 14) and (sy == 1 or sy == 14)) return [3]f32{ 0.0, 0.0, 0.0 };
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
            return [3]f32{ 252.0, 252.0, 252.0 };
        }
    }
    return [3]f32{ 252.0, gold_g, gold_b };
}

fn getEmptyBlockPixel(sx: usize, sy: usize) [3]f32 {
    if (sx == 0 or sx == 15 or sy == 0 or sy == 15) return [3]f32{ 0.0, 0.0, 0.0 };
    if ((sx == 1 or sx == 14) and (sy == 1 or sy == 14)) return [3]f32{ 0.0, 0.0, 0.0 };
    if (sx == 1 or sy == 1) return [3]f32{ 180.0, 120.0, 60.0 };
    if (sx == 14 or sy == 14) return [3]f32{ 80.0, 48.0, 16.0 };
    return [3]f32{ 136.0, 76.0, 32.0 };
}

fn getPipePixel(tile_type: u8, sx: usize, sy: usize) [3]f32 {
    if (tile_type == 4 or tile_type == 5) {
        if (sy == 0 or sy == 15) return [3]f32{ 0.0, 0.0, 0.0 };
        if (tile_type == 4 and sx == 0) return [3]f32{ 0.0, 0.0, 0.0 };
        if (tile_type == 5 and sx == 15) return [3]f32{ 0.0, 0.0, 0.0 };
    } else {
        if (tile_type == 6 and sx == 2) return [3]f32{ 0.0, 0.0, 0.0 };
        if (tile_type == 7 and sx == 13) return [3]f32{ 0.0, 0.0, 0.0 };
        if (tile_type == 6 and sx < 2) return COLOR_SKY;
        if (tile_type == 7 and sx > 13) return COLOR_SKY;
    }

    const col = if (tile_type == 4 or tile_type == 6) sx else sx + 16;
    if (col == 1 or col == 2 or col == 3 or col == 4) return [3]f32{ 184.0, 248.0, 24.0 };
    if (col >= 5 and col <= 18) return [3]f32{ 0.0, 168.0, 0.0 };
    if (col >= 19 and col <= 26) return [3]f32{ 0.0, 120.0, 0.0 };
    return [3]f32{ 0.0, 80.0, 0.0 };
}

fn getFlagpolePixel(tile_type: u8, sx: usize, sy: usize) [3]f32 {
    if (tile_type == 8) {
        const dx = @as(i64, @intCast(sx)) - 8;
        const dy = @as(i64, @intCast(sy)) - 8;
        if (dx * dx + dy * dy <= 16) {
            if (dx < 0 and dy < 0) return [3]f32{ 184.0, 248.0, 24.0 };
            return [3]f32{ 0.0, 168.0, 0.0 };
        }
        return COLOR_SKY;
    }
    if (sx == 7 or sx == 8) return [3]f32{ 252.0, 252.0, 252.0 };
    if (sx == 6) return [3]f32{ 180.0, 180.0, 180.0 };
    if (sx == 9) return [3]f32{ 100.0, 100.0, 100.0 };
    return COLOR_SKY;
}

fn getCastlePixel(tile_type: u8, sx: usize, sy: usize) [3]f32 {
    if (tile_type == 12) {
        if (sx >= 4 and sx < 12 and sy >= 2) return [3]f32{ 0.0, 0.0, 0.0 };
    }
    if (tile_type == 11) {
        if ((sx < 4 or (sx >= 8 and sx < 12)) and sy < 6) return COLOR_SKY;
    }
    const is_mortar = (sy == 0 or sy == 8 or sx == 0 or (sy < 8 and sx == 8) or (sy >= 8 and (sx == 4 or sx == 12)));
    if (is_mortar) return [3]f32{ 0.0, 0.0, 0.0 };
    if (sy == 1 or sy == 9 or sx == 1) return [3]f32{ 252.0, 216.0, 168.0 };
    return [3]f32{ 180.0, 120.0, 60.0 };
}

fn getTilePixel(tile_type: u8, sx: usize, sy: usize, anim_t: f32) [3]f32 {
    return switch (tile_type) {
        0 => COLOR_SKY,
        1 => getGroundPixel(sx, sy),
        2 => getQuestionPixel(sx, sy, anim_t),
        3 => getBrickPixel(sx, sy),
        4, 5, 6, 7 => getPipePixel(tile_type, sx, sy),
        8, 9 => getFlagpolePixel(tile_type, sx, sy),
        10, 11, 12 => getCastlePixel(tile_type, sx, sy),
        13 => getEmptyBlockPixel(sx, sy),
        else => COLOR_SKY,
    };
}

// ----------------------------------------------------------------------------
// 7. Mario & Enemy Sprite Generators
// ----------------------------------------------------------------------------

pub const MarioState = struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    facing: i32,
    is_grounded: bool,
    is_dead: bool,
    anim_frame: usize,
};

pub const Entity = struct {
    entity_type: u8,
    x: f32,
    y: f32,
    state: u8,
    anim_timer: f32,
    facing: i32,
};

fn getMarioPixel(mario: MarioState, px: usize, py: usize) ?[3]f32 {
    const mx = @as(i64, @intFromFloat(mario.x));
    const my = @as(i64, @intFromFloat(mario.y));
    const sx_raw = @as(i64, @intCast(px)) - mx;
    const sy = @as(i64, @intCast(py)) - my;

    if (sy < 0 or sy >= 16 or sx_raw < 0 or sx_raw >= 16) return null;

    const sx: usize = if (mario.facing == -1) @intCast(15 - sx_raw) else @intCast(sx_raw);
    const y_idx: usize = @intCast(sy);

    if (mario.is_dead) {
        const dead_pattern = [16][16]u8{
            [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
            [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
            [_]u8{ 0, 0, 0, 0, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0, 0, 0 },
            [_]u8{ 0, 0, 0, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0, 0 },
            [_]u8{ 0, 0, 0, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0 },
            [_]u8{ 0, 0, 0, 0, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0, 0, 0 },
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
        const c = dead_pattern[y_idx][sx];
        return switch (c) {
            1 => COLOR_MARIO_RED,
            2 => COLOR_MARIO_BROWN,
            3 => COLOR_MARIO_SKIN,
            4 => COLOR_MARIO_YELLOW,
            else => null,
        };
    }

    const idle_pattern = [16][16]u8{
        [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 2, 2, 1, 2, 2, 2, 0, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 2, 2, 2, 1, 2, 2, 1, 2, 2, 2, 0, 0, 0 },
        [_]u8{ 0, 0, 2, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 2, 0, 0 },
        [_]u8{ 0, 0, 3, 3, 2, 1, 4, 1, 1, 4, 1, 2, 3, 3, 0, 0 },
        [_]u8{ 0, 0, 3, 3, 3, 1, 1, 1, 1, 1, 1, 3, 3, 3, 0, 0 },
        [_]u8{ 0, 0, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0 },
        [_]u8{ 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 2, 2, 2, 2, 0, 0 },
    };

    const c = idle_pattern[y_idx][sx];
    return switch (c) {
        1 => COLOR_MARIO_RED,
        2 => COLOR_MARIO_BROWN,
        3 => COLOR_MARIO_SKIN,
        4 => COLOR_MARIO_YELLOW,
        else => null,
    };
}

fn getGoombaPixel(ent: Entity, px: usize, py: usize) ?[3]f32 {
    const ex = @as(i64, @intFromFloat(ent.x));
    const ey = @as(i64, @intFromFloat(ent.y));
    const sx = @as(i64, @intCast(px)) - ex;
    const sy = @as(i64, @intCast(py)) - ey;

    if (sy < 0 or sy >= 16 or sx < 0 or sx >= 16) return null;

    if (ent.state == 1) { // Squished
        if (sy < 10) return null;
        if (sx >= 2 and sx < 14) return COLOR_GOOMBA_BROWN;
        return null;
    }

    const goomba_pattern = [16][16]u8{
        [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0 },
        [_]u8{ 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 },
        [_]u8{ 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0 },
        [_]u8{ 1, 1, 1, 1, 0, 2, 1, 1, 1, 1, 2, 0, 1, 1, 1, 1 },
        [_]u8{ 1, 1, 1, 1, 0, 2, 1, 1, 1, 1, 2, 0, 1, 1, 1, 1 },
        [_]u8{ 1, 1, 1, 1, 0, 0, 2, 2, 2, 2, 0, 0, 1, 1, 1, 1 },
        [_]u8{ 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1 },
        [_]u8{ 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0 },
        [_]u8{ 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0 },
        [_]u8{ 0, 0, 3, 3, 3, 2, 2, 2, 2, 2, 2, 3, 3, 3, 0, 0 },
        [_]u8{ 0, 3, 3, 3, 3, 3, 0, 0, 0, 0, 3, 3, 3, 3, 3, 0 },
        [_]u8{ 0, 3, 3, 3, 3, 3, 0, 0, 0, 0, 3, 3, 3, 3, 3, 0 },
    };

    const c = goomba_pattern[@intCast(sy)][@intCast(sx)];
    return switch (c) {
        1 => COLOR_GOOMBA_BROWN,
        2 => COLOR_GOOMBA_TAN,
        3 => [3]f32{ 0.0, 0.0, 0.0 },
        else => null,
    };
}

fn getCoinPixel(ent: Entity, px: usize, py: usize) ?[3]f32 {
    const ex = @as(i64, @intFromFloat(ent.x));
    const ey = @as(i64, @intFromFloat(ent.y));
    const sx = @as(i64, @intCast(px)) - ex;
    const sy = @as(i64, @intCast(py)) - ey;
    if (sy < 0 or sy >= 16 or sx < 0 or sx >= 16) return null;
    const frame = @as(usize, @intFromFloat(ent.anim_timer * 8.0)) % 4;
    const coin_w: i64 = switch (frame) {
        0, 2 => 10,
        1 => 6,
        3 => 2,
        else => 8,
    };
    const x_start = 8 - @divTrunc(coin_w, 2);
    if (sx >= x_start and sx < x_start + coin_w and sy >= 2 and sy < 14) {
        if (sx == x_start or sx == x_start + coin_w - 1 or sy == 2 or sy == 13) return [3]f32{ 0.0, 0.0, 0.0 };
        if (sx == x_start + 1 or sy == 3) return COLOR_COIN_HIGHLIGHT;
        return COLOR_COIN_GOLD;
    }
    return null;
}

// ----------------------------------------------------------------------------
// 8. Multi-Core Scanline Parallel Game Renderer
// ----------------------------------------------------------------------------

pub const RenderJob = struct {
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    cam_x: f32,
    cam_y: f32,
    mario: MarioState,
    entities: []const Entity,
    tiles: []const u8,
    tiles_w: usize,
    tiles_h: usize,
    anim_t: f32,
    score: usize,
    coins: usize,
    time_left: usize,
};

fn renderScanlines(job: RenderJob) void {
    const buf = job.buf;
    const w = job.w;
    const tiles = job.tiles;
    const tiles_w = job.tiles_w;
    const tiles_h = job.tiles_h;
    const cam_x = job.cam_x;
    const cam_y = job.cam_y;

    var py: usize = job.start_y;
    while (py < job.end_y) : (py += 1) {
        const world_y = @as(f32, @floatFromInt(py)) + cam_y;
        const tile_y = @divFloor(@as(i64, @intFromFloat(world_y)), 16);
        const sub_y: usize = @intCast(@mod(@as(i64, @intFromFloat(world_y)), 16));

        var px: usize = 0;
        while (px < w) : (px += 1) {
            const world_x = @as(f32, @floatFromInt(px)) + cam_x;
            const tile_x = @divFloor(@as(i64, @intFromFloat(world_x)), 16);
            const sub_x: usize = @intCast(@mod(@as(i64, @intFromFloat(world_x)), 16));

            var pixel_color = COLOR_SKY;

            if (tile_y >= 0 and tile_y < @as(i64, @intCast(tiles_h)) and tile_x >= 0 and tile_x < @as(i64, @intCast(tiles_w))) {
                const t_idx = @as(usize, @intCast(tile_y)) * tiles_w + @as(usize, @intCast(tile_x));
                if (t_idx < tiles.len) {
                    pixel_color = getTilePixel(tiles[t_idx], sub_x, sub_y, job.anim_t);
                }
            }

            // Entities
            for (job.entities) |ent| {
                const screen_ex = ent.x - cam_x;
                const screen_ey = ent.y - cam_y;
                if (@as(f32, @floatFromInt(px)) >= screen_ex and @as(f32, @floatFromInt(px)) < screen_ex + 16.0 and
                    @as(f32, @floatFromInt(py)) >= screen_ey and @as(f32, @floatFromInt(py)) < screen_ey + 16.0)
                {
                    const ent_screen_px = px;
                    const ent_screen_py = py;
                    var local_ent = ent;
                    local_ent.x = screen_ex;
                    local_ent.y = screen_ey;

                    if (ent.entity_type == 1) {
                        if (getGoombaPixel(local_ent, ent_screen_px, ent_screen_py)) |gc| {
                            pixel_color = gc;
                        }
                    } else if (ent.entity_type == 2) {
                        if (getCoinPixel(local_ent, ent_screen_px, ent_screen_py)) |cc| {
                            pixel_color = cc;
                        }
                    }
                }
            }

            // Mario
            const screen_mx = job.mario.x - cam_x;
            const screen_my = job.mario.y - cam_y;
            if (@as(f32, @floatFromInt(px)) >= screen_mx and @as(f32, @floatFromInt(px)) < screen_mx + 16.0 and
                @as(f32, @floatFromInt(py)) >= screen_my and @as(f32, @floatFromInt(py)) < screen_my + 16.0)
            {
                var local_mario = job.mario;
                local_mario.x = screen_mx;
                local_mario.y = screen_my;
                if (getMarioPixel(local_mario, px, py)) |mc| {
                    pixel_color = mc;
                }
            }

            // Write into GPU buffer
            const out_idx = (py * w + px) * 3;
            if (out_idx + 2 < buf.data.len) {
                buf.data[out_idx] = pixel_color[0];
                buf.data[out_idx + 1] = pixel_color[1];
                buf.data[out_idx + 2] = pixel_color[2];
            }
        }
    }
}

pub fn renderGameScene(allocator: std.mem.Allocator, args: []const Dynamic, _: ?*anyopaque) anyerror!Dynamic {
    if (args.len < 12) return Dynamic.initNone();

    var arg_offset: usize = 0;
    if (args.len > 12 and args[0].value == .str_type) {
        arg_offset = 1;
    }

    const buf_dyn = args[arg_offset + 0];
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    const w: usize = if (args[arg_offset + 1].value == .i64_type) @intCast(args[arg_offset + 1].value.i64_type) else 256;
    const h: usize = if (args[arg_offset + 2].value == .i64_type) @intCast(args[arg_offset + 2].value.i64_type) else 240;

    var cam_x: f32 = 0.0;
    if (args[arg_offset + 3].value == .float_type) cam_x = @floatCast(args[arg_offset + 3].value.float_type);
    var cam_y: f32 = 0.0;
    if (args[arg_offset + 4].value == .float_type) cam_y = @floatCast(args[arg_offset + 4].value.float_type);

    // Mario state unpacking
    var mario = MarioState{
        .x = 40.0,
        .y = 192.0,
        .vx = 0.0,
        .vy = 0.0,
        .facing = 1,
        .is_grounded = true,
        .is_dead = false,
        .anim_frame = 0,
    };
    const mario_dyn = args[arg_offset + 5];
    if (mario_dyn.value == .list_type) {
        const items = mario_dyn.value.list_type.items.items;
        if (items.len >= 6) {
            if (items[0].value == .float_type) mario.x = @floatCast(items[0].value.float_type);
            if (items[1].value == .float_type) mario.y = @floatCast(items[1].value.float_type);
            if (items[2].value == .float_type) mario.vx = @floatCast(items[2].value.float_type);
            if (items[3].value == .float_type) mario.vy = @floatCast(items[3].value.float_type);
            if (items[4].value == .i64_type) mario.facing = @intCast(items[4].value.i64_type);
            if (items[5].value == .bool_type) mario.is_grounded = items[5].value.bool_type;
            if (items.len >= 7 and items[6].value == .bool_type) mario.is_dead = items[6].value.bool_type;
            if (items.len >= 8 and items[7].value == .i64_type) mario.anim_frame = @intCast(items[7].value.i64_type);
        }
    }

    // Entities unpacking
    var entity_list = std.ArrayList(Entity).initCapacity(allocator, 32) catch std.ArrayList(Entity).empty;
    defer entity_list.deinit(allocator);

    const entities_dyn = args[arg_offset + 6];
    if (entities_dyn.value == .list_type) {
        for (entities_dyn.value.list_type.items.items) |ent_dyn| {
            if (ent_dyn.value == .list_type) {
                const e_items = ent_dyn.value.list_type.items.items;
                if (e_items.len >= 6) {
                    const e_type: u8 = if (e_items[0].value == .i64_type) @intCast(e_items[0].value.i64_type) else 1;
                    const ex: f32 = if (e_items[1].value == .float_type) @floatCast(e_items[1].value.float_type) else 0.0;
                    const ey: f32 = if (e_items[2].value == .float_type) @floatCast(e_items[2].value.float_type) else 0.0;
                    const estate: u8 = if (e_items[3].value == .i64_type) @intCast(e_items[3].value.i64_type) else 0;
                    const eanim: f32 = if (e_items[4].value == .float_type) @floatCast(e_items[4].value.float_type) else 0.0;
                    const efacing: i32 = if (e_items[5].value == .i64_type) @intCast(e_items[5].value.i64_type) else 1;
                    entity_list.append(allocator, Entity{
                        .entity_type = e_type,
                        .x = ex,
                        .y = ey,
                        .state = estate,
                        .anim_timer = eanim,
                        .facing = efacing,
                    }) catch {};
                }
            }
        }
    }

    // Tiles unpacking
    const tiles_dyn = args[arg_offset + 7];
    const tiles_w: usize = if (args[arg_offset + 8].value == .i64_type) @intCast(args[arg_offset + 8].value.i64_type) else 224;
    const tiles_h: usize = if (args[arg_offset + 9].value == .i64_type) @intCast(args[arg_offset + 9].value.i64_type) else 15;

    var tile_bytes = try allocator.alloc(u8, tiles_w * tiles_h);
    defer allocator.free(tile_bytes);
    @memset(tile_bytes, 0);

    if (tiles_dyn.value == .list_type) {
        const t_items = tiles_dyn.value.list_type.items.items;
        const copy_len = @min(tile_bytes.len, t_items.len);
        for (0..copy_len) |i| {
            if (t_items[i].value == .i64_type) {
                tile_bytes[i] = @intCast(t_items[i].value.i64_type);
            }
        }
    }

    // HUD unpacking
    var score: usize = 0;
    var coins: usize = 0;
    var time_left: usize = 400;
    const hud_dyn = args[arg_offset + 10];
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
    if (args[arg_offset + 11].value == .float_type) anim_t = @floatCast(args[arg_offset + 11].value.float_type);

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

    // Render HUD Text Overlay directly on top of the buffer
    var score_buf: [32]u8 = undefined;
    const score_str = std.fmt.bufPrint(&score_buf, "{d:0>6}", .{score}) catch "000000";

    var coins_buf: [32]u8 = undefined;
    const coins_str = std.fmt.bufPrint(&coins_buf, "*{d:0>2}", .{coins}) catch "*00";

    var time_buf: [32]u8 = undefined;
    const time_str = std.fmt.bufPrint(&time_buf, "{d:0>3}", .{time_left}) catch "400";

    draw_text_fast(buf, w, h, "MARIO          WORLD   TIME", 24, 10, 1, 252.0, 252.0, 252.0);
    draw_text_fast(buf, w, h, score_str, 24, 20, 1, 252.0, 252.0, 252.0);
    draw_text_fast(buf, w, h, coins_str, 96, 20, 1, 252.0, 252.0, 252.0);
    draw_text_fast(buf, w, h, "1-1", 144, 20, 1, 252.0, 252.0, 252.0);
    draw_text_fast(buf, w, h, time_str, 200, 20, 1, 252.0, 252.0, 252.0);

    buf.toDevice();
    return Dynamic.initNone();
}

// Backward-compatible wrapper for render_mario_frame
pub fn renderMarioFrame(allocator: std.mem.Allocator, args: []const Dynamic, opt: ?*anyopaque) anyerror!Dynamic {
    return renderGameScene(allocator, args, opt);
}

// Direct 12-argument slice dispatcher
pub fn render_mario_frame_slice(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    cam_x_dyn: Dynamic,
    cam_y_dyn: Dynamic,
    mario_dyn: Dynamic,
    entities_dyn: Dynamic,
    tiles_dyn: Dynamic,
    map_w_dyn: Dynamic,
    map_h_dyn: Dynamic,
    hud_dyn: Dynamic,
    time_dyn: Dynamic,
) anyerror!Dynamic {
    const args = [_]Dynamic{
        buf_dyn,
        w_dyn,
        h_dyn,
        cam_x_dyn,
        cam_y_dyn,
        mario_dyn,
        entities_dyn,
        tiles_dyn,
        map_w_dyn,
        map_h_dyn,
        hud_dyn,
        time_dyn,
    };
    return renderGameScene(std.heap.c_allocator, &args, null);
}

// ----------------------------------------------------------------------------
// 9. Module Reflection & Attribute Dispatch
pub const clear = clear_surface;
pub const blit = blit_surface;
pub const render_game_scene = render_mario_frame_slice;
pub const render_mario_frame = render_mario_frame_slice;

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "create_surface")) return @import("datatype/dynamic.zig").toDynamicFunc(create_surface);
    if (std.mem.eql(u8, attr, "clear")) return @import("datatype/dynamic.zig").toDynamicFunc(clear_surface);
    if (std.mem.eql(u8, attr, "draw_rect")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_rect);
    if (std.mem.eql(u8, attr, "draw_line")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_line);
    if (std.mem.eql(u8, attr, "draw_circle")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_circle);
    if (std.mem.eql(u8, attr, "draw_text")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_text);
    if (std.mem.eql(u8, attr, "blit")) return @import("datatype/dynamic.zig").toDynamicFunc(blit_surface);
    if (std.mem.eql(u8, attr, "rgb_to_bgr")) return @import("datatype/dynamic.zig").toDynamicFunc(rgb_to_bgr);
    if (std.mem.eql(u8, attr, "render_game_scene")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame_slice } };
    if (std.mem.eql(u8, attr, "render_mario_frame")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame_slice } };
    return error.AttributeError;
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
