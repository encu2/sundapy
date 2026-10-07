const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const pool = @import("gpu_pool.zig");

// ============================================================================
// 4D Clifford Torus Raymarching Accelerator (Persistent Worker Pool)
// ============================================================================

const RowPayload = struct {
    buf: *GpuBuffer,
    w: usize,
    h: usize,
    start_y: usize,
    end_y: usize,
    t: f32,
    cos1: f32, sin1: f32,
    cos2: f32, sin2: f32,
    cos3: f32, sin3: f32,
    cos4: f32, sin4: f32,
    R1: f32, R2: f32, r_tube_base: f32,
};

fn rowWorker(p: RowPayload) void {
    var py = p.start_y;
    while (py < p.end_y) : (py += 1) {
        const ndc_y = (2.0 * (@as(f32, @floatFromInt(py)) + 0.5) / @as(f32, @floatFromInt(p.h)) - 1.0);
        var px: usize = 0;
        while (px < p.w) : (px += 1) {
            const aspect = @as(f32, @floatFromInt(p.w)) / @as(f32, @floatFromInt(p.h));
            const ndc_x = (2.0 * (@as(f32, @floatFromInt(px)) + 0.5) / @as(f32, @floatFromInt(p.w)) - 1.0) * aspect;

            const ro_x: f32 = 0.0;
            const ro_y: f32 = 0.0;
            const ro_z: f32 = -3.2;
            const ro_w: f32 = 0.0;

            const rlen = @sqrt(ndc_x * ndc_x + ndc_y * ndc_y + 4.0);
            const rd_x: f32 = ndc_x / rlen;
            const rd_y: f32 = ndc_y / rlen;
            const rd_z: f32 = 2.0 / rlen;
            const rd_w: f32 = 0.0;

            var dist_traveled: f32 = 0.0;
            var hit: bool = false;
            var hit_x: f32 = 0.0;
            var hit_y: f32 = 0.0;
            var hit_z: f32 = 0.0;
            var hit_w: f32 = 0.0;
            var iter: usize = 0;

            while (iter < 28 and dist_traveled < 6.0) : (iter += 1) {
                const px_cur = ro_x + rd_x * dist_traveled;
                const py_cur = ro_y + rd_y * dist_traveled;
                const pz_cur = ro_z + rd_z * dist_traveled;
                const pw_cur = ro_w + rd_w * dist_traveled;

                const x1 = px_cur * p.cos1 - pw_cur * p.sin1;
                const w1 = px_cur * p.sin1 + pw_cur * p.cos1;

                const y1 = py_cur * p.cos2 - w1 * p.sin2;
                const w2 = py_cur * p.sin2 + w1 * p.cos2;

                const z1 = pz_cur * p.cos3 - w2 * p.sin3;
                const w3 = pz_cur * p.sin3 + w2 * p.cos3;

                const x2 = x1 * p.cos4 - z1 * p.sin4;
                const z2 = x1 * p.sin4 + z1 * p.cos4;

                const q1 = @sqrt(x2 * x2 + y1 * y1) - p.R1;
                const q2 = @sqrt(z2 * z2 + w3 * w3) - p.R2;
                const r_tube = p.r_tube_base + 0.08 * @cos(3.0 * std.math.atan2(y1, x2) + 2.5 * p.t);
                const d = @sqrt(q1 * q1 + q2 * q2) - r_tube;

                if (d < 0.006) {
                    hit = true;
                    hit_x = x2;
                    hit_y = y1;
                    hit_z = z2;
                    hit_w = w3;
                    break;
                }
                dist_traveled += @max(d * 0.75, 0.01);
            }

            const out_idx = (py * p.w + px) * 3;
            if (hit) {
                const nx = hit_x;
                const ny = hit_y;
                const nz = hit_z;
                const nlen = @sqrt(nx * nx + ny * ny + nz * nz + 0.001);
                const norm_x = nx / nlen;
                const norm_y = ny / nlen;
                const norm_z = nz / nlen;

                const lx: f32 = 0.577;
                const ly: f32 = 0.577;
                const lz: f32 = -0.577;
                const diff = @max(0.15, norm_x * lx + norm_y * ly + norm_z * lz);

                const hx = lx;
                const hy = ly;
                const hz = lz - 1.0;
                const hlen = @sqrt(hx * hx + hy * hy + hz * hz + 0.001);
                const spec = std.math.pow(f32, @max(0.0, (norm_x * hx + norm_y * hy + norm_z * hz) / hlen), 16.0);

                const hue = hit_w * 2.2 + p.t * 1.5;
                const cr = (0.5 + 0.5 * @sin(hue)) * diff * 220.0 + spec * 255.0;
                const cg = (0.5 + 0.5 * @sin(hue + 2.094)) * diff * 220.0 + spec * 255.0;
                const cb = (0.5 + 0.5 * @sin(hue + 4.188)) * diff * 220.0 + spec * 255.0;

                p.buf.data[out_idx] = @min(255.0, cr);
                p.buf.data[out_idx + 1] = @min(255.0, cg);
                p.buf.data[out_idx + 2] = @min(255.0, cb);
            } else {
                const bg_r: f32 = 10.0 + 6.0 * (1.0 - ndc_y);
                const bg_g: f32 = 12.0 + 8.0 * (1.0 - ndc_y);
                const bg_b: f32 = 28.0 + 20.0 * (1.0 - ndc_y);
                p.buf.data[out_idx] = bg_r;
                p.buf.data[out_idx + 1] = bg_g;
                p.buf.data[out_idx + 2] = bg_b;
            }
        }
    }
}

