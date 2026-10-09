// ============================================================================
// SundaPy GUI Engine - Spatial Tile Clipping & Scissor Bounds
// Zero-allocation, high-performance spatial clipping for vector & canvas rendering
// ============================================================================

const std = @import("std");

pub const ClipRect = extern struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub inline fn init(x: i32, y: i32, w: i32, h: i32) ClipRect {
        return .{
            .x = x,
            .y = y,
            .w = @max(0, w),
            .h = @max(0, h),
        };
    }

    pub inline fn isEmpty(self: ClipRect) bool {
        return self.w <= 0 or self.h <= 0;
    }

    pub inline fn right(self: ClipRect) i32 {
        return self.x + self.w;
    }

    pub inline fn bottom(self: ClipRect) i32 {
        return self.y + self.h;
    }

    pub inline fn contains(self: ClipRect, px: i32, py: i32) bool {
        return px >= self.x and px < self.right() and py >= self.y and py < self.bottom();
    }

    pub fn intersect(self: ClipRect, other: ClipRect) ?ClipRect {
        const nx = @max(self.x, other.x);
        const ny = @max(self.y, other.y);
        const nr = @min(self.right(), other.right());
        const nb = @min(self.bottom(), other.bottom());

        if (nr <= nx or nb <= ny) return null;
        return ClipRect{
            .x = nx,
            .y = ny,
            .w = nr - nx,
            .h = nb - ny,
        };
    }

    pub fn intersectsAABB(self: ClipRect, ox: i32, oy: i32, ow: i32, oh: i32) bool {
        if (ow <= 0 or oh <= 0 or self.isEmpty()) return false;
        return self.x < (ox + ow) and self.right() > ox and self.y < (oy + oh) and self.bottom() > oy;
    }
};

// Cohen-Sutherland Outcodes for 2D Line Clipping
pub const OUTCODE_INSIDE: u4 = 0;
pub const OUTCODE_LEFT: u4 = 1;
pub const OUTCODE_RIGHT: u4 = 2;
pub const OUTCODE_BOTTOM: u4 = 4;
pub const OUTCODE_TOP: u4 = 8;

pub inline fn computeOutCode(rect: ClipRect, x: i32, y: i32) u4 {
    var code: u4 = OUTCODE_INSIDE;
    if (x < rect.x) {
        code |= OUTCODE_LEFT;
    } else if (x >= rect.right()) {
        code |= OUTCODE_RIGHT;
    }
    if (y < rect.y) {
        code |= OUTCODE_TOP;
    } else if (y >= rect.bottom()) {
        code |= OUTCODE_BOTTOM;
    }
    return code;
}

pub const Point2D = extern struct { x: i32, y: i32 };

pub fn clipLine(rect: ClipRect, p0: anytype, p1: anytype) bool {
    if (rect.isEmpty()) return false;

    var code0 = computeOutCode(rect, p0.x, p0.y);
    var code1 = computeOutCode(rect, p1.x, p1.y);

    var x0 = @as(f64, @floatFromInt(p0.x));
    var y0 = @as(f64, @floatFromInt(p0.y));
    var x1 = @as(f64, @floatFromInt(p1.x));
    var y1 = @as(f64, @floatFromInt(p1.y));

    while (true) {
        if ((code0 | code1) == 0) {
            p0.x = @as(i32, @intFromFloat(@round(x0)));
            p0.y = @as(i32, @intFromFloat(@round(y0)));
            p1.x = @as(i32, @intFromFloat(@round(x1)));
            p1.y = @as(i32, @intFromFloat(@round(y1)));
            return true;
        } else if ((code0 & code1) != 0) {
            return false;
        } else {
            const outcode_out = if (code0 != 0) code0 else code1;
            var nx: f64 = 0;
            var ny: f64 = 0;

            const rx = @as(f64, @floatFromInt(rect.x));
            const ry = @as(f64, @floatFromInt(rect.y));
            const rr = @as(f64, @floatFromInt(rect.right() - 1));
            const rb = @as(f64, @floatFromInt(rect.bottom() - 1));

            if ((outcode_out & OUTCODE_TOP) != 0) {
                nx = x0 + (x1 - x0) * (ry - y0) / (y1 - y0);
                ny = ry;
            } else if ((outcode_out & OUTCODE_BOTTOM) != 0) {
                nx = x0 + (x1 - x0) * (rb - y0) / (y1 - y0);
                ny = rb;
            } else if ((outcode_out & OUTCODE_RIGHT) != 0) {
                ny = y0 + (y1 - y0) * (rr - x0) / (x1 - x0);
                nx = rr;
            } else if ((outcode_out & OUTCODE_LEFT) != 0) {
                ny = y0 + (y1 - y0) * (rx - x0) / (x1 - x0);
                nx = rx;
            }

            if (outcode_out == code0) {
                x0 = nx;
                y0 = ny;
                code0 = computeOutCode(rect, @as(i32, @intFromFloat(x0)), @as(i32, @intFromFloat(y0)));
            } else {
                x1 = nx;
                y1 = ny;
                code1 = computeOutCode(rect, @as(i32, @intFromFloat(x1)), @as(i32, @intFromFloat(y1)));
            }
        }
    }
}

