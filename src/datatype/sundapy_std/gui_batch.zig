// ============================================================================
// SundaPy GUI Engine - Instanced Batching Buffers
// Contiguous memory layout for ultra-high throughput batch primitive rendering
// ============================================================================

const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_clip = @import("gui_clip.zig");
const ClipRect = gui_clip.ClipRect;
const gui_palette = @import("gui_palette.zig");
const ColorRGBA8 = gui_palette.ColorRGBA8;
const gui_font = @import("gui_font.zig");

pub const RectInstance = extern struct {
    x: i16,
    y: i16,
    w: u16,
    h: u16,
    color: u32,
    flags: u16 = 0,
    radius: u16 = 0,

    pub inline fn init(x: i16, y: i16, w: u16, h: u16, col: ColorRGBA8) RectInstance {
        return .{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .color = col.toU32(),
        };
    }
};

pub const GlyphInstance = extern struct {
    x: i16,
    y: i16,
    char: u8,
    scale: u8,
    pad: u16 = 0,
    color: u32,

    pub inline fn init(x: i16, y: i16, ch: u8, scale: u8, col: ColorRGBA8) GlyphInstance {
        return .{
            .x = x,
            .y = y,
            .char = ch,
            .scale = scale,
            .color = col.toU32(),
        };
    }
};

pub const LineInstance = extern struct {
    x0: i16,
    y0: i16,
    x1: i16,
    y1: i16,
    color: u32,
    thickness: u32 = 1,

    pub inline fn init(x0: i16, y0: i16, x1: i16, y1: i16, col: ColorRGBA8) LineInstance {
        return .{
            .x0 = x0,
            .y0 = y0,
            .x1 = x1,
            .y1 = y1,
            .color = col.toU32(),
        };
    }
};

