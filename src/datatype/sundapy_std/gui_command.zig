// ============================================================================
// SundaPy GUI Engine - Compact 24-Byte Draw-Command Representation
// Serializes vector draw lists into ultra-dense 24-byte instruction streams
// ============================================================================

const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_clip = @import("gui_clip.zig");
const ClipRect = gui_clip.ClipRect;
const gui_palette = @import("gui_palette.zig");
const ColorRGBA8 = gui_palette.ColorRGBA8;
const gui_font = @import("gui_font.zig");

pub const CommandOp = enum(u8) {
    nop = 0,
    clear = 1,
    pixel = 2,
    rect = 3,
    rect_outline = 4,
    line = 5,
    circle = 6,
    circle_outline = 7,
    text = 8,
    set_clip = 9,
    reset_clip = 10,
};

pub const PackedDrawCommand = extern struct {
    op: CommandOp,
    flags: u8 = 0,
    palette_idx: u16 = 0,
    x: i16 = 0,
    y: i16 = 0,
    w: u16 = 0,
    h: u16 = 0,
    color: u32 = 0, // ColorRGBA8 packed
    data: u32 = 0,  // Secondary param (radius, scale, text string offset)

    pub inline fn initClear(r: u8, g: u8, b: u8) PackedDrawCommand {
        return .{
            .op = .clear,
            .color = ColorRGBA8.init(r, g, b, 255).toU32(),
        };
    }

    pub inline fn initRect(x: i16, y: i16, w: u16, h: u16, col: ColorRGBA8, fill: bool) PackedDrawCommand {
        return .{
            .op = if (fill) .rect else .rect_outline,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .color = col.toU32(),
        };
    }

    pub inline fn initLine(x0: i16, y0: i16, x1: i16, y1: i16, col: ColorRGBA8) PackedDrawCommand {
        return .{
            .op = .line,
            .x = x0,
            .y = y0,
            .w = @bitCast(x1),
            .h = @bitCast(y1),
            .color = col.toU32(),
        };
    }

    pub inline fn initCircle(cx: i16, cy: i16, rad: u16, col: ColorRGBA8, fill: bool) PackedDrawCommand {
        return .{
            .op = if (fill) .circle else .circle_outline,
            .x = cx,
            .y = cy,
            .w = rad,
            .color = col.toU32(),
        };
    }

    pub inline fn initText(x: i16, y: i16, text_offset: u32, text_len: u16, scale: u8, col: ColorRGBA8) PackedDrawCommand {
        return .{
            .op = .text,
            .x = x,
            .y = y,
            .w = text_len,
            .flags = scale,
            .color = col.toU32(),
            .data = text_offset,
        };
    }
};

