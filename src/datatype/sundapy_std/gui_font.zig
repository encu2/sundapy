const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

// ============================================================================
// SundaPy GUI Engine - Procedural Font & Text Rasterizer
// ============================================================================

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
    if (sc == 1) {
        for (str, 0..) |ch, i| {
            const glyph = getCharGlyph(ch);
            const char_x = x + i * 8;
            if (char_x >= w or y >= h) continue;
            var gy: usize = 0;
            while (gy < 8) : (gy += 1) {
                const py = y + gy;
                if (py >= h) break;
                const row = glyph[gy];
                if (row == 0) continue;
                const row_idx = py * w * 3;
                var gx: usize = 0;
                while (gx < 8) : (gx += 1) {
                    if ((row & (@as(u8, 0x80) >> @intCast(gx))) != 0) {
                        const px = char_x + gx;
                        if (px < w) {
                            const idx = row_idx + px * 3;
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
        return;
    }
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
    return Dynamic.initNone();
}
