// ============================================================================
// SundaPy GUI Engine - Compact 64-Bit Glyph Representation & Text Rasterizer
// Stores full printable ASCII (32..126) in only 760 bytes of memory
// ============================================================================

const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_clip = @import("gui_clip.zig");
const ClipRect = gui_clip.ClipRect;

// Compact 8x8 Bitmap Font Table (1 u64 = 8 rows of 8 bits, 95 printable characters)
// Row y is ((glyph >> (y * 8)) & 0xFF)
pub const ASCII_GLYPHS = [95]u64{
    0x0000000000000000, // 32 ' '
    0x0018001818181818, // 33 '!'
    0x0000000000246666, // 34 '"'
    0x00247E24247E2400, // 35 '#'
    0x00183E603C067C18, // 36 '$'
    0x00466630180C6662, // 37 '%'
    0x003A466E30183420, // 38 '&'
    0x0000000000181808, // 39 '''
    0x000C18303030180C, // 40 '('
    0x0030180C0C0C1830, // 41 ')'
    0x000024663C3C6624, // 42 '*'
    0x000018187E181800, // 43 '+'
    0x0018183000000000, // 44 ','
    0x000000007E000000, // 45 '-'
    0x0018180000000000, // 46 '.'
    0x006030180C060300, // 47 '/'
    0x003C66666666663C, // 48 '0'
    0x007E181818183818, // 49 '1'
    0x007E30180C06663C, // 50 '2'
    0x003C6606061C063C, // 51 '3'
    0x0004047E64341C0C, // 52 '4'
    0x003C6606067C607E, // 53 '5'
    0x003C66667C60301C, // 54 '6'
    0x00181818180C067E, // 55 '7'
    0x003C66663C66663C, // 56 '8'
    0x00380C063E66663C, // 57 '9'
    0x0000181800181800, // 58 ':'
    0x0018183000181800, // 59 ';'
    0x00060C1830180C06, // 60 '<'
    0x00007E007E000000, // 61 '='
    0x006030180C183060, // 62 '>'
    0x001800180C06663C, // 63 '?'
    0x003C606E6A6A603C, // 64 '@'
    0x0066667E66663C18, // 65 'A'
    0x007C66667C66667C, // 66 'B'
    0x003C66606060663C, // 67 'C'
    0x00786C6666666C78, // 68 'D'
    0x007E60607860607E, // 69 'E'
    0x006060607860607E, // 70 'F'
    0x003A66666E60663C, // 71 'G'
    0x006666667E666666, // 72 'H'
    0x003C18181818183C, // 73 'I'
    0x003C66060606060E, // 74 'J'
    0x00666C7870786C66, // 75 'K'
    0x007E606060606060, // 76 'L'
    0x006363636B7F7763, // 77 'M'
    0x0066666E7E7E7666, // 78 'N'
    0x003C66666666663C, // 79 'O'
    0x006060607C66667C, // 80 'P'
    0x00366C6A6666663C, // 81 'Q'
    0x0063666C7C66667C, // 82 'R'
    0x003C66063C60663C, // 83 'S'
    0x001818181818187E, // 84 'T'
    0x003C666666666666, // 85 'U'
    0x00183C6666666666, // 86 'V'
    0x0063777F6B636363, // 87 'W'
    0x0066663C183C6666, // 88 'X'
    0x001818183C666666, // 89 'Y'
    0x007E6030180C067E, // 90 'Z'
    0x003C30303030303C, // 91 '['
    0x0003060C18306000, // 92 '\'
    0x003C0C0C0C0C0C3C, // 93 ']'
    0x0000000000663C18, // 94 '^'
    0x007E000000000000, // 95 '_'
    0x0000000000081830, // 96 '`'
    0x003E66667E603C00, // 97 'a'
    0x007C66667C666060, // 98 'b'
    0x003C666060663C00, // 99 'c'
    0x003E66663E060606, // 100 'd'
    0x003C667E603C0000, // 101 'e'
    0x0030307C30301C0C, // 102 'f'
    0x003E063E66663E00, // 103 'g'
    0x006666667C666060, // 104 'h'
    0x003C181818180018, // 105 'i'
    0x003C660606060006, // 106 'j'
    0x00666C7870686060, // 107 'k'
    0x0038181818181818, // 108 'l'
    0x006B7F6363630000, // 109 'm'
    0x00666666667C0000, // 110 'n'
    0x003C6666663C0000, // 111 'o'
    0x0060607C66667C00, // 112 'p'
    0x0006063E66663E00, // 113 'q'
    0x00606060667C0000, // 114 'r'
    0x007C063C603E0000, // 115 's'
    0x001C3030307C3030, // 116 't'
    0x003E666666660000, // 117 'u'
    0x00183C6666000000, // 118 'v'
    0x00367F6B6B000000, // 119 'w'
    0x00663C183C660000, // 120 'x'
    0x003C063E66660000, // 121 'y'
    0x007E30180C7E0000, // 122 'z'
    0x000E18187018180E, // 123 '{'
    0x0018181818181818, // 124 '|'
    0x007018180E181870, // 125 '}'
    0x00000000245A0000, // 126 '~'
};

