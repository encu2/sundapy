const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const pool = @import("gpu_pool.zig");
const math3d = @import("gpu_math3d.zig");
const Vec3 = math3d.Vec3;

// ============================================================================
// Multi-Core 3D Raymarching & Blinn-Phong Shading Engine
// ============================================================================

fn sdfSphere(p: Vec3, r: f32) f32 {
    return p.length() - r;
}

fn sdfBox(p: Vec3, b: Vec3) f32 {
    const qx = @abs(p.x) - b.x;
    const qy = @abs(p.y) - b.y;
    const qz = @abs(p.z) - b.z;
    const ex = @max(qx, 0.0);
    const ey = @max(qy, 0.0);
    const ez = @max(qz, 0.0);
    const len = @sqrt(ex * ex + ey * ey + ez * ez);
    return len + @min(@max(qx, @max(qy, qz)), 0.0);
}

fn sdfTorus(p: Vec3, r_major: f32, r_minor: f32) f32 {
    const qx = @sqrt(p.x * p.x + p.z * p.z) - r_major;
    return @sqrt(qx * qx + p.y * p.y) - r_minor;
}

fn sdfCylinder(p: Vec3, h: f32, r: f32) f32 {
    const dx = @sqrt(p.x * p.x + p.z * p.z) - r;
    const dy = @abs(p.y) - h;
    const ex = @max(dx, 0.0);
    const ey = @max(dy, 0.0);
    return @min(@max(dx, dy), 0.0) + @sqrt(ex * ex + ey * ey);
}

fn smoothMin(d1: f32, d2: f32, k: f32) f32 {
    const h = @max(k - @abs(d1 - d2), 0.0) / k;
    return @min(d1, d2) - h * h * k * 0.25;
}

