const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const pool = @import("gpu_pool.zig");
const math3d = @import("gpu_math3d.zig");
const Vec3 = math3d.Vec3;
const driver = @import("gpu_driver.zig");
const earth_cuda = @import("gpu_earth_cuda.zig");

// ============================================================================
// Photorealistic 3D Earth Engine: NASA Blue Marble, Black Marble & Clouds
// With Atmospheric Rayleigh Scattering, Sunset Terminator & Ocean Glint
// ============================================================================

const TEXTURE_W: usize = 512;
const TEXTURE_H: usize = 256;
const DAY_SIZE: usize = TEXTURE_W * TEXTURE_H * 3;
const NIGHT_SIZE: usize = TEXTURE_W * TEXTURE_H * 3;
const CLOUD_SIZE: usize = TEXTURE_W * TEXTURE_H;
const TOTAL_TEX_BYTES: usize = DAY_SIZE + NIGHT_SIZE + CLOUD_SIZE;

var texture_data: [TOTAL_TEX_BYTES]u8 = undefined;
var textures_loaded: bool = false;

fn loadTextures() bool {
    if (textures_loaded) return true;
    const paths = [_][*:0]const u8{
        "assets/earth/earth_packed_512x256.bin",
        "/home/encu/myCode/zigCode/pythonZigZag/assets/earth/earth_packed_512x256.bin",
    };
    for (paths) |p| {
        const rc = std.os.linux.open(p, .{ .ACCMODE = .RDONLY }, 0);
        const fd: i32 = @bitCast(@as(u32, @truncate(rc)));
        if (fd >= 0) {
            defer _ = std.os.linux.close(fd);
            var total_read: usize = 0;
            while (total_read < TOTAL_TEX_BYTES) {
                const n = std.os.linux.read(fd, texture_data[total_read..].ptr, TOTAL_TEX_BYTES - total_read);
                const signed_n: isize = @bitCast(n);
                if (signed_n <= 0) break;
                total_read += @intCast(signed_n);
            }
            if (total_read == TOTAL_TEX_BYTES) {
                textures_loaded = true;
                return true;
            }
        }
    }
    return false;
}

const SampleResult = struct {
    day_r: f32, day_g: f32, day_b: f32,
    night_r: f32, night_g: f32, night_b: f32,
    cloud: f32,
    is_water: bool,
};

fn sampleNasaEarth(p: Vec3, earth_rot: f32, cloud_rot: f32) SampleResult {
    // Earth axial tilt: 23.44 degrees (0.409 rad)
    const tilt_cos = 0.9174;
    const tilt_sin = 0.3979;
    const p_tilt_y = p.y * tilt_cos - p.z * tilt_sin;
    const p_tilt_z = p.y * tilt_sin + p.z * tilt_cos;
    const p_tilt_x = p.x;

    const lat = std.math.asin(std.math.clamp(p_tilt_y, -1.0, 1.0));
    var lon = std.math.atan2(p_tilt_z, p_tilt_x) + earth_rot;
    var lon_c = std.math.atan2(p_tilt_z, p_tilt_x) + cloud_rot;

    const two_pi = 2.0 * std.math.pi;
    lon = lon - two_pi * @floor(lon / two_pi);
    lon_c = lon_c - two_pi * @floor(lon_c / two_pi);

    const u_surf = (lon / two_pi) * @as(f32, @floatFromInt(TEXTURE_W));
    const u_c = (lon_c / two_pi) * @as(f32, @floatFromInt(TEXTURE_W));
    const v = (0.5 - lat / std.math.pi) * @as(f32, @floatFromInt(TEXTURE_H - 1));

    const px: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(u_surf)), 0, @as(i32, @intCast(TEXTURE_W - 1))));
    const px_c: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(u_c)), 0, @as(i32, @intCast(TEXTURE_W - 1))));
    const py: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(v)), 0, @as(i32, @intCast(TEXTURE_H - 1))));

    if (!textures_loaded) {
        // Fallback procedural land/sea
        const n = @sin(lat * 8.0) * @cos(lon * 8.0);
        const is_w = (n < 0.1);
        return .{
            .day_r = if (is_w) 15.0 else 55.0,
            .day_g = if (is_w) 45.0 else 115.0,
            .day_b = if (is_w) 85.0 else 45.0,
            .night_r = if (!is_w) 60.0 else 0.0,
            .night_g = if (!is_w) 50.0 else 0.0,
            .night_b = if (!is_w) 30.0 else 0.0,
            .cloud = 0.25,
            .is_water = is_w,
        };
    }

    const surf_idx = py * TEXTURE_W + px;
    const day_offset = surf_idx * 3;
    const night_offset = DAY_SIZE + surf_idx * 3;
    const cloud_offset = DAY_SIZE + NIGHT_SIZE + (py * TEXTURE_W + px_c);

    const dr: f32 = @floatFromInt(texture_data[day_offset]);
    const dg: f32 = @floatFromInt(texture_data[day_offset + 1]);
    const db: f32 = @floatFromInt(texture_data[day_offset + 2]);

    const nr: f32 = @floatFromInt(texture_data[night_offset]);
    const ng: f32 = @floatFromInt(texture_data[night_offset + 1]);
    const nb: f32 = @floatFromInt(texture_data[night_offset + 2]);

    const c_val: f32 = @as(f32, @floatFromInt(texture_data[cloud_offset])) / 255.0;
    const is_water = (dr < 40.0 and db > dr * 0.9);

    return .{
        .day_r = dr, .day_g = dg, .day_b = db,
        .night_r = nr, .night_g = ng, .night_b = nb,
        .cloud = c_val,
        .is_water = is_water,
    };
}

