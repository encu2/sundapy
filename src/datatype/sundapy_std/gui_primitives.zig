const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

// ============================================================================
// SundaPy GUI Engine - 2D Drawing Primitives & Surface Operations
// ============================================================================

pub fn create_surface(w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 240;
    const total_pixels = w * h * 3;
    const total_dyn = Dynamic.initInt(@intCast(total_pixels));
    return @import("gpu.zig").alloc(total_dyn);
}

pub fn clear_surface(buf_dyn: Dynamic, r_dyn: Dynamic, g_dyn: Dynamic, b_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else if (r_dyn.value == .i64_type) @floatFromInt(r_dyn.value.i64_type) else 0.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else if (g_dyn.value == .i64_type) @floatFromInt(g_dyn.value.i64_type) else 0.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else if (b_dyn.value == .i64_type) @floatFromInt(b_dyn.value.i64_type) else 0.0;

    if (r == 0.0 and g == 0.0 and b == 0.0) {
        @memset(buf.data, 0.0);
    } else {
        var i: usize = 0;
        const len = buf.data.len;
        while (i + 2 < len) : (i += 3) {
            buf.data[i] = r;
            buf.data[i + 1] = g;
            buf.data[i + 2] = b;
        }
    }
    return Dynamic.initNone();
}

pub fn sync(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
        buf.toDevice();
    }
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

pub fn draw_pixel(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    x_dyn: Dynamic,
    y_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 1920;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 1080;
    const x: i64 = if (x_dyn.value == .i64_type) x_dyn.value.i64_type else if (x_dyn.value == .float_type) @as(i64, @intFromFloat(x_dyn.value.float_type)) else 0;
    const y: i64 = if (y_dyn.value == .i64_type) y_dyn.value.i64_type else if (y_dyn.value == .float_type) @as(i64, @intFromFloat(y_dyn.value.float_type)) else 0;
    const r: f32 = if (r_dyn.value == .float_type) @floatCast(r_dyn.value.float_type) else if (r_dyn.value == .i64_type) @floatFromInt(r_dyn.value.i64_type) else 255.0;
    const g: f32 = if (g_dyn.value == .float_type) @floatCast(g_dyn.value.float_type) else if (g_dyn.value == .i64_type) @floatFromInt(g_dyn.value.i64_type) else 255.0;
    const b: f32 = if (b_dyn.value == .float_type) @floatCast(b_dyn.value.float_type) else if (b_dyn.value == .i64_type) @floatFromInt(b_dyn.value.i64_type) else 255.0;

    draw_pixel_fast(buf, w, h, x, y, r, g, b);
    return Dynamic.initNone();
}

pub fn draw_pixel_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len < 8) return Dynamic.initNone();
    return draw_pixel(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
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

    if (rw == 1 and rh == 1) {
        draw_pixel_fast(buf, w, h, rx, ry, r, g, b);
        return Dynamic.initNone();
    }

    if (fill) {
        const x_start = @max(0, rx);
        const x_end = @min(@as(i64, @intCast(w)), rx + rw);
        const y_start = @max(0, ry);
        const y_end = @min(@as(i64, @intCast(h)), ry + rh);
        if (x_end > x_start and y_end > y_start) {
            const span_len = @as(usize, @intCast(x_end - x_start));
            var py = y_start;
            while (py < y_end) : (py += 1) {
                var idx = (@as(usize, @intCast(py)) * w + @as(usize, @intCast(x_start))) * 3;
                var count: usize = 0;
                while (count < span_len and idx + 2 < buf.data.len) : ({
                    count += 1;
                    idx += 3;
                }) {
                    buf.data[idx] = r;
                    buf.data[idx + 1] = g;
                    buf.data[idx + 2] = b;
                }
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
    return Dynamic.initNone();
}

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