fn rotateY(p: Vec3, ang: f32) Vec3 {
    const c = @cos(ang);
    const s = @sin(ang);
    return Vec3.init(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

fn rotateX(p: Vec3, ang: f32) Vec3 {
    const c = @cos(ang);
    const s = @sin(ang);
    return Vec3.init(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

fn mapScene(p: Vec3, shape_type: u32, t: f32) struct { dist: f32, is_floor: bool } {
    const floor_dist = p.y + 1.2;
    var prot = rotateY(p, t * 0.8);
    prot = rotateX(prot, t * 0.5);

    var obj_dist: f32 = 0.0;
    switch (shape_type) {
        0 => { // Sphere with surface harmonics
            const ripple = 0.04 * @sin(prot.x * 8.0 + t * 2.0) * @sin(prot.y * 8.0);
            obj_dist = sdfSphere(prot, 1.0) + ripple;
        },
        1 => { // Rounded Box
            obj_dist = sdfBox(prot, Vec3.init(0.7, 0.7, 0.7)) - 0.1;
        },
        2 => { // Torus
            obj_dist = sdfTorus(prot, 0.85, 0.32);
        },
        3 => { // Cylinder
            obj_dist = sdfCylinder(prot, 0.75, 0.55);
        },
        else => { // CSG: Smooth-blend of sphere and torus
            const d1 = sdfSphere(prot, 0.8);
            const d2 = sdfTorus(prot, 0.95, 0.25);
            obj_dist = smoothMin(d1, d2, 0.25);
        },
    }

    if (floor_dist < obj_dist) {
        return .{ .dist = floor_dist, .is_floor = true };
    }
    return .{ .dist = obj_dist, .is_floor = false };
}

fn calcNormal(p: Vec3, shape_type: u32, t: f32) Vec3 {
    const eps: f32 = 0.002;
    const d = mapScene(p, shape_type, t).dist;
    const nx = mapScene(p.add(Vec3.init(eps, 0, 0)), shape_type, t).dist - d;
    const ny = mapScene(p.add(Vec3.init(0, eps, 0)), shape_type, t).dist - d;
    const nz = mapScene(p.add(Vec3.init(0, 0, eps)), shape_type, t).dist - d;
    return Vec3.init(nx, ny, nz).normalize();
}

fn calcSoftShadow(ro: Vec3, rd: Vec3, mint: f32, maxt: f32, k: f32, shape_type: u32, t: f32) f32 {
    var res: f32 = 1.0;
    var march_t: f32 = mint;
    var iter: usize = 0;
    while (iter < 20 and march_t < maxt) : (iter += 1) {
        const p = ro.add(rd.scale(march_t));
        const d = mapScene(p, shape_type, t).dist;
        if (d < 0.001) return 0.0;
        res = @min(res, k * d / march_t);
        march_t += @max(d, 0.02);
    }
    return @max(0.0, @min(1.0, res));
}

const RowChunkPayload = struct {
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    ro: Vec3,
    forward: Vec3,
    right: Vec3,
    up: Vec3,
    shape_type: u32,
    t: f32,
    is_rgb3: bool,
};

fn renderRowChunk(p: RowChunkPayload) void {
    const light_dir = Vec3.init(0.577, 0.8, 0.577).normalize();
    const aspect = @as(f32, @floatFromInt(p.w)) / @as(f32, @floatFromInt(p.h));
    const fov_scale: f32 = 0.9;

    var py = p.start_y;
    while (py < p.end_y) : (py += 1) {
        const ndc_y = (1.0 - 2.0 * (@as(f32, @floatFromInt(py)) + 0.5) / @as(f32, @floatFromInt(p.h))) * fov_scale;

        var px: usize = 0;
        while (px < p.w) : (px += 1) {
            const ndc_x = (2.0 * (@as(f32, @floatFromInt(px)) + 0.5) / @as(f32, @floatFromInt(p.w)) - 1.0) * aspect * fov_scale;

            const rd = p.forward.add(p.right.scale(ndc_x)).add(p.up.scale(ndc_y)).normalize();

            var dist_traveled: f32 = 0.1;
            var hit = false;
            var hit_p = Vec3{};
            var is_floor = false;
            var steps: usize = 0;

            while (steps < 64 and dist_traveled < 20.0) : (steps += 1) {
                const cur = p.ro.add(rd.scale(dist_traveled));
                const res = mapScene(cur, p.shape_type, p.t);
                if (res.dist < 0.002) {
                    hit = true;
                    hit_p = cur;
                    is_floor = res.is_floor;
                    break;
                }
                dist_traveled += res.dist;
            }

            var col_r: f32 = 0.0;
            var col_g: f32 = 0.0;
            var col_b: f32 = 0.0;

            if (hit) {
                const norm = calcNormal(hit_p, p.shape_type, p.t);
                const diff = @max(0.0, norm.dot(light_dir));
                const shadow = calcSoftShadow(hit_p.add(norm.scale(0.01)), light_dir, 0.02, 10.0, 16.0, p.shape_type, p.t);

                const half_v = light_dir.sub(rd).normalize();
                const spec_angle = @max(0.0, norm.dot(half_v));
                const spec = std.math.pow(f32, spec_angle, 32.0);

                if (is_floor) {
                    const fx = @floor(hit_p.x * 1.5);
                    const fz = @floor(hit_p.z * 1.5);
                    const check = @mod(@as(i32, @intFromFloat(fx)) + @as(i32, @intFromFloat(fz)), 2) == 0;
                    const base_c: f32 = if (check) 180.0 else 90.0;
                    const illum = (0.2 + 0.8 * diff * shadow);
                    col_r = base_c * illum;
                    col_g = base_c * illum;
                    col_b = base_c * illum;
                } else {
                    const r_base = (0.5 + 0.5 * @cos(norm.x * 3.14 + p.t)) * 220.0;
                    const g_base = (0.5 + 0.5 * @cos(norm.y * 3.14 + p.t + 2.094)) * 220.0;
                    const b_base = (0.5 + 0.5 * @cos(norm.z * 3.14 + p.t + 4.188)) * 220.0;

                    const ambient: f32 = 0.2;
                    const illum = ambient + diff * shadow * 0.8;
                    col_r = @min(255.0, r_base * illum + spec * 255.0);
                    col_g = @min(255.0, g_base * illum + spec * 255.0);
                    col_b = @min(255.0, b_base * illum + spec * 255.0);
                }
            } else {
                // Gradient sky background
                const sky_t = 0.5 * (rd.y + 1.0);
                col_r = (1.0 - sky_t) * 20.0 + sky_t * 60.0;
                col_g = (1.0 - sky_t) * 25.0 + sky_t * 100.0;
                col_b = (1.0 - sky_t) * 45.0 + sky_t * 180.0;
            }

            const pixel_idx = py * p.w + px;
            if (p.is_rgb3) {
                const out_idx = pixel_idx * 3;
                p.buf.data[out_idx] = col_r;
                p.buf.data[out_idx + 1] = col_g;
                p.buf.data[out_idx + 2] = col_b;
            } else {
                const ur: u32 = @min(255, @as(u32, @intFromFloat(col_r)));
                const ug: u32 = @min(255, @as(u32, @intFromFloat(col_g)));
                const ub: u32 = @min(255, @as(u32, @intFromFloat(col_b)));
                const packed_pixel: u32 = 0xFF000000 | (ur << 16) | (ug << 8) | ub;
                p.buf.data[pixel_idx] = @floatFromInt(packed_pixel);
            }
        }
    }
}

fn rowChunkWrapper(ctx: ?*anyopaque) void {
    const p: *RowChunkPayload = @ptrCast(@alignCast(ctx.?));
    renderRowChunk(p.*);
}

pub fn render_3d_object(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    time_dyn: Dynamic,
    shape_dyn: Dynamic,
) anyerror!Dynamic {
    const dist_dyn: ?Dynamic = null;
    const pitch_dyn: ?Dynamic = null;
    const yaw_dyn: ?Dynamic = null;

    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 80;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 40;
    const t: f32 = switch (time_dyn.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.0,
    };
    const shape_type: u32 = if (shape_dyn.value == .i64_type) @intCast(@max(0, shape_dyn.value.i64_type)) else 0;

    const cam_dist: f32 = if (dist_dyn) |d| (switch (d.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 3.5,
    }) else 3.5;

    const cam_pitch: f32 = if (pitch_dyn) |p| (switch (p.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.35,
    }) else 0.35;

    const cam_yaw: f32 = if (yaw_dyn) |y| (switch (y.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => t * 0.4,
    }) else t * 0.4;

    const ro = Vec3.init(
        cam_dist * @cos(cam_pitch) * @sin(cam_yaw),
        cam_dist * @sin(cam_pitch),
        cam_dist * @cos(cam_pitch) * @cos(cam_yaw),
    );
    const target = Vec3.init(0.0, 0.0, 0.0);
    const forward = target.sub(ro).normalize();
    const world_up = Vec3.init(0.0, 1.0, 0.0);
    const right = forward.cross(world_up).normalize();
    const up = right.cross(forward).normalize();

    const is_rgb3 = (buf.size >= w * h * 3);

    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;
    const num_threads = @min(h, @max(1, num_workers));

    var payloads: [pool.MAX_WORKERS]RowChunkPayload = undefined;
    var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
    var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

    const rows_per_thread = (h + num_threads - 1) / num_threads;
    var start_y: usize = 0;
    var count: usize = 0;

    for (0..num_threads) |i| {
        if (start_y >= h) break;
        const end_y = @min(h, start_y + rows_per_thread);

        payloads[i] = RowChunkPayload{
            .buf = buf,
            .w = w,
            .h = h,
            .start_y = start_y,
            .end_y = end_y,
            .ro = ro,
            .forward = forward,
            .right = right,
            .up = up,
            .shape_type = shape_type,
            .t = t,
            .is_rgb3 = is_rgb3,
        };
        funcs[i] = rowChunkWrapper;
        args_ptr[i] = &payloads[i];
        count += 1;
        start_y = end_y;
    }

    global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    buf.toDevice();

    return Dynamic.initNone();
}

pub const render_3d = render_3d_object;