const EarthRowPayload = struct {
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    time: f32,
    cam_dist: f32,
    cam_lat: f32,
    cam_lon: f32,
};

fn renderEarthRows(p: EarthRowPayload) void {
    const sun_dir = Vec3.init(1.1, 0.35, 0.85).normalize();
    const aspect = @as(f32, @floatFromInt(p.w)) / @as(f32, @floatFromInt(p.h));
    const fov_scale: f32 = 0.85;

    const cy = @sin(p.cam_lat);
    const c_rad = @cos(p.cam_lat);
    const ro = Vec3.init(
        p.cam_dist * c_rad * @sin(p.cam_lon),
        p.cam_dist * cy,
        p.cam_dist * c_rad * @cos(p.cam_lon),
    );
    const target = Vec3.init(0.0, 0.0, 0.0);
    const forward = target.sub(ro).normalize();
    const world_up = Vec3.init(0.0, 1.0, 0.0);
    const right = forward.cross(world_up).normalize();
    const up = right.cross(forward).normalize();

    const earth_rot = p.time * 0.12;
    const cloud_rot = earth_rot + p.time * 0.018;

    var y = p.start_y;
    while (y < p.end_y) : (y += 1) {
        const ndc_y = (1.0 - 2.0 * (@as(f32, @floatFromInt(y)) + 0.5) / @as(f32, @floatFromInt(p.h))) * fov_scale;

        var x: usize = 0;
        while (x < p.w) : (x += 1) {
            const ndc_x = (2.0 * (@as(f32, @floatFromInt(x)) + 0.5) / @as(f32, @floatFromInt(p.w)) - 1.0) * aspect * fov_scale;
            const rd = forward.add(right.scale(ndc_x)).add(up.scale(ndc_y)).normalize();

            // Analytical sphere intersection
            const b = ro.dot(rd);
            const c = ro.dot(ro) - 1.0;
            const disc = b * b - c;

            var out_r: f32 = 0.0;
            var out_g: f32 = 0.0;
            var out_b: f32 = 0.0;

            if (disc > 0.0) {
                const t = -b - @sqrt(disc);
                if (t > 0.0) {
                    const hit = ro.add(rd.scale(t));
                    const norm = hit.normalize();

                    const n_dot_l = norm.dot(sun_dir);

                    // Day-night blending with smooth twilight terminator
                    const day_factor = std.math.clamp((n_dot_l + 0.10) / 0.25, 0.0, 1.0);
                    const night_factor = (1.0 - day_factor);

                    // Sunset/Sunrise golden red terminator glow
                    const twilight = @max(0.0, 1.0 - @abs(n_dot_l - 0.05) * 8.0);

                    // Sample photographic NASA Blue Marble & Black Marble data
                    const s = sampleNasaEarth(norm, earth_rot, cloud_rot);

                    // Ocean sunglint (Blinn-Phong specular)
                    const half_v = sun_dir.sub(rd).normalize();
                    const n_dot_h = @max(0.0, norm.dot(half_v));
                    const sunglint = if (s.is_water and day_factor > 0.0) std.math.pow(f32, n_dot_h, 48.0) * 235.0 * day_factor else 0.0;

                    // Cloud shadow projection onto surface
                    const shadow_p = norm.add(sun_dir.scale(0.022)).normalize();
                    const s_shadow = sampleNasaEarth(shadow_p, earth_rot, cloud_rot);
                    const shadow_mult = 1.0 - 0.65 * s_shadow.cloud;

                    // Light up daytime surface with twilight modulation
                    const day_light = @max(0.0, n_dot_l) * shadow_mult;
                    const sunset_r = twilight * 65.0;
                    const sunset_g = twilight * 25.0;

                    var cr = s.day_r * day_light * day_factor + s.night_r * night_factor * 1.6 + sunglint + sunset_r;
                    var cg = s.day_g * day_light * day_factor + s.night_g * night_factor * 1.6 + sunglint + sunset_g;
                    var cb = s.day_b * day_light * day_factor + s.night_b * night_factor * 1.6 + sunglint;

                    // Blend clouds with realistic illumination
                    if (s.cloud > 0.02) {
                        const cloud_diff = @max(0.04, n_dot_l);
                        const c_light = 245.0 * (cloud_diff * day_factor + 0.03 * night_factor);
                        const alpha = std.math.clamp(s.cloud * 1.25, 0.0, 1.0);
                        cr = cr * (1.0 - alpha) + (c_light + sunset_r * 0.5) * alpha;
                        cg = cg * (1.0 - alpha) + (c_light + sunset_g * 0.5) * alpha;
                        cb = cb * (1.0 - alpha) + c_light * alpha;
                    }

                    // Atmospheric limb Fresnel glow (Rayleigh scattering)
                    const fresnel = std.math.pow(f32, 1.0 - @max(0.0, -rd.dot(norm)), 3.8) * 0.70;
                    const atm_illum = (0.2 + 0.8 * day_factor);
                    cr = cr * (1.0 - fresnel) + 75.0 * fresnel * atm_illum;
                    cg = cg * (1.0 - fresnel) + 155.0 * fresnel * atm_illum;
                    cb = cb * (1.0 - fresnel) + 255.0 * fresnel * atm_illum;

                    out_r = @min(255.0, cr);
                    out_g = @min(255.0, cg);
                    out_b = @min(255.0, cb);
                }
            } else {
                // Outer atmosphere halo
                const c_halo = ro.dot(ro) - 1.0816; // R = 1.04
                const disc_halo = b * b - c_halo;
                if (disc_halo > 0.0) {
                    const halo_dist = @sqrt(@max(0.0, -disc));
                    const halo_intensity = std.math.clamp((0.14 - halo_dist) * 7.5, 0.0, 1.0);
                    out_r = 25.0 * halo_intensity;
                    out_g = 75.0 * halo_intensity;
                    out_b = 210.0 * halo_intensity;
                } else {
                    // Deep space starfield
                    const star = @sin(rd.x * 125.0) * @cos(rd.y * 125.0 + rd.z * 125.0);
                    if (star > 0.986) {
                        const s_lum = (star - 0.986) * 70.0 * 255.0;
                        out_r = @min(230.0, s_lum);
                        out_g = @min(230.0, s_lum);
                        out_b = @min(255.0, s_lum);
                    }
                }
            }

            const out_idx = y * p.w + x;
            if (out_idx < p.buf.data.len) {
                const r32: u32 = @intFromFloat(@min(255.0, @max(0.0, out_r)));
                const g32: u32 = @intFromFloat(@min(255.0, @max(0.0, out_g)));
                const b32: u32 = @intFromFloat(@min(255.0, @max(0.0, out_b)));
                const dst_words: [*]u32 = @ptrCast(@alignCast(p.buf.data.ptr));
                dst_words[out_idx] = b32 | (g32 << 8) | (r32 << 16) | 0xff000000;
            }
        }
    }
}