pub fn clipAABB(rect: ClipRect, x: i32, y: i32, w: i32, h: i32) ?ClipRect {
    if (w <= 0 or h <= 0) return null;
    const prim_rect = ClipRect.init(x, y, w, h);
    return rect.intersect(prim_rect);
}

pub const CircleClipResult = enum {
    culled,
    partially_inside,
    fully_inside,
};

pub fn clipCircle(rect: ClipRect, cx: i32, cy: i32, rad: i32) CircleClipResult {
    if (rad <= 0 or rect.isEmpty()) return .culled;
    const aabb = ClipRect.init(cx - rad, cy - rad, rad * 2, rad * 2);
    if (!rect.intersectsAABB(aabb.x, aabb.y, aabb.w, aabb.h)) return .culled;

    if (cx - rad >= rect.x and cx + rad < rect.right() and
        cy - rad >= rect.y and cy + rad < rect.bottom())
    {
        return .fully_inside;
    }
    return .partially_inside;
}

// Spatial Tile Grid Culling (Default 32x32 Tiles)
pub const TILE_SIZE: usize = 32;

pub const TileBounds = struct {
    tx_min: usize,
    ty_min: usize,
    tx_max: usize,
    ty_max: usize,
};

pub fn computeTileBounds(
    screen_w: usize,
    screen_h: usize,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
) ?TileBounds {
    if (w <= 0 or h <= 0) return null;
    const right = x + w;
    const bottom = y + h;
    if (right <= 0 or bottom <= 0) return null;
    if (x >= @as(i32, @intCast(screen_w)) or y >= @as(i32, @intCast(screen_h))) return null;

    const clamped_x: usize = @intCast(@max(0, x));
    const clamped_y: usize = @intCast(@max(0, y));
    const clamped_r: usize = @intCast(@min(@as(i32, @intCast(screen_w)), right));
    const clamped_b: usize = @intCast(@min(@as(i32, @intCast(screen_h)), bottom));

    if (clamped_r <= clamped_x or clamped_b <= clamped_y) return null;

    return TileBounds{
        .tx_min = clamped_x / TILE_SIZE,
        .ty_min = clamped_y / TILE_SIZE,
        .tx_max = (clamped_r - 1) / TILE_SIZE,
        .ty_max = (clamped_b - 1) / TILE_SIZE,
    };
}

// Zero-Allocation Scissor Stack (Capacity 16)
pub const MAX_SCISSOR_DEPTH: usize = 16;

pub const ScissorStack = struct {
    stack: [MAX_SCISSOR_DEPTH]ClipRect = undefined,
    count: usize = 0,

    pub fn init() ScissorStack {
        return .{};
    }

    pub fn push(self: *ScissorStack, rect: ClipRect) bool {
        if (self.count >= MAX_SCISSOR_DEPTH) return false;
        if (self.count == 0) {
            self.stack[0] = rect;
        } else {
            const cur = self.stack[self.count - 1];
            self.stack[self.count] = cur.intersect(rect) orelse ClipRect.init(0, 0, 0, 0);
        }
        self.count += 1;
        return true;
    }

    pub fn pop(self: *ScissorStack) ?ClipRect {
        if (self.count == 0) return null;
        self.count -= 1;
        return if (self.count > 0) self.stack[self.count - 1] else null;
    }

    pub inline fn current(self: *const ScissorStack) ?ClipRect {
        if (self.count == 0) return null;
        return self.stack[self.count - 1];
    }

    pub inline fn peekDepth(self: *const ScissorStack) usize {
        return self.count;
    }

    pub inline fn clear(self: *ScissorStack) void {
        self.count = 0;
    }
};

