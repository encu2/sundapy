const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const input = @import("screen_input.zig");
pub const types = @import("screen_x11_types.zig");
pub const init_mod = @import("screen_x11_init.zig");

// Re-export state variables & constants
pub const IPC_PRIVATE = types.IPC_PRIVATE;
pub const IPC_CREAT = types.IPC_CREAT;
pub const IPC_RMID = types.IPC_RMID;

pub var x11_fd = &types.x11_fd;
pub var x11_connected = &types.x11_connected;
pub var x11_win_id = &types.x11_win_id;
pub var x11_gc_id = &types.x11_gc_id;
pub var x11_win_w = &types.x11_win_w;
pub var x11_win_h = &types.x11_win_h;
pub var x11_scale = &types.x11_scale;
pub var x11_img_buf = &types.x11_img_buf;
pub var x11_heap_buf = &types.x11_heap_buf;
pub var x11_shm_supported = &types.x11_shm_supported;
pub var x11_shm_active = &types.x11_shm_active;
pub var x11_shm_opcode = &types.x11_shm_opcode;
pub var x11_shmseg_id = &types.x11_shmseg_id;
pub var x11_shm_id = &types.x11_shm_id;
pub var x11_shm_addr = &types.x11_shm_addr;
pub var wm_protocols = &types.wm_protocols;
pub var wm_delete_window = &types.wm_delete_window;

pub const initX11Window = init_mod.initX11Window;
pub const readXauthCookie = types.readXauthCookie;
pub const readFull = types.readFull;
pub const internAtom = types.internAtom;

pub fn setInputFocus() void {
    if (!types.x11_connected or types.x11_fd < 0) return;
    var focus_buf: [12]u8 = undefined;
    focus_buf[0] = 42;
    focus_buf[1] = 1;
    std.mem.writeInt(u16, focus_buf[2..4], 3, .little);
    std.mem.writeInt(u32, focus_buf[4..8], types.x11_win_id, .little);
    std.mem.writeInt(u32, focus_buf[8..12], 0, .little);
    _ = std.os.linux.write(types.x11_fd, &focus_buf, 12);
}

pub fn processX11Event(ev_buf: *const [32]u8, is_running_ptr: *bool) void {
    const ev_code = ev_buf[0] & 0x7f;
    if (ev_code == 33) {
        const msg_type = std.mem.readInt(u32, ev_buf[8..12], .little);
        const data0 = std.mem.readInt(u32, ev_buf[16..20], .little);
        if (msg_type == types.wm_protocols and data0 == types.wm_delete_window) {
            is_running_ptr.* = false;
        }
    } else if (ev_code == 2) {
        const keycode = ev_buf[1];
        input.key_states[keycode] = true;
    } else if (ev_code == 3) {
        const keycode = ev_buf[1];
        input.key_states[keycode] = false;
    } else if (ev_code == 4) {
        setInputFocus();
    }
}