pub const CommandBuffer = struct {
    commands: []PackedDrawCommand,
    command_count: usize = 0,
    text_pool: []u8,
    text_pool_len: usize = 0,
    allocator: ?std.mem.Allocator = null,

    pub fn initPreallocated(cmd_storage: []PackedDrawCommand, text_storage: []u8) CommandBuffer {
        return .{
            .commands = cmd_storage,
            .command_count = 0,
            .text_pool = text_storage,
            .text_pool_len = 0,
            .allocator = null,
        };
    }

    pub fn initAllocated(allocator: std.mem.Allocator, max_cmds: usize, max_text: usize) !CommandBuffer {
        const cmd_mem = try allocator.alloc(PackedDrawCommand, max_cmds);
        const text_mem = try allocator.alloc(u8, max_text);
        return .{
            .commands = cmd_mem,
            .command_count = 0,
            .text_pool = text_mem,
            .text_pool_len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CommandBuffer) void {
        if (self.allocator) |alloc| {
            alloc.free(self.commands);
            alloc.free(self.text_pool);
        }
    }

    pub inline fn clear(self: *CommandBuffer) void {
        self.command_count = 0;
        self.text_pool_len = 0;
    }

    pub inline fn getMemoryBytes(self: *const CommandBuffer) usize {
        return self.commands.len * @sizeOf(PackedDrawCommand) + self.text_pool.len;
    }

    pub inline fn getCommandCapacity(self: *const CommandBuffer) usize {
        return self.commands.len;
    }

    pub fn push(self: *CommandBuffer, cmd: PackedDrawCommand) bool {
        if (self.command_count >= self.commands.len) return false;
        self.commands[self.command_count] = cmd;
        self.command_count += 1;
        return true;
    }

    pub fn pushText(self: *CommandBuffer, x: i16, y: i16, text: []const u8, scale: u8, col: ColorRGBA8) bool {
        if (self.command_count >= self.commands.len) return false;
        if (self.text_pool_len + text.len > self.text_pool.len) return false;

        const offset: u32 = @intCast(self.text_pool_len);
        @memcpy(self.text_pool[offset .. offset + text.len], text);
        self.text_pool_len += text.len;

        return self.push(PackedDrawCommand.initText(x, y, offset, @intCast(text.len), scale, col));
    }

    pub fn execute(self: *const CommandBuffer, buf: *GpuBuffer, w: usize, h: usize) void {
        var scissor = gui_clip.ScissorStack.init();
        var i: usize = 0;

        while (i < self.command_count) : (i += 1) {
            const cmd = self.commands[i];
            const active_clip = scissor.current();
            const col = ColorRGBA8.fromU32(cmd.color);
            const rf: f32 = @floatFromInt(col.r);
            const gf: f32 = @floatFromInt(col.g);
            const bf: f32 = @floatFromInt(col.b);

            switch (cmd.op) {
                .nop => {},
                .clear => {
                    if (col.r == 0 and col.g == 0 and col.b == 0) {
                        @memset(buf.data, 0.0);
                    } else {
                        var pidx: usize = 0;
                        while (pidx + 2 < buf.data.len) : (pidx += 3) {
                            buf.data[pidx] = rf;
                            buf.data[pidx + 1] = gf;
                            buf.data[pidx + 2] = bf;
                        }
                    }
                },
                .pixel => {
                    const px = cmd.x;
                    const py = cmd.y;
                    if (px >= 0 and py >= 0 and px < @as(i16, @intCast(w)) and py < @as(i16, @intCast(h))) {
                        if (active_clip == null or active_clip.?.contains(px, py)) {
                            const idx = (@as(usize, @intCast(py)) * w + @as(usize, @intCast(px))) * 3;
                            if (idx + 2 < buf.data.len) {
                                buf.data[idx] = rf;
                                buf.data[idx + 1] = gf;
                                buf.data[idx + 2] = bf;
                            }
                        }
                    }
                },
                .rect => {
                    const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
                    const base_clip = if (active_clip) |c| c.intersect(screen_rect) orelse continue else screen_rect;
                    const clipped = base_clip.intersect(ClipRect.init(cmd.x, cmd.y, cmd.w, cmd.h)) orelse continue;

                    var cy = clipped.y;
                    while (cy < clipped.bottom()) : (cy += 1) {
                        const row_start = @as(usize, @intCast(cy)) * w * 3;
                        var cx = clipped.x;
                        while (cx < clipped.right()) : (cx += 1) {
                            const idx = row_start + @as(usize, @intCast(cx)) * 3;
                            if (idx + 2 < buf.data.len) {
                                buf.data[idx] = rf;
                                buf.data[idx + 1] = gf;
                                buf.data[idx + 2] = bf;
                            }
                        }
                    }
                },
                .rect_outline => {
                    // 4 border segments
                    const rx: i32 = cmd.x;
                    const ry: i32 = cmd.y;
                    const rw: i32 = cmd.w;
                    const rh: i32 = cmd.h;
                    drawLineFast(buf, w, h, rx, ry, rx + rw - 1, ry, rf, gf, bf, active_clip);
                    drawLineFast(buf, w, h, rx, ry + rh - 1, rx + rw - 1, ry + rh - 1, rf, gf, bf, active_clip);
                    drawLineFast(buf, w, h, rx, ry, rx, ry + rh - 1, rf, gf, bf, active_clip);
                    drawLineFast(buf, w, h, rx + rw - 1, ry, rx + rw - 1, ry + rh - 1, rf, gf, bf, active_clip);
                },
                .line => {
                    const x1: i16 = @bitCast(cmd.w);
                    const y1: i16 = @bitCast(cmd.h);
                    drawLineFast(buf, w, h, cmd.x, cmd.y, x1, y1, rf, gf, bf, active_clip);
                },
                .circle => {
                    drawCircleFast(buf, w, h, cmd.x, cmd.y, @intCast(cmd.w), rf, gf, bf, true, active_clip);
                },
                .circle_outline => {
                    drawCircleFast(buf, w, h, cmd.x, cmd.y, @intCast(cmd.w), rf, gf, bf, false, active_clip);
                },
                .text => {
                    const offset = cmd.data;
                    const len = cmd.w;
                    if (offset + len <= self.text_pool_len) {
                        const str = self.text_pool[offset .. offset + len];
                        gui_font.draw_text_clipped(buf, w, h, str, cmd.x, cmd.y, cmd.flags, rf, gf, bf, active_clip);
                    }
                },
                .set_clip => {
                    _ = scissor.push(ClipRect.init(cmd.x, cmd.y, cmd.w, cmd.h));
                },
                .reset_clip => {
                    scissor.clear();
                },
            }
        }
    }
};

fn drawLineFast(buf: *GpuBuffer, w: usize, h: usize, x0_in: i32, y0_in: i32, x1_in: i32, y1_in: i32, r: f32, g: f32, b: f32, clip: ?ClipRect) void {
    const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
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
        if (effective_clip.contains(x0, y0)) {
            const idx = (@as(usize, @intCast(y0)) * w + @as(usize, @intCast(x0))) * 3;
            if (idx + 2 < buf.data.len) {
                buf.data[idx] = r;
                buf.data[idx + 1] = g;
                buf.data[idx + 2] = b;
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

fn drawCircleFast(buf: *GpuBuffer, w: usize, h: usize, cx: i32, cy: i32, rad: i32, r: f32, g: f32, b: f32, fill: bool, clip: ?ClipRect) void {
    const screen_rect = ClipRect.init(0, 0, @intCast(w), @intCast(h));
    const effective_clip = if (clip) |c| c.intersect(screen_rect) orelse return else screen_rect;

    const clip_res = gui_clip.clipCircle(effective_clip, cx, cy, rad);
    if (clip_res == .culled) return;

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
                    const px = cx + dx;
                    if (px >= effective_clip.x and px < effective_clip.right()) {
                        const idx = (@as(usize, @intCast(py)) * w + @as(usize, @intCast(px))) * 3;
                        if (idx + 2 < buf.data.len) {
                            buf.data[idx] = r;
                            buf.data[idx + 1] = g;
                            buf.data[idx + 2] = b;
                        }
                    }
                }
            }
        }
    } else {
        var x: i32 = 0;
        var y: i32 = rad;
        var d: i32 = 3 - 2 * rad;
        while (y >= x) {
            plotPixel(buf, w, cx + x, cy + y, r, g, b, effective_clip);
            plotPixel(buf, w, cx - x, cy + y, r, g, b, effective_clip);
            plotPixel(buf, w, cx + x, cy - y, r, g, b, effective_clip);
            plotPixel(buf, w, cx - x, cy - y, r, g, b, effective_clip);
            plotPixel(buf, w, cx + y, cy + x, r, g, b, effective_clip);
            plotPixel(buf, w, cx - y, cy + x, r, g, b, effective_clip);
            plotPixel(buf, w, cx + y, cy - x, r, g, b, effective_clip);
            plotPixel(buf, w, cx - y, cy - x, r, g, b, effective_clip);
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

inline fn plotPixel(buf: *GpuBuffer, w: usize, px: i32, py: i32, r: f32, g: f32, b: f32, clip: ClipRect) void {
    if (clip.contains(px, py)) {
        const idx = (@as(usize, @intCast(py)) * w + @as(usize, @intCast(px))) * 3;
        if (idx + 2 < buf.data.len) {
            buf.data[idx] = r;
            buf.data[idx + 1] = g;
            buf.data[idx + 2] = b;
        }
    }
}

test "packed draw command and buffer execution" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(PackedDrawCommand));
    var cmd_storage: [16]PackedDrawCommand = undefined;
    var text_storage: [64]u8 = undefined;
    var cb = CommandBuffer.initPreallocated(&cmd_storage, &text_storage);

    _ = cb.push(PackedDrawCommand.initClear(10, 20, 30));
    _ = cb.push(PackedDrawCommand.initRect(5, 5, 10, 10, ColorRGBA8.init(255, 0, 0, 255), true));
    _ = cb.pushText(0, 0, "TEST", 1, ColorRGBA8.init(255, 255, 255, 255));

    try std.testing.expectEqual(@as(usize, 3), cb.command_count);
    try std.testing.expect(cb.getMemoryBytes() > 0);
    cb.clear();
    try std.testing.expectEqual(@as(usize, 0), cb.command_count);
}