pub var custom_glyphs: [32]u64 = [_]u64{
    0x0001020488502000, // 0: Checkmark
    0x0000422418182442, // 1: Cross
    0x0000181C1E1C1800, // 2: Arrow Right
    0x0000007E3C180000, // 3: Arrow Down
    0x0000183878381800, // 4: Arrow Left
    0x000000183C7E0000, // 5: Arrow Up
    0x00003C3C3C3C0000, // 6: Square bullet
    0x00183C7E7E3C1800, // 7: Circle bullet
} ++ ([_]u64{0} ** 24);

pub fn registerCustomGlyph(index: u5, glyph: u64) void {
    custom_glyphs[index] = glyph;
}

pub inline fn getPackedGlyph(c: u8) u64 {
    if (c < 32) return custom_glyphs[@as(u5, @truncate(c))];
    if (c <= 126) return ASCII_GLYPHS[c - 32];
    return 0;
}

pub fn getCharGlyph(c: u8) [8]u8 {
    const packed_val = getPackedGlyph(c);
    return [8]u8{
        @truncate(packed_val),
        @truncate(packed_val >> 8),
        @truncate(packed_val >> 16),
        @truncate(packed_val >> 24),
        @truncate(packed_val >> 32),
        @truncate(packed_val >> 40),
        @truncate(packed_val >> 48),
        @truncate(packed_val >> 56),
    };
}

pub fn measure_text(str: []const u8, scale: usize) struct { width: usize, height: usize } {
    const sc = @max(1, scale);
    return .{
        .width = str.len * (8 * sc),
        .height = 8 * sc,
    };
}

pub fn measureTextMultiline(str: []const u8, scale: usize) struct { width: usize, height: usize, lines: usize } {
    const sc = @max(1, scale);
    var max_line_len: usize = 0;
    var current_len: usize = 0;
    var line_count: usize = if (str.len > 0) 1 else 0;

    for (str) |ch| {
        if (ch == '\n') {
            max_line_len = @max(max_line_len, current_len);
            current_len = 0;
            line_count += 1;
        } else {
            current_len += 1;
        }
    }
    max_line_len = @max(max_line_len, current_len);

    return .{
        .width = max_line_len * (8 * sc),
        .height = line_count * (8 * sc),
        .lines = line_count,
    };
}

pub fn draw_text_fast(
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    str: []const u8,
    x: usize,
    y: usize,
    scale: usize,
    r: f32,
    g: f32,
    b: f32,
) void {
    draw_text_clipped(buf, w, h, str, @intCast(x), @intCast(y), scale, r, g, b, null);
}