pub fn renderX11Buffer(buf: *GpuBuffer, w: usize, h: usize, is_running_ptr: *bool) void {
    if (!types.x11_connected or types.x11_img_buf == null or types.x11_fd < 0) return;
    const dest = types.x11_img_buf.?;
    const scale = types.x11_scale;
    const win_w = types.x11_win_w;
    const win_h = types.x11_win_h;

    const dst32: [*]u32 = @ptrCast(@alignCast(dest.ptr));
    const src32: [*]const u32 = @ptrCast(@alignCast(buf.data.ptr));

    var is_float_rgb = (buf.data.len >= w * h * 3);
    if (is_float_rgb) {
        var sample_idx: usize = 0;
        while (sample_idx < @min(buf.data.len, 16)) : (sample_idx += 1) {
            if (src32[sample_idx] != 0) {
                if (((src32[sample_idx] >> 24) & 0xFF) == 0xFF) {
                    is_float_rgb = false;
                }
                break;
            }
        }
    }

    if (scale == 1 and w == win_w and h == win_h) {
        if (!is_float_rgb) {
            const total_bytes = @as(usize, win_w) * win_h * 4;
            const max_bytes = @min(total_bytes, buf.data.len * 4);
            @memcpy(dest[0..max_bytes], @as([*]const u8, @ptrCast(src32))[0..max_bytes]);
        } else {
            const total_pixels = @min(w * h, buf.data.len / 3);
            for (0..total_pixels) |i| {
                const r: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[i * 3])));
                const g: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[i * 3 + 1])));
                const b: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[i * 3 + 2])));
                dst32[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
            }
        }
    } else {
        for (0..h) |sy| {
            const sy_scaled = sy * scale;
            for (0..w) |sx| {
                var pixel_val: u32 = 0xFF000000;
                if (is_float_rgb) {
                    const src_idx = (sy * w + sx) * 3;
                    if (src_idx + 2 < buf.data.len) {
                        const r: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[src_idx])));
                        const g: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[src_idx + 1])));
                        const b: u32 = @intFromFloat(@min(255.0, @max(0.0, buf.data[src_idx + 2])));
                        pixel_val = 0xFF000000 | (r << 16) | (g << 8) | b;
                    }
                } else {
                    const src_idx = sy * w + sx;
                    if (src_idx < buf.data.len) {
                        pixel_val = src32[src_idx];
                    }
                }

                var dy: usize = 0;
                while (dy < scale) : (dy += 1) {
                    const py = sy_scaled + dy;
                    if (py >= win_h) break;
                    const row_offset = py * @as(usize, win_w);
                    var dx: usize = 0;
                    while (dx < scale) : (dx += 1) {
                        const px = sx * scale + dx;
                        if (px >= win_w) break;
                        dst32[row_offset + px] = pixel_val;
                    }
                }
            }
        }
    }

    if (types.x11_shm_active) {
        var shm_pi: [40]u8 = undefined;
        shm_pi[0] = types.x11_shm_opcode;
        shm_pi[1] = 3;
        std.mem.writeInt(u16, shm_pi[2..4], 10, .little);
        std.mem.writeInt(u32, shm_pi[4..8], types.x11_win_id, .little);
        std.mem.writeInt(u32, shm_pi[8..12], types.x11_gc_id, .little);
        std.mem.writeInt(u16, shm_pi[12..14], win_w, .little);
        std.mem.writeInt(u16, shm_pi[14..16], win_h, .little);
        std.mem.writeInt(u16, shm_pi[16..18], 0, .little);
        std.mem.writeInt(u16, shm_pi[18..20], 0, .little);
        std.mem.writeInt(u16, shm_pi[20..22], win_w, .little);
        std.mem.writeInt(u16, shm_pi[22..24], win_h, .little);
        std.mem.writeInt(u16, shm_pi[24..26], 0, .little);
        std.mem.writeInt(u16, shm_pi[26..28], 0, .little);
        shm_pi[28] = 24;
        shm_pi[29] = 2;
        shm_pi[30] = 0;
        shm_pi[31] = 0;
        std.mem.writeInt(u32, shm_pi[32..36], types.x11_shmseg_id, .little);
        std.mem.writeInt(u32, shm_pi[36..40], 0, .little);
        _ = std.os.linux.write(types.x11_fd, &shm_pi, 40);
    } else {
        const rows_per_chunk: u16 = 32;
        var y_start: u16 = 0;
        while (y_start < win_h) : (y_start += rows_per_chunk) {
            const chunk_h: u16 = @min(rows_per_chunk, win_h - y_start);
            const chunk_bytes: usize = @as(usize, win_w) * chunk_h * 4;
            const pi_hdr_len = 24;
            const total_pi_len: u16 = @intCast((pi_hdr_len + chunk_bytes) / 4);

            var pi_hdr: [24]u8 = undefined;
            pi_hdr[0] = 72;
            pi_hdr[1] = 2;
            std.mem.writeInt(u16, pi_hdr[2..4], total_pi_len, .little);
            std.mem.writeInt(u32, pi_hdr[4..8], types.x11_win_id, .little);
            std.mem.writeInt(u32, pi_hdr[8..12], types.x11_gc_id, .little);
            std.mem.writeInt(u16, pi_hdr[12..14], win_w, .little);
            std.mem.writeInt(u16, pi_hdr[14..16], chunk_h, .little);
            std.mem.writeInt(u16, pi_hdr[16..18], 0, .little);
            std.mem.writeInt(u16, pi_hdr[18..20], y_start, .little);
            pi_hdr[20] = 0;
            pi_hdr[21] = 24;
            pi_hdr[22] = 0;
            pi_hdr[23] = 0;

            _ = std.os.linux.write(types.x11_fd, &pi_hdr, 24);
            const data_offset = @as(usize, y_start) * win_w * 4;
            _ = std.os.linux.write(types.x11_fd, dest.ptr + data_offset, chunk_bytes);
        }
    }

    var ev_buf: [64]u8 = undefined;
    while (true) {
        const ev_rc = @as(isize, @bitCast(std.os.linux.recvfrom(types.x11_fd, &ev_buf, 32, std.os.linux.MSG.DONTWAIT, null, null)));
        if (ev_rc < 32) break;
        processX11Event(ev_buf[0..32], is_running_ptr);
    }
}

pub fn closeX11Window() void {
    input.restoreTerminal();
    if (types.x11_connected and types.x11_fd >= 0) {
        if (types.x11_shm_active) {
            var detach_buf: [8]u8 = undefined;
            detach_buf[0] = types.x11_shm_opcode;
            detach_buf[1] = 2;
            std.mem.writeInt(u16, detach_buf[2..4], 2, .little);
            std.mem.writeInt(u32, detach_buf[4..8], types.x11_shmseg_id, .little);
            _ = std.os.linux.write(types.x11_fd, &detach_buf, 8);
        }

        var destroy_buf: [8]u8 = undefined;
        destroy_buf[0] = 4;
        destroy_buf[1] = 0;
        std.mem.writeInt(u16, destroy_buf[2..4], 2, .little);
        std.mem.writeInt(u32, destroy_buf[4..8], types.x11_win_id, .little);
        _ = std.os.linux.write(types.x11_fd, &destroy_buf, 8);
        _ = std.os.linux.close(types.x11_fd);
        types.x11_fd = -1;
    }
    if (types.x11_shm_addr) |addr| {
        _ = types.shmdt(addr);
        types.x11_shm_addr = null;
    }
    if (types.x11_heap_buf) |b| {
        std.heap.c_allocator.free(b);
        types.x11_heap_buf = null;
    }
    types.x11_img_buf = null;
    types.x11_shm_active = false;
    types.x11_connected = false;
}