// 64-Bit Hierarchical Tile Occupancy Bitmask (8x8 Tile Matrix)
pub fn computeTileMask(screen_w: usize, screen_h: usize, x: i32, y: i32, w: i32, h: i32) u64 {
    const tb = computeTileBounds(screen_w, screen_h, x, y, w, h) orelse return 0;
    const t_min_x = @min(tb.tx_min, 7);
    const t_max_x = @min(tb.tx_max, 7);
    const t_min_y = @min(tb.ty_min, 7);
    const t_max_y = @min(tb.ty_max, 7);

    var mask: u64 = 0;
    var ty: usize = t_min_y;
    while (ty <= t_max_y) : (ty += 1) {
        var tx: usize = t_min_x;
        while (tx <= t_max_x) : (tx += 1) {
            const shift: u6 = @intCast(ty * 8 + tx);
            mask |= (@as(u64, 1) << shift);
        }
    }
    return mask;
}

pub inline fn masksOverlap(mask_a: u64, mask_b: u64) bool {
    return (mask_a & mask_b) != 0;
}

pub fn computePointsAABB(points: []const struct { x: i32, y: i32 }) ?ClipRect {
    if (points.len == 0) return null;
    var min_x = points[0].x;
    var max_x = points[0].x;
    var min_y = points[0].y;
    var max_y = points[0].y;

    for (points[1..]) |pt| {
        min_x = @min(min_x, pt.x);
        max_x = @max(max_x, pt.x);
        min_y = @min(min_y, pt.y);
        max_y = @max(max_y, pt.y);
    }
    return ClipRect.init(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1);
}

test "clip rect intersection" {
    const r1 = ClipRect.init(10, 10, 50, 50);
    const r2 = ClipRect.init(40, 40, 50, 50);
    const inter = r1.intersect(r2);
    try std.testing.expect(inter != null);
    try std.testing.expectEqual(@as(i32, 40), inter.?.x);
    try std.testing.expectEqual(@as(i32, 40), inter.?.y);
    try std.testing.expectEqual(@as(i32, 20), inter.?.w);
    try std.testing.expectEqual(@as(i32, 20), inter.?.h);

    const r3 = ClipRect.init(100, 100, 10, 10);
    try std.testing.expect(r1.intersect(r3) == null);
}

test "line clipping Cohen-Sutherland" {
    const rect = ClipRect.init(0, 0, 100, 100);
    var p0 = struct { x: i32, y: i32 }{ .x = -50, .y = 50 };
    var p1 = struct { x: i32, y: i32 }{ .x = 150, .y = 50 };
    const visible = clipLine(rect, &p0, &p1);
    try std.testing.expect(visible);
    try std.testing.expectEqual(@as(i32, 0), p0.x);
    try std.testing.expectEqual(@as(i32, 99), p1.x);
}

test "circle clipping" {
    const rect = ClipRect.init(0, 0, 100, 100);
    try std.testing.expectEqual(CircleClipResult.fully_inside, clipCircle(rect, 50, 50, 20));
    try std.testing.expectEqual(CircleClipResult.partially_inside, clipCircle(rect, 10, 10, 20));
    try std.testing.expectEqual(CircleClipResult.culled, clipCircle(rect, -50, -50, 10));
}

test "tile bounds and occupancy bitmask" {
    const mask1 = computeTileMask(256, 256, 0, 0, 32, 32);
    try std.testing.expect(mask1 != 0);
    const mask2 = computeTileMask(256, 256, 200, 200, 32, 32);
    try std.testing.expect(mask2 != 0);
    try std.testing.expect(!masksOverlap(mask1, mask2));
}

test "scissor stack depth" {
    var stack = ScissorStack.init();
    try std.testing.expectEqual(@as(usize, 0), stack.peekDepth());
    _ = stack.push(ClipRect.init(0, 0, 100, 100));
    _ = stack.push(ClipRect.init(20, 20, 40, 40));
    try std.testing.expectEqual(@as(usize, 2), stack.peekDepth());
    const cur = stack.current().?;
    try std.testing.expectEqual(@as(i32, 20), cur.x);
    _ = stack.pop();
    try std.testing.expectEqual(@as(usize, 1), stack.peekDepth());
}