pub fn draw_text_clipped(
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    str: []const u8,
    x: i32,
    y: i32,
    scale: usize,
    r: f32,
    g: f32,
    b: f32,
    clip: ?ClipRect,
) void {
    const sc = @max(1, scale);
    const char_step: i32 = @intCast(8 * sc);
    const screen_clip = ClipRect.init(0, 0, @intCast(w), @intCast(h));
    const effective_clip = if (clip) |c| c.intersect(screen_clip) orelse return else screen_clip;

    for (str, 0..) |ch, i| {
        const char_x = x + @as(i32, @intCast(i)) * char_step;
        if (char_x + char_step <= effective_clip.x or char_x >= effective_clip.right()) continue;
        if (y + char_step <= effective_clip.y or y >= effective_clip.bottom()) continue;

        const glyph = getPackedGlyph(ch);
        if (glyph == 0) continue;

        var gy: usize = 0;
        while (gy < 8) : (gy += 1) {
            const row: u8 = @truncate(glyph >> @intCast(gy * 8));
            if (row == 0) continue;

            var gx: usize = 0;
            while (gx < 8) : (gx += 1) {
                if ((row & (@as(u8, 0x80) >> @intCast(gx))) != 0) {
                    const px_base = char_x + @as(i32, @intCast(gx * sc));
                    const py_base = y + @as(i32, @intCast(gy * sc));

                    var sy: usize = 0;
                    while (sy < sc) : (sy += 1) {
                        const py = py_base + @as(i32, @intCast(sy));
                        if (py < effective_clip.y or py >= effective_clip.bottom()) continue;
                        const row_offset = @as(usize, @intCast(py)) * w * 3;

                        var sx: usize = 0;
                        while (sx < sc) : (sx += 1) {
                            const px = px_base + @as(i32, @intCast(sx));
                            if (px >= effective_clip.x and px < effective_clip.right()) {
                                const idx = row_offset + @as(usize, @intCast(px)) * 3;
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
    const x: i32 = if (x_dyn.value == .i64_type) @intCast(x_dyn.value.i64_type) else 0;
    const y: i32 = if (y_dyn.value == .i64_type) @intCast(y_dyn.value.i64_type) else 0;
    const sc: usize = if (scale_dyn.value == .i64_type) @intCast(@max(1, scale_dyn.value.i64_type)) else 1;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else 255.0;

    draw_text_clipped(buf, w, h, s, x, y, sc, r, g, b, null);
    return Dynamic.initNone();
}

pub fn draw_text_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len < 4) return Dynamic.initNone();
    const buf = args[0];
    const w = args[1];
    const h = args[2];
    const s = args[3];
    const x = if (args.len > 4) args[4] else Dynamic.initInt(0);
    const y = if (args.len > 5) args[5] else Dynamic.initInt(0);
    const sc = if (args.len > 6) args[6] else Dynamic.initInt(1);
    const r = if (args.len > 7) args[7] else Dynamic.initFloat(255.0);
    const g = if (args.len > 8) args[8] else Dynamic.initFloat(255.0);
    const b = if (args.len > 9) args[9] else Dynamic.initFloat(255.0);
    return draw_text(buf, w, h, s, x, y, sc, r, g, b);
}

test "packed glyph extraction" {
    const space = getPackedGlyph(' ');
    try std.testing.expectEqual(@as(u64, 0), space);
    const exclamation = getPackedGlyph('!');
    try std.testing.expect(exclamation != 0);
    const char_bytes = getCharGlyph('!');
    try std.testing.expectEqual(@as(u8, 0x18), char_bytes[0]);
}

test "text measurement" {
    const m = measure_text("HELLO", 1);
    try std.testing.expectEqual(@as(usize, 40), m.width);
    try std.testing.expectEqual(@as(usize, 8), m.height);

    const ml = measureTextMultiline("LINE1\nLONGER_LINE", 2);
    try std.testing.expectEqual(@as(usize, 11 * 16), ml.width);
    try std.testing.expectEqual(@as(usize, 2 * 16), ml.height);
    try std.testing.expectEqual(@as(usize, 2), ml.lines);
}

test "custom glyph registration" {
    const icon_check = getPackedGlyph(0);
    try std.testing.expect(icon_check != 0);
    registerCustomGlyph(10, 0x1234567890ABCDEF);
    try std.testing.expectEqual(@as(u64, 0x1234567890ABCDEF), getPackedGlyph(10));
}

