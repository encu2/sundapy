const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const metrics = @import("screen_metrics.zig");

// ============================================================================
// Screen GUI Terminal ANSI TrueColor 24-bit Renderer
// ============================================================================

pub var ansi_render_buf: [256 * 1024]u8 = undefined;

pub fn renderAnsiBuffer(buf: *GpuBuffer, w: usize, h: usize) void {
    var out_pos: usize = 0;
    const home_seq = "\x1b[H";
    @memcpy(ansi_render_buf[out_pos..][0..home_seq.len], home_seq);
    out_pos += home_seq.len;

    const effective_h = (h / 2) * 2;
    var y: usize = 0;
    while (y < effective_h) : (y += 2) {
        var x: usize = 0;
        while (x < w) : (x += 1) {
            const top_idx = (y * w + x) * 3;
            const bot_idx = ((y + 1) * w + x) * 3;

            var tr: u8 = 0;
            var tg: u8 = 0;
            var tb: u8 = 0;
            if (top_idx + 2 < buf.data.len) {
                tr = @intFromFloat(@max(0.0, @min(255.0, buf.data[top_idx])));
                tg = @intFromFloat(@max(0.0, @min(255.0, buf.data[top_idx + 1])));
                tb = @intFromFloat(@max(0.0, @min(255.0, buf.data[top_idx + 2])));
            }

            var br: u8 = 0;
            var bg: u8 = 0;
            var bb: u8 = 0;
            if (bot_idx + 2 < buf.data.len) {
                br = @intFromFloat(@max(0.0, @min(255.0, buf.data[bot_idx])));
                bg = @intFromFloat(@max(0.0, @min(255.0, buf.data[bot_idx + 1])));
                bb = @intFromFloat(@max(0.0, @min(255.0, buf.data[bot_idx + 2])));
            }

            const pixel_ansi = std.fmt.bufPrint(
                ansi_render_buf[out_pos..],
                "\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m▀",
                .{ tr, tg, tb, br, bg, bb },
            ) catch break;
            out_pos += pixel_ansi.len;
        }

        if (out_pos + 10 >= ansi_render_buf.len) break;
        ansi_render_buf[out_pos] = '\x1b';
        ansi_render_buf[out_pos + 1] = '[';
        ansi_render_buf[out_pos + 2] = '0';
        ansi_render_buf[out_pos + 3] = 'm';
        ansi_render_buf[out_pos + 4] = '\n';
        out_pos += 5;
    }

    const cpu_pct = metrics.updateCpuStats();
    const mem_stats = metrics.readMemoryStats();
    const gpu_pct = metrics.getGpuUsagePct();

    const hud_str = std.fmt.bufPrint(
        ansi_render_buf[out_pos..],
        "\x1b[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\x1b[0m\n" ++
            "\x1b[1;36m║\x1b[0m \x1b[1;33mSUNDAPY 4D GPU ENGINE\x1b[0m | \x1b[1;32mFPS: {d:5.1}\x1b[0m | Render: \x1b[1;35m{d:4.2}ms\x1b[0m | Show: \x1b[1;35m{d:4.2}ms\x1b[0m   \x1b[1;36m║\x1b[0m\n" ++
            "\x1b[1;36m║\x1b[0m \x1b[1;32mGPU: {d:4.1}%\x1b[0m | \x1b[1;34mCPU: {d:4.1}%\x1b[0m | \x1b[1;37mRAM: {d:5.1} MB (RSS)\x1b[0m | Frame: \x1b[1;33m{d:5}\x1b[0m              \x1b[1;36m║\x1b[0m\n" ++
            "\x1b[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\x1b[0m\n",
        .{
            metrics.last_fps,
            metrics.last_render_time_ms,
            metrics.last_show_time_ms,
            gpu_pct,
            cpu_pct,
            mem_stats[0],
            metrics.frame_counter,
        },
    ) catch "";
    out_pos += hud_str.len;

    _ = std.os.linux.write(1, &ansi_render_buf, out_pos);
}
