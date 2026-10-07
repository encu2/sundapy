const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

pub const x11 = @import("screen_x11.zig");
pub const x11_types = @import("screen_x11_types.zig");
pub const input = @import("screen_input.zig");
pub const metrics = @import("screen_metrics.zig");
pub const ansi = @import("screen_ansi.zig");

pub const name = Dynamic.initStr("screenGUI");

// ============================================================================
// Internal State
// ============================================================================

pub var screen_width: usize = 80;
pub var screen_height: usize = 40;
pub var screen_title: [128]u8 = undefined;
pub var screen_title_len: usize = 0;
pub var is_initialized: bool = false;
pub var is_running: bool = true;

// Re-export metrics & profiling APIs
pub const record_render_time = metrics.record_render_time;
pub const sleep_until_next_frame = metrics.sleep_until_next_frame;
pub const get_render_time_ms = metrics.get_render_time_ms;
pub const get_show_time_ms = metrics.get_show_time_ms;
pub const get_fps = metrics.get_fps;
pub const get_cpu_usage = metrics.get_cpu_usage;
pub const get_gpu_usage = metrics.get_gpu_usage;
pub const get_memory_usage = metrics.get_memory_usage;
pub const get_frame_count = metrics.get_frame_count;
pub const get_benchmark_summary = metrics.get_benchmark_summary;

// Re-export input APIs
pub const clear_registered_keys = input.clear_registered_keys;
pub const register_key = input.register_key;
pub const is_action_pressed = input.is_action_pressed;
pub const get_actions = input.get_actions;
pub const is_key_pressed = input.is_key_pressed;
pub const get_pressed_keys = input.get_pressed_keys;
pub const get_input = input.get_input;

// ============================================================================
// Module Lifecycle & Buffer Rendering
// ============================================================================

pub fn init(width_dyn: Dynamic, height_dyn: Dynamic, title_dyn: Dynamic) anyerror!Dynamic {
    if (width_dyn.value == .i64_type) {
        screen_width = @intCast(@max(10, width_dyn.value.i64_type));
    }
    if (height_dyn.value == .i64_type) {
        screen_height = @intCast(@max(10, height_dyn.value.i64_type));
    }
    if (title_dyn.value == .str_type) {
        const t = title_dyn.value.str_type;
        const copy_len = @min(t.len, screen_title.len - 1);
        @memcpy(screen_title[0..copy_len], t[0..copy_len]);
        screen_title[copy_len] = 0;
        screen_title_len = copy_len;
    } else {
        const def_title = "SundaPy screenGUI";
        @memcpy(screen_title[0..def_title.len], def_title);
        screen_title_len = def_title.len;
    }

    metrics.frame_counter = 0;
    metrics.start_timestamp_ns = metrics.readTimeNs();
    metrics.last_frame_timestamp_ns = metrics.start_timestamp_ns;
    is_initialized = true;
    is_running = true;

    input.enableRawTerminal();

    _ = x11.initX11Window(screen_width, screen_height, screen_title[0..screen_title_len]);

    if (!x11_types.x11_connected) {
        const init_seq = "\x1b[?1049h\x1b[2J\x1b[H\x1b[?25l";
        _ = std.os.linux.write(1, init_seq, init_seq.len);
    } else {
        _ = std.os.linux.write(1, "\x1b[?25l", 6);
    }

    _ = metrics.updateCpuStats();
    return Dynamic.initBool(true);
}

pub fn render_buffer(buf_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    const t_start = metrics.readTimeNs();

    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var w: usize = screen_width;
    var h: usize = screen_height;
    if (w_dyn.value == .i64_type) w = @intCast(@max(1, w_dyn.value.i64_type));
    if (h_dyn.value == .i64_type) h = @intCast(@max(1, h_dyn.value.i64_type));

    buf.toHost();

    if (x11_types.x11_connected) {
        x11.renderX11Buffer(buf, w, h, &is_running);
        const t_end = metrics.readTimeNs();
        metrics.last_show_time_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1e6;
        metrics.total_show_time_ms += metrics.last_show_time_ms;
        metrics.frame_counter += 1;

        if (metrics.frame_counter % 12 == 0) {
            const cpu_pct = metrics.updateCpuStats();
            const mem_stats = metrics.readMemoryStats();
            const gpu_pct = metrics.getGpuUsagePct();

            const mode_tag: []const u8 = if (x11_types.x11_shm_active) "SHM" else "Socket";
            var hud_buf: [256]u8 = undefined;
            const hud_line = std.fmt.bufPrint(
                &hud_buf,
                "\r\x1b[K\x1b[1;36m[SundaPy GUI ({s}): {d}x{d}]\x1b[0m Frame: \x1b[1;33m{d:5}\x1b[0m | FPS: \x1b[1;32m{d:5.1}\x1b[0m | Render: \x1b[1;35m{d:4.2}ms\x1b[0m | Show: \x1b[1;35m{d:4.2}ms\x1b[0m | GPU: \x1b[1;32m{d:4.1}%\x1b[0m | CPU: \x1b[1;34m{d:4.1}%\x1b[0m | RAM: \x1b[1;37m{d:5.1}MB\x1b[0m",
                .{ mode_tag, x11_types.x11_win_w, x11_types.x11_win_h, metrics.frame_counter, metrics.last_fps, metrics.last_render_time_ms, metrics.last_show_time_ms, gpu_pct, cpu_pct, mem_stats[0] },
            ) catch "";
            _ = std.os.linux.write(1, hud_line.ptr, hud_line.len);
        }
        return Dynamic.initNone();
    } else {
        ansi.renderAnsiBuffer(buf, w, h);
        const t_end = metrics.readTimeNs();
        metrics.last_show_time_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1e6;
        metrics.total_show_time_ms += metrics.last_show_time_ms;
        metrics.frame_counter += 1;
        return Dynamic.initNone();
    }
}