pub const InstanceBatcher = struct {
    rects: []RectInstance,
    rect_count: usize = 0,
    glyphs: []GlyphInstance,
    glyph_count: usize = 0,
    lines: []LineInstance,
    line_count: usize = 0,
    allocator: ?std.mem.Allocator = null,

    pub fn initPreallocated(
        rect_storage: []RectInstance,
        glyph_storage: []GlyphInstance,
        line_storage: []LineInstance,
    ) InstanceBatcher {
        return .{
            .rects = rect_storage,
            .rect_count = 0,
            .glyphs = glyph_storage,
            .glyph_count = 0,
            .lines = line_storage,
            .line_count = 0,
            .allocator = null,
        };
    }

    pub fn initAllocated(
        allocator: std.mem.Allocator,
        max_rects: usize,
        max_glyphs: usize,
        max_lines: usize,
    ) !InstanceBatcher {
        const r_mem = try allocator.alloc(RectInstance, max_rects);
        const g_mem = try allocator.alloc(GlyphInstance, max_glyphs);
        const l_mem = try allocator.alloc(LineInstance, max_lines);
        return .{
            .rects = r_mem,
            .rect_count = 0,
            .glyphs = g_mem,
            .glyph_count = 0,
            .lines = l_mem,
            .line_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InstanceBatcher) void {
        if (self.allocator) |alloc| {
            alloc.free(self.rects);
            alloc.free(self.glyphs);
            alloc.free(self.lines);
        }
    }

    pub inline fn clear(self: *InstanceBatcher) void {
        self.rect_count = 0;
        self.glyph_count = 0;
        self.line_count = 0;
    }

    pub fn pushRect(self: *InstanceBatcher, r: RectInstance) bool {
        if (self.rect_count >= self.rects.len) return false;
        self.rects[self.rect_count] = r;
        self.rect_count += 1;
        return true;
    }

    pub fn pushGlyph(self: *InstanceBatcher, g: GlyphInstance) bool {
        if (self.glyph_count >= self.glyphs.len) return false;
        self.glyphs[self.glyph_count] = g;
        self.glyph_count += 1;
        return true;
    }

    pub fn pushString(
        self: *InstanceBatcher,
        x: i16,
        y: i16,
        str: []const u8,
        scale: u8,
        col: ColorRGBA8,
    ) usize {
        const sc = @max(1, scale);
        const step = @as(i16, @intCast(8 * sc));
        var added: usize = 0;
        for (str, 0..) |ch, i| {
            const gx = x + @as(i16, @intCast(i)) * step;
            if (self.pushGlyph(GlyphInstance.init(gx, y, ch, scale, col))) {
                added += 1;
            } else {
                break;
            }
        }
        return added;
    }

    pub fn pushLine(self: *InstanceBatcher, l: LineInstance) bool {
        if (self.line_count >= self.lines.len) return false;
        self.lines[self.line_count] = l;
        self.line_count += 1;
        return true;
    }

    pub fn flushRects(self: *InstanceBatcher, buf: *GpuBuffer, w: usize, h: usize, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var i: usize = 0;
        while (i < self.rect_count) : (i += 1) {
            const r = self.rects[i];
            const clipped = effective_clip.intersect(ClipRect.init(r.x, r.y, r.w, r.h)) orelse continue;
            const col = ColorRGBA8.fromU32(r.color);
            const rf: f32 = @floatFromInt(col.r);
            const gf: f32 = @floatFromInt(col.g);
            const bf: f32 = @floatFromInt(col.b);

            var py = clipped.y;
            while (py < clipped.bottom()) : (py += 1) {
                const row_start = @as(usize, @intCast(py)) * w * 3;
                var px = clipped.x;
                while (px < clipped.right()) : (px += 1) {
                    const idx = row_start + @as(usize, @intCast(px)) * 3;
                    if (idx + 2 < buf.data.len) {
                        buf.data[idx] = rf;
                        buf.data[idx + 1] = gf;
                        buf.data[idx + 2] = bf;
                    }
                }
            }
        }
    }

    pub fn flushGlyphs(self: *InstanceBatcher, buf: *GpuBuffer, w: usize, h: usize, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var i: usize = 0;
        while (i < self.glyph_count) : (i += 1) {
            const g = self.glyphs[i];
            const sc = @max(1, g.scale);
            const char_step: i32 = @intCast(8 * sc);
            const gx: i32 = g.x;
            const gy: i32 = g.y;

            if (gx + char_step <= effective_clip.x or gx >= effective_clip.right()) continue;
            if (gy + char_step <= effective_clip.y or gy >= effective_clip.bottom()) continue;

            const packed_glyph = gui_font.getPackedGlyph(g.char);
            if (packed_glyph == 0) continue;

            const col = ColorRGBA8.fromU32(g.color);
            const rf: f32 = @floatFromInt(col.r);
            const gf: f32 = @floatFromInt(col.g);
            const bf: f32 = @floatFromInt(col.b);

            var row_idx: usize = 0;
            while (row_idx < 8) : (row_idx += 1) {
                const row: u8 = @truncate(packed_glyph >> @intCast(row_idx * 8));
                if (row == 0) continue;

                var col_idx: usize = 0;
                while (col_idx < 8) : (col_idx += 1) {
                    if ((row & (@as(u8, 0x80) >> @intCast(col_idx))) != 0) {
                        const px_base = gx + @as(i32, @intCast(col_idx * sc));
                        const py_base = gy + @as(i32, @intCast(row_idx * sc));

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
                                        buf.data[idx] = rf;
                                        buf.data[idx + 1] = gf;
                                        buf.data[idx + 2] = bf;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn flushLines(self: *InstanceBatcher, buf: *GpuBuffer, w: usize, h: usize, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var i: usize = 0;
        while (i < self.line_count) : (i += 1) {
            const l = self.lines[i];
            const col = ColorRGBA8.fromU32(l.color);
            const rf: f32 = @floatFromInt(col.r);
            const gf: f32 = @floatFromInt(col.g);
            const bf: f32 = @floatFromInt(col.b);

            var p0 = struct { x: i32, y: i32 }{ .x = l.x0, .y = l.y0 };
            var p1 = struct { x: i32, y: i32 }{ .x = l.x1, .y = l.y1 };
            if (!gui_clip.clipLine(effective_clip, &p0, &p1)) continue;

            var x0 = p0.x;
            var y0 = p0.y;
            const x1 = p1.x;
            const y1 = p1.y;

            const dx = @abs(x1 - x0);
            const dy = -@as(i32, @intCast(@abs(y1 - y0)));
            const sx: i32 = if (x0 < x1) 1 else -1;
            const sy: i32 = if (y0 < y1) 1 else -1;
            var err = @as(i32, @intCast(dx)) + dy;

            while (true) {
                if (effective_clip.contains(x0, y0)) {
                    const idx = (@as(usize, @intCast(y0)) * w + @as(usize, @intCast(x0))) * 3;
                    if (idx + 2 < buf.data.len) {
                        buf.data[idx] = rf;
                        buf.data[idx + 1] = gf;
                        buf.data[idx + 2] = bf;
                    }
                }
                if (x0 == x1 and y0 == y1) break;
                const e2 = 2 * err;
                if (e2 >= dy) {
                    err += dy;
                    x0 += sx;
                }
                if (e2 <= @as(i32, @intCast(dx))) {
                    err += @as(i32, @intCast(dx));
                    y0 += sy;
                }
            }
        }
    }

    pub inline fn getBatchMemoryBytes(self: *const InstanceBatcher) usize {
        return self.rect_count * @sizeOf(RectInstance) +
            self.glyph_count * @sizeOf(GlyphInstance) +
            self.line_count * @sizeOf(LineInstance);
    }

    pub inline fn getTotalInstances(self: *const InstanceBatcher) usize {
        return self.rect_count + self.glyph_count + self.line_count;
    }

    pub fn flushRectsIndexed(self: *InstanceBatcher, surf: anytype, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(surf.width), @intCast(surf.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var i: usize = 0;
        while (i < self.rect_count) : (i += 1) {
            const r = self.rects[i];
            const clipped = effective_clip.intersect(ClipRect.init(r.x, r.y, r.w, r.h)) orelse continue;
            const c_idx: u8 = @truncate(r.flags);
            var py = clipped.y;
            while (py < clipped.bottom()) : (py += 1) {
                const row_start = @as(usize, @intCast(py)) * surf.width;
                const span_start = row_start + @as(usize, @intCast(clipped.x));
                const span_len = @as(usize, @intCast(clipped.w));
                @memset(surf.pixels[span_start .. span_start + span_len], c_idx);
            }
        }
    }

    pub fn flushAll(self: *InstanceBatcher, buf: *GpuBuffer, w: usize, h: usize, clip: ?ClipRect) void {
        self.flushRects(buf, w, h, clip);
        self.flushLines(buf, w, h, clip);
        self.flushGlyphs(buf, w, h, clip);
        self.clear();
    }
};

test "instanced batcher queue and metrics" {
    var rect_buf: [16]RectInstance = undefined;
    var glyph_buf: [32]GlyphInstance = undefined;
    var line_buf: [16]LineInstance = undefined;

    var batcher = InstanceBatcher.initPreallocated(&rect_buf, &glyph_buf, &line_buf);
    _ = batcher.pushRect(RectInstance.init(10, 10, 20, 20, ColorRGBA8.init(255, 0, 0, 255)));
    _ = batcher.pushLine(LineInstance.init(0, 0, 100, 100, ColorRGBA8.init(0, 255, 0, 255)));
    _ = batcher.pushString(0, 0, "HI", 1, ColorRGBA8.init(255, 255, 255, 255));

    try std.testing.expectEqual(@as(usize, 4), batcher.getTotalInstances());
    try std.testing.expect(batcher.getBatchMemoryBytes() > 0);

    batcher.clear();
    try std.testing.expectEqual(@as(usize, 0), batcher.getTotalInstances());
}