fn rowWorkerWrapper(ctx: ?*anyopaque) void {
    const p: *RowPayload = @ptrCast(@alignCast(ctx.?));
    rowWorker(p.*);
}

pub fn render_4d_object(buf_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic, time_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 80;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 40;
    const t: f32 = switch (time_dyn.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.0,
    };

    const a1 = t * 1.3;
    const a2 = t * 0.85;
    const a3 = t * 1.1;
    const a4 = t * 0.7;

    const cos1 = @cos(a1);
    const sin1 = @sin(a1);
    const cos2 = @cos(a2);
    const sin2 = @sin(a2);
    const cos3 = @cos(a3);
    const sin3 = @sin(a3);
    const cos4 = @cos(a4);
    const sin4 = @sin(a4);

    const R1 = 1.25 + 0.30 * @cos(1.8 * t);
    const R2 = 1.25 + 0.30 * @sin(1.4 * t);
    const r_tube_base: f32 = 0.28;

    const global_pool = pool.getGlobalPool();
    const num_workers = global_pool.num_workers;
    const num_threads = @min(h, @max(1, num_workers));

    if (num_threads <= 1) {
        rowWorker(RowPayload{
            .buf = buf, .w = w, .h = h, .start_y = 0, .end_y = h, .t = t,
            .cos1 = cos1, .sin1 = sin1, .cos2 = cos2, .sin2 = sin2,
            .cos3 = cos3, .sin3 = sin3, .cos4 = cos4, .sin4 = sin4,
            .R1 = R1, .R2 = R2, .r_tube_base = r_tube_base,
        });
    } else {
        var payloads: [pool.MAX_WORKERS]RowPayload = undefined;
        var funcs: [pool.MAX_WORKERS]pool.TaskFn = undefined;
        var args_ptr: [pool.MAX_WORKERS]?*anyopaque = undefined;

        const rows_per_thread = (h + num_threads - 1) / num_threads;
        var start_y: usize = 0;
        var count: usize = 0;

        for (0..num_threads) |i| {
            if (start_y >= h) break;
            const end_y = @min(h, start_y + rows_per_thread);

            payloads[i] = RowPayload{
                .buf = buf, .w = w, .h = h, .start_y = start_y, .end_y = end_y, .t = t,
                .cos1 = cos1, .sin1 = sin1, .cos2 = cos2, .sin2 = sin2,
                .cos3 = cos3, .sin3 = sin3, .cos4 = cos4, .sin4 = sin4,
                .R1 = R1, .R2 = R2, .r_tube_base = r_tube_base,
            };
            funcs[i] = rowWorkerWrapper;
            args_ptr[i] = &payloads[i];
            count += 1;
            start_y = end_y;
        }

        global_pool.dispatchBatch(count, funcs[0..count], args_ptr[0..count]);
    }

    buf.toDevice();
    return Dynamic.initNone();
}