pub fn poll_events() anyerror!Dynamic {
    if (x11_types.x11_connected and x11_types.x11_fd >= 0) {
        var ev_buf: [64]u8 = undefined;
        while (true) {
            const ev_rc = @as(isize, @bitCast(std.os.linux.recvfrom(x11_types.x11_fd, &ev_buf, 32, std.os.linux.MSG.DONTWAIT, null, null)));
            if (ev_rc < 32) break;
            x11.processX11Event(ev_buf[0..32], &is_running);
        }
    }
    input.pollTerminalInput(&is_running);
    return Dynamic.initBool(is_running);
}

pub fn close() anyerror!Dynamic {
    is_running = false;
    input.restoreTerminal();
    if (x11_types.x11_connected) {
        x11.closeX11Window();
        _ = std.os.linux.write(1, "\x1b[?25h\r\x1b[K\n", 9);
    } else {
        const exit_seq = "\x1b[0m\x1b[?25h\x1b[?1049l\n";
        _ = std.os.linux.write(1, exit_seq, exit_seq.len);
    }
    return Dynamic.initNone();
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "init")) return @import("datatype/dynamic.zig").toDynamicFunc(init);
    if (std.mem.eql(u8, attr, "render_buffer")) return @import("datatype/dynamic.zig").toDynamicFunc(render_buffer);
    if (std.mem.eql(u8, attr, "record_render_time")) return @import("datatype/dynamic.zig").toDynamicFunc(record_render_time);
    if (std.mem.eql(u8, attr, "sleep_until_next_frame")) return @import("datatype/dynamic.zig").toDynamicFunc(sleep_until_next_frame);
    if (std.mem.eql(u8, attr, "poll_events")) return @import("datatype/dynamic.zig").toDynamicFunc(poll_events);
    if (std.mem.eql(u8, attr, "is_key_pressed")) return @import("datatype/dynamic.zig").toDynamicFunc(is_key_pressed);
    if (std.mem.eql(u8, attr, "is_key_down")) return @import("datatype/dynamic.zig").toDynamicFunc(is_key_pressed);
    if (std.mem.eql(u8, attr, "get_pressed_keys")) return @import("datatype/dynamic.zig").toDynamicFunc(get_pressed_keys);
    if (std.mem.eql(u8, attr, "register_key")) return @import("datatype/dynamic.zig").toDynamicFunc(register_key);
    if (std.mem.eql(u8, attr, "register_action")) return @import("datatype/dynamic.zig").toDynamicFunc(register_key);
    if (std.mem.eql(u8, attr, "clear_registered_keys")) return @import("datatype/dynamic.zig").toDynamicFunc(clear_registered_keys);
    if (std.mem.eql(u8, attr, "clear_keys")) return @import("datatype/dynamic.zig").toDynamicFunc(clear_registered_keys);
    if (std.mem.eql(u8, attr, "is_action_pressed")) return @import("datatype/dynamic.zig").toDynamicFunc(is_action_pressed);
    if (std.mem.eql(u8, attr, "get_actions")) return @import("datatype/dynamic.zig").toDynamicFunc(get_actions);
    if (std.mem.eql(u8, attr, "get_input")) return @import("datatype/dynamic.zig").toDynamicFunc(get_input);
    if (std.mem.eql(u8, attr, "close")) return @import("datatype/dynamic.zig").toDynamicFunc(close);
    if (std.mem.eql(u8, attr, "get_render_time_ms")) return @import("datatype/dynamic.zig").toDynamicFunc(get_render_time_ms);
    if (std.mem.eql(u8, attr, "get_show_time_ms")) return @import("datatype/dynamic.zig").toDynamicFunc(get_show_time_ms);
    if (std.mem.eql(u8, attr, "get_fps")) return @import("datatype/dynamic.zig").toDynamicFunc(get_fps);
    if (std.mem.eql(u8, attr, "get_cpu_usage")) return @import("datatype/dynamic.zig").toDynamicFunc(get_cpu_usage);
    if (std.mem.eql(u8, attr, "get_gpu_usage")) return @import("datatype/dynamic.zig").toDynamicFunc(get_gpu_usage);
    if (std.mem.eql(u8, attr, "get_memory_usage")) return @import("datatype/dynamic.zig").toDynamicFunc(get_memory_usage);
    if (std.mem.eql(u8, attr, "get_frame_count")) return @import("datatype/dynamic.zig").toDynamicFunc(get_frame_count);
    if (std.mem.eql(u8, attr, "get_benchmark_summary")) return @import("datatype/dynamic.zig").toDynamicFunc(get_benchmark_summary);
    return error.AttributeError;
}