fn earthRowTaskWrapper(ctx: ?*anyopaque) void {
    const p: *EarthRowPayload = @ptrCast(@alignCast(ctx.?));
    renderEarthRows(p.*);
}

pub fn render_3d_earth(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    time_dyn: Dynamic,
    dist_dyn: ?Dynamic,
    lat_dyn: ?Dynamic,
    lon_dyn: ?Dynamic,
) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    _ = loadTextures();

    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 80;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 40;
    const t: f32 = switch (time_dyn.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.0,
    };

    const cam_dist: f32 = if (dist_dyn) |d| (switch (d.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 2.6,
    }) else 2.6;

    const cam_lat: f32 = if (lat_dyn) |p_lat| (switch (p_lat.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.25,
    }) else 0.25;

    const cam_lon: f32 = if (lon_dyn) |p_lon| (switch (p_lon.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => t * 0.15,
    }) else t * 0.15;

    // ── CUDA GPU Fast Path ──────────────────────────────────────────────────
    // When CUDA backend is active, launch hardware kernel on NVIDIA GPU.
    // nvidia-smi will show active GPU utilization during this call.
    driver.initGpuDriver(null);
    if (driver.active_backend == .cuda) {
        const launched = earth_cuda.launchCudaEarth(
            buf,
            @intCast(w), @intCast(h),
            t, cam_dist, cam_lat, cam_lon,
        );
        if (launched) return Dynamic.initNone();
    }

    // ── CPU Multicore Fallback ──────────────────────────────────────────────
    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;
    const num_threads = @min(h, @max(1, num_workers));

    var payloads: [pool.MAX_WORKERS]EarthRowPayload = undefined;
    var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
    var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

    const rows_per_thread = (h + num_threads - 1) / num_threads;
    var start_y: usize = 0;
    var count: usize = 0;

    for (0..num_threads) |i| {
        if (start_y >= h) break;
        const end_y = @min(h, start_y + rows_per_thread);

        payloads[i] = EarthRowPayload{
            .buf = buf,
            .w = w,
            .h = h,
            .start_y = start_y,
            .end_y = end_y,
            .time = t,
            .cam_dist = cam_dist,
            .cam_lat = cam_lat,
            .cam_lon = cam_lon,
        };
        funcs[i] = earthRowTaskWrapper;
        args_ptr[i] = &payloads[i];
        count += 1;
        start_y = end_y;
    }

    global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    buf.toDevice();

    return Dynamic.initNone();
}
