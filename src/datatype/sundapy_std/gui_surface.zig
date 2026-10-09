// ============================================================================
// SundaPy GUI Engine - Ultra-High Memory Compression Indexed Canvas Surface
// 8-bit indexed surface achieves 12x memory reduction (1 byte/px vs 12 bytes/px)
// ============================================================================

const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_clip = @import("gui_clip.zig");
const ClipRect = gui_clip.ClipRect;
const gui_palette = @import("gui_palette.zig");
const SharedPaletteRegistry = gui_palette.SharedPaletteRegistry;
const ColorRGBA8 = gui_palette.ColorRGBA8;
const gui_font = @import("gui_font.zig");

pub const IndexedSurface = struct {
    width: usize,
    height: usize,
    palette_id: u16,
    pixels: []u8,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, w: usize, h: usize, palette_id: u16) !*IndexedSurface {
        const self = try allocator.create(IndexedSurface);
        const mem = try allocator.alloc(u8, w * h);
        @memset(mem, 0);

        self.* = .{
            .width = w,
            .height = h,
            .palette_id = palette_id,
            .pixels = mem,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *IndexedSurface) void {
        self.allocator.free(self.pixels);
        self.allocator.destroy(self);
    }

    pub fn clear(self: *IndexedSurface, color_index: u8) void {
        @memset(self.pixels, color_index);
    }

    pub inline fn drawPixel(self: *IndexedSurface, x: i32, y: i32, color_index: u8, clip: ?ClipRect) void {
        if (x < 0 or y < 0 or x >= @as(i32, @intCast(self.width)) or y >= @as(i32, @intCast(self.height))) return;
        if (clip) |c| {
            if (!c.contains(x, y)) return;
        }
        self.pixels[@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))] = color_index;
    }

    pub fn drawRect(self: *IndexedSurface, x: i32, y: i32, w: i32, h: i32, color_index: u8, fill: bool, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(self.width), @intCast(self.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        if (fill) {
            const clipped = effective_clip.intersect(ClipRect.init(x, y, w, h)) orelse return;
            var cy = clipped.y;
            while (cy < clipped.bottom()) : (cy += 1) {
                const row_start = @as(usize, @intCast(cy)) * self.width;
                const span_start = row_start + @as(usize, @intCast(clipped.x));
                const span_len = @as(usize, @intCast(clipped.w));
                @memset(self.pixels[span_start .. span_start + span_len], color_index);
            }
        } else {
            var px = x;
            while (px < x + w) : (px += 1) {
                self.drawPixel(px, y, color_index, effective_clip);
                self.drawPixel(px, y + h - 1, color_index, effective_clip);
            }
            var py = y;
            while (py < y + h) : (py += 1) {
                self.drawPixel(x, py, color_index, effective_clip);
                self.drawPixel(x + w - 1, py, color_index, effective_clip);
            }
        }
    }

    pub fn drawLine(self: *IndexedSurface, x0_in: i32, y0_in: i32, x1_in: i32, y1_in: i32, color_index: u8, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(self.width), @intCast(self.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var p0 = struct { x: i32, y: i32 }{ .x = x0_in, .y = y0_in };
        var p1 = struct { x: i32, y: i32 }{ .x = x1_in, .y = y1_in };
        if (!gui_clip.clipLine(effective_clip, &p0, &p1)) return;

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
            self.drawPixel(x0, y0, color_index, effective_clip);
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

    pub fn drawCircle(self: *IndexedSurface, cx: i32, cy: i32, rad: i32, color_index: u8, fill: bool, clip: ?ClipRect) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(self.width), @intCast(self.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        if (fill) {
            var dy = -rad;
            while (dy <= rad) : (dy += 1) {
                const py = cy + dy;
                if (py < effective_clip.y or py >= effective_clip.bottom()) continue;
                const r2 = rad * rad;
                const dy2 = dy * dy;
                var dx = -rad;
                while (dx <= rad) : (dx += 1) {
                    if (dx * dx + dy2 <= r2) {
                        self.drawPixel(cx + dx, py, color_index, effective_clip);
                    }
                }
            }
        } else {
            var x: i32 = 0;
            var y: i32 = rad;
            var d: i32 = 3 - 2 * rad;
            while (y >= x) {
                self.drawPixel(cx + x, cy + y, color_index, effective_clip);
                self.drawPixel(cx - x, cy + y, color_index, effective_clip);
                self.drawPixel(cx + x, cy - y, color_index, effective_clip);
                self.drawPixel(cx - x, cy - y, color_index, effective_clip);
                self.drawPixel(cx + y, cy + x, color_index, effective_clip);
                self.drawPixel(cx - y, cy + x, color_index, effective_clip);
                self.drawPixel(cx + y, cy - x, color_index, effective_clip);
                self.drawPixel(cx - y, cy - x, color_index, effective_clip);
                x += 1;
                if (d > 0) {
                    y -= 1;
                    d = d + 4 * (x - y) + 10;
                } else {
                    d = d + 4 * x + 6;
                }
            }
        }
    }

    pub fn drawText(self: *IndexedSurface, str: []const u8, x: i32, y: i32, scale: usize, color_index: u8, clip: ?ClipRect) void {
        const sc = @max(1, scale);
        const char_step: i32 = @intCast(8 * sc);
        const screen_rect = ClipRect.init(0, 0, @intCast(self.width), @intCast(self.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        for (str, 0..) |ch, i| {
            const char_x = x + @as(i32, @intCast(i)) * char_step;
            if (char_x + char_step <= effective_clip.x or char_x >= effective_clip.right()) continue;
            if (y + char_step <= effective_clip.y or y >= effective_clip.bottom()) continue;

            const glyph = gui_font.getPackedGlyph(ch);
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
                            var sx: usize = 0;
                            while (sx < sc) : (sx += 1) {
                                self.drawPixel(px_base + @as(i32, @intCast(sx)), py_base + @as(i32, @intCast(sy)), color_index, effective_clip);
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn blitToGpu(
        self: *const IndexedSurface,
        dst: *GpuBuffer,
        dw: usize,
        dh: usize,
        dx: i32,
        dy: i32,
        colorkey: ?u8,
        alpha: f32,
        clip: ?ClipRect,
    ) void {
        const palette = gui_palette.getSharedPalette(self.palette_id);
        const screen_rect = ClipRect.init(0, 0, @intCast(dw), @intCast(dh));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var sy: usize = 0;
        while (sy < self.height) : (sy += 1) {
            const target_y = dy + @as(i32, @intCast(sy));
            if (target_y < effective_clip.y or target_y >= effective_clip.bottom()) continue;

            const src_row = sy * self.width;
            const dst_row = @as(usize, @intCast(target_y)) * dw * 3;

            var sx: usize = 0;
            while (sx < self.width) : (sx += 1) {
                const target_x = dx + @as(i32, @intCast(sx));
                if (target_x < effective_clip.x or target_x >= effective_clip.right()) continue;

                const c_idx = self.pixels[src_row + sx];
                if (colorkey != null and c_idx == colorkey.?) continue;

                const col = palette[c_idx];
                const rf: f32 = @floatFromInt(col.r);
                const gf: f32 = @floatFromInt(col.g);
                const bf: f32 = @floatFromInt(col.b);

                const d_idx = dst_row + @as(usize, @intCast(target_x)) * 3;
                if (d_idx + 2 < dst.data.len) {
                    if (alpha >= 0.999) {
                        dst.data[d_idx] = rf;
                        dst.data[d_idx + 1] = gf;
                        dst.data[d_idx + 2] = bf;
                    } else {
                        const dr = dst.data[d_idx];
                        const dg = dst.data[d_idx + 1];
                        const db = dst.data[d_idx + 2];
                        dst.data[d_idx] = rf * alpha + dr * (1.0 - alpha);
                        dst.data[d_idx + 1] = gf * alpha + dg * (1.0 - alpha);
                        dst.data[d_idx + 2] = bf * alpha + db * (1.0 - alpha);
                    }
                }
            }
        }
        dst.toDevice();
    }

    pub fn compressFromGpu(self: *IndexedSurface, src: *const GpuBuffer) void {
        const palette = gui_palette.getSharedPalette(self.palette_id);
        const total = @min(self.width * self.height, src.data.len / 3);

        var i: usize = 0;
        while (i < total) : (i += 1) {
            const s_idx = i * 3;
            const r: u8 = @intFromFloat(std.math.clamp(src.data[s_idx], 0.0, 255.0));
            const g: u8 = @intFromFloat(std.math.clamp(src.data[s_idx + 1], 0.0, 255.0));
            const b: u8 = @intFromFloat(std.math.clamp(src.data[s_idx + 2], 0.0, 255.0));
            self.pixels[i] = gui_palette.findNearestPaletteIndex(palette, r, g, b);
        }
    }

    pub fn compressFromGpuFast(self: *IndexedSurface, src: *const GpuBuffer, cache: *const gui_palette.QuantizationCache) void {
        const total = @min(self.width * self.height, src.data.len / 3);
        var i: usize = 0;
        while (i < total) : (i += 1) {
            const s_idx = i * 3;
            const r: u8 = @intFromFloat(std.math.clamp(src.data[s_idx], 0.0, 255.0));
            const g: u8 = @intFromFloat(std.math.clamp(src.data[s_idx + 1], 0.0, 255.0));
            const b: u8 = @intFromFloat(std.math.clamp(src.data[s_idx + 2], 0.0, 255.0));
            self.pixels[i] = gui_palette.findNearestPaletteFast(cache, r, g, b);
        }
    }

    pub fn blitIndexed(
        self: *IndexedSurface,
        src: *const IndexedSurface,
        dx: i32,
        dy: i32,
        colorkey: ?u8,
        clip: ?ClipRect,
    ) void {
        const screen_rect = ClipRect.init(0, 0, @intCast(self.width), @intCast(self.height));
        const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

        var sy: usize = 0;
        while (sy < src.height) : (sy += 1) {
            const target_y = dy + @as(i32, @intCast(sy));
            if (target_y < effective_clip.y or target_y >= effective_clip.bottom()) continue;

            const src_row = sy * src.width;
            const dst_row = @as(usize, @intCast(target_y)) * self.width;

            var sx: usize = 0;
            while (sx < src.width) : (sx += 1) {
                const target_x = dx + @as(i32, @intCast(sx));
                if (target_x < effective_clip.x or target_x >= effective_clip.right()) continue;

                const c_idx = src.pixels[src_row + sx];
                if (colorkey != null and c_idx == colorkey.?) continue;

                self.pixels[dst_row + @as(usize, @intCast(target_x))] = c_idx;
            }
        }
    }

    pub fn compressRLE(self: *const IndexedSurface, out_buf: []u8) usize {
        if (self.pixels.len == 0 or out_buf.len < 2) return 0;
        var out_idx: usize = 0;
        var in_idx: usize = 0;
        const len = self.pixels.len;

        while (in_idx < len) {
            const val = self.pixels[in_idx];
            var run: usize = 1;
            while (in_idx + run < len and self.pixels[in_idx + run] == val and run < 255) : (run += 1) {}
            if (out_idx + 2 > out_buf.len) break;
            out_buf[out_idx] = @intCast(run);
            out_buf[out_idx + 1] = val;
            out_idx += 2;
            in_idx += run;
        }
        return out_idx;
    }

    pub fn decompressRLE(self: *IndexedSurface, rle_data: []const u8) bool {
        var in_idx: usize = 0;
        var out_idx: usize = 0;
        const total_px = self.pixels.len;

        while (in_idx + 1 < rle_data.len and out_idx < total_px) : (in_idx += 2) {
            const run = rle_data[in_idx];
            const val = rle_data[in_idx + 1];
            const count = @min(run, total_px - out_idx);
            @memset(self.pixels[out_idx .. out_idx + count], val);
            out_idx += count;
        }
        return out_idx == total_px;
    }

    pub inline fn getMemoryBytes(self: *const IndexedSurface) usize {
        return self.width * self.height;
    }

    pub inline fn getUncompressedGpuBytes(self: *const IndexedSurface) usize {
        return self.width * self.height * 12;
    }

    pub inline fn getCompressionRatio(self: *const IndexedSurface) f32 {
        _ = self;
        return 12.0;
    }
};

test "indexed surface memory and RLE" {
    const allocator = std.testing.allocator;
    const surf = try IndexedSurface.create(allocator, 64, 64, 0);
    defer surf.deinit();

    try std.testing.expectEqual(@as(usize, 4096), surf.getMemoryBytes());
    try std.testing.expectEqual(@as(usize, 4096 * 12), surf.getUncompressedGpuBytes());

    surf.clear(7);
    surf.drawRect(10, 10, 20, 20, 3, true, null);

    var rle_buf: [8192]u8 = undefined;
    const compressed_len = surf.compressRLE(&rle_buf);
    try std.testing.expect(compressed_len > 0 and compressed_len < 4096);

    const surf2 = try IndexedSurface.create(allocator, 64, 64, 0);
    defer surf2.deinit();
    try std.testing.expect(surf2.decompressRLE(rle_buf[0..compressed_len]));
    try std.testing.expectEqualSlices(u8, surf.pixels, surf2.pixels);
}

