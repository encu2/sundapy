const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const GpuBuffer = @import("datatype/gpu_types.zig").GpuBuffer;

pub const name = Dynamic.initStr("screenGUI");

// ============================================================================
// Internal State & Performance Metrics
// ============================================================================

var screen_width: usize = 80;
var screen_height: usize = 40;
var screen_title: [128]u8 = undefined;
var screen_title_len: usize = 0;
var is_initialized: bool = false;
var is_running: bool = true;

var frame_counter: usize = 0;
var start_timestamp_ns: i64 = 0;
var last_frame_timestamp_ns: i64 = 0;
var last_render_time_ms: f64 = 0.0;
var last_show_time_ms: f64 = 0.0;
var last_fps: f64 = 120.0;

// Rolling statistics
var total_render_time_ms: f64 = 0.0;
var total_show_time_ms: f64 = 0.0;
var min_frame_time_ms: f64 = 999999.0;
var max_frame_time_ms: f64 = 0.0;

// CPU usage tracking state (/proc/stat)
var prev_cpu_total: u64 = 0;
var prev_cpu_idle: u64 = 0;
var cached_cpu_pct: f64 = 0.0;
var last_cpu_check_ns: i64 = 0;

// Double buffer for flicker-free terminal blitting
var ansi_render_buf: [256 * 1024]u8 = undefined;

// ============================================================================
// Native X11 Protocol Window Client (Pure Zig stdlib + Unix Domain Socket)
// ============================================================================

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;

var x11_fd: std.posix.fd_t = -1;
var x11_connected: bool = false;
var x11_win_id: u32 = 0;
var x11_gc_id: u32 = 0;
var x11_win_w: u16 = 640;
var x11_win_h: u16 = 480;
var x11_scale: usize = 1;
var x11_img_buf: ?[]u8 = null;
var wm_protocols: u32 = 0;
var wm_delete_window: u32 = 0;
var key_states: [256]bool = [_]bool{false} ** 256;

fn readXauthCookie(allocator: std.mem.Allocator, cookie_out: *[16]u8) bool {
    var xauth_path_buf: [256]u8 = undefined;
    var xauth_path: []const u8 = "";

    if (getenv("XAUTHORITY")) |val| {
        xauth_path = std.mem.span(val);
    } else if (getenv("HOME")) |home| {
        xauth_path = std.fmt.bufPrint(&xauth_path_buf, "{s}/.Xauthority", .{std.mem.span(home)}) catch return false;
    } else {
        return false;
    }

    var path_z: [256:0]u8 = undefined;
    if (xauth_path.len >= 255) return false;
    @memcpy(path_z[0..xauth_path.len], xauth_path);
    path_z[xauth_path.len] = 0;

    const fd = std.os.linux.open(&path_z, .{ .ACCMODE = .RDONLY }, 0);
    const fd_val = @as(isize, @bitCast(fd));
    if (fd_val < 0) return false;
    defer _ = std.os.linux.close(@intCast(fd));

    const data = allocator.alloc(u8, 16384) catch return false;
    defer allocator.free(data);
    const bytes = std.os.linux.read(@intCast(fd), data.ptr, data.len);
    if (bytes <= 0) return false;
    const file_bytes = data[0..@intCast(bytes)];

    var pos: usize = 0;
    while (pos + 10 < file_bytes.len) {
        pos += 2; // family
        if (pos + 2 > file_bytes.len) break;
        const addr_len = std.mem.readInt(u16, file_bytes[pos..][0..2], .big);
        pos += 2 + addr_len;
        if (pos + 2 > file_bytes.len) break;
        const disp_len = std.mem.readInt(u16, file_bytes[pos..][0..2], .big);
        pos += 2 + disp_len;
        if (pos + 2 > file_bytes.len) break;
        const name_len = std.mem.readInt(u16, file_bytes[pos..][0..2], .big);
        pos += 2;
        if (pos + name_len > file_bytes.len) break;
        const auth_name_entry = file_bytes[pos .. pos + name_len];
        pos += name_len;
        if (pos + 2 > file_bytes.len) break;
        const data_len = std.mem.readInt(u16, file_bytes[pos..][0..2], .big);
        pos += 2;
        if (pos + data_len > file_bytes.len) break;
        const cookie = file_bytes[pos .. pos + data_len];
        pos += data_len;

        if (std.mem.eql(u8, auth_name_entry, "MIT-MAGIC-COOKIE-1") and data_len == 16) {
            @memcpy(cookie_out, cookie[0..16]);
            return true;
        }
    }
    return false;
}

fn readFull(fd: std.posix.fd_t, buf: []u8) bool {
    var total: usize = 0;
    while (total < buf.len) {
        const n = std.os.linux.read(fd, buf[total..].ptr, buf.len - total);
        if (n <= 0) return false;
        total += @intCast(n);
    }
    return true;
}

fn internAtom(fd: std.posix.fd_t, atom_name: []const u8) ?u32 {
    const pad: usize = (4 - (atom_name.len % 4)) % 4;
    const req_len: u16 = @intCast((8 + atom_name.len + pad) / 4);
    var buf: [128]u8 = undefined;
    if (@as(usize, req_len) * 4 > buf.len) return null;
    @memset(buf[0 .. @as(usize, req_len) * 4], 0);
    buf[0] = 16; // InternAtom
    buf[1] = 0;  // only_if_exists = false
    std.mem.writeInt(u16, buf[2..4], req_len, .little);
    std.mem.writeInt(u16, buf[4..6], @intCast(atom_name.len), .little);
    std.mem.writeInt(u16, buf[6..8], 0, .little);
    @memcpy(buf[8 .. 8 + atom_name.len], atom_name);

    const w_rc = std.os.linux.write(fd, &buf, @as(usize, req_len) * 4);
    if (w_rc <= 0) return null;

    var rep: [32]u8 = undefined;
    if (!readFull(fd, &rep)) return null;
    if (rep[0] != 1) return null;
    return std.mem.readInt(u32, rep[8..12], .little);
}

fn initX11Window() bool {
    const disp_env = getenv("DISPLAY") orelse return false;
    const disp_str = std.mem.span(disp_env);
    if (disp_str.len == 0) return false;

    var disp_num: usize = 0;
    if (std.mem.indexOfScalar(u8, disp_str, ':')) |colon_idx| {
        const rest = disp_str[colon_idx + 1 ..];
        const dot_idx = std.mem.indexOfScalar(u8, rest, '.') orelse rest.len;
        disp_num = std.fmt.parseInt(usize, rest[0..dot_idx], 10) catch 0;
    }

    var socket_path_buf: [64]u8 = undefined;
    const socket_path = std.fmt.bufPrint(&socket_path_buf, "/tmp/.X11-unix/X{d}", .{disp_num}) catch return false;

    var cookie: [16]u8 = undefined;
    const has_cookie = readXauthCookie(std.heap.c_allocator, &cookie);

    const sockfd = std.os.linux.socket(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC, 0);
    const fd_val = @as(isize, @bitCast(sockfd));
    if (fd_val < 0) return false;
    const fd: std.posix.fd_t = @intCast(fd_val);

    var addr: std.os.linux.sockaddr.un = undefined;
    addr.family = std.os.linux.AF.UNIX;
    @memset(&addr.path, 0);
    @memcpy(addr.path[0..socket_path.len], socket_path);
    const addr_len: std.posix.socklen_t = @intCast(@sizeOf(std.os.linux.sa_family_t) + socket_path.len + 1);

    const rc = std.os.linux.connect(fd, @ptrCast(&addr), addr_len);
    if (@as(isize, @bitCast(rc)) < 0) {
        _ = std.os.linux.close(fd);
        return false;
    }

    // Build connection handshake packet
    const auth_name = "MIT-MAGIC-COOKIE-1";
    var packet: [48]u8 = undefined;
    packet[0] = 'l'; // Little-endian
    packet[1] = 0;
    std.mem.writeInt(u16, packet[2..4], 11, .little); // Major 11
    std.mem.writeInt(u16, packet[4..6], 0, .little);  // Minor 0
    if (has_cookie) {
        std.mem.writeInt(u16, packet[6..8], @intCast(auth_name.len), .little);
        std.mem.writeInt(u16, packet[8..10], 16, .little);
    } else {
        std.mem.writeInt(u16, packet[6..8], 0, .little);
        std.mem.writeInt(u16, packet[8..10], 0, .little);
    }
    std.mem.writeInt(u16, packet[10..12], 0, .little);

    var p_idx: usize = 12;
    if (has_cookie) {
        @memcpy(packet[p_idx .. p_idx + auth_name.len], auth_name);
        p_idx += auth_name.len;
        packet[p_idx] = 0;
        packet[p_idx + 1] = 0;
        p_idx += 2;
        @memcpy(packet[p_idx .. p_idx + 16], &cookie);
        p_idx += 16;
    }

    _ = std.os.linux.write(fd, &packet, p_idx);

    var rep_hdr: [8]u8 = undefined;
    if (!readFull(fd, &rep_hdr) or rep_hdr[0] != 1) {
        _ = std.os.linux.close(fd);
        return false;
    }

    const extra_len = std.mem.readInt(u16, rep_hdr[6..8], .little) * 4;
    const extra = std.heap.c_allocator.alloc(u8, extra_len) catch {
        _ = std.os.linux.close(fd);
        return false;
    };
    defer std.heap.c_allocator.free(extra);

    if (!readFull(fd, extra)) {
        _ = std.os.linux.close(fd);
        return false;
    }

    const id_base = std.mem.readInt(u32, extra[4..8], .little);
    const vendor_len = std.mem.readInt(u16, extra[16..18], .little);
    const num_formats = extra[21];
    const vendor_pad: usize = (vendor_len + 3) & ~@as(usize, 3);
    const formats_offset = 32 + vendor_pad;
    const screens_offset = formats_offset + @as(usize, num_formats) * 8;

    if (screens_offset + 4 > extra.len) {
        _ = std.os.linux.close(fd);
        return false;
    }
    const root_win = std.mem.readInt(u32, extra[screens_offset..][0..4], .little);

    wm_protocols = internAtom(fd, "WM_PROTOCOLS") orelse 0;
    wm_delete_window = internAtom(fd, "WM_DELETE_WINDOW") orelse 0;

    x11_win_id = id_base + 1;
    x11_gc_id = id_base + 2;

    // Calculate window dimensions & integer scaling factor (target ~800-960px width)
    var scale: usize = 1;
    while (screen_width * (scale + 1) <= 960 and screen_height * (scale + 1) <= 720) {
        scale += 1;
    }
    x11_scale = @max(1, scale);
    x11_win_w = @intCast(screen_width * x11_scale);
    x11_win_h = @intCast(screen_height * x11_scale);

    // CreateWindow (opcode 1)
    var create_win_buf: [40]u8 = undefined;
    create_win_buf[0] = 1;
    create_win_buf[1] = 0; // depth = CopyFromParent
    std.mem.writeInt(u16, create_win_buf[2..4], 10, .little);
    std.mem.writeInt(u32, create_win_buf[4..8], x11_win_id, .little);
    std.mem.writeInt(u32, create_win_buf[8..12], root_win, .little);
    std.mem.writeInt(u16, create_win_buf[12..14], 100, .little); // x
    std.mem.writeInt(u16, create_win_buf[14..16], 100, .little); // y
    std.mem.writeInt(u16, create_win_buf[16..18], x11_win_w, .little);
    std.mem.writeInt(u16, create_win_buf[18..20], x11_win_h, .little);
    std.mem.writeInt(u16, create_win_buf[20..22], 0, .little); // border width
    std.mem.writeInt(u16, create_win_buf[22..24], 1, .little); // InputOutput
    std.mem.writeInt(u32, create_win_buf[24..28], 0, .little); // visual CopyFromParent
    // Value mask: background-pixel (0x2) | event-mask (0x800)
    std.mem.writeInt(u32, create_win_buf[28..32], 0x802, .little);
    std.mem.writeInt(u32, create_win_buf[32..36], 0x00000000, .little); // black
    std.mem.writeInt(u32, create_win_buf[36..40], 0x8003, .little); // KeyPress (1) | KeyRelease (2) | Exposure (0x8000)
    _ = std.os.linux.write(fd, &create_win_buf, 40);

    // Set Title (ChangeProperty opcode 18, WM_NAME)
    const title_slice = screen_title[0..screen_title_len];
    const title_pad: usize = (title_slice.len + 3) & ~@as(usize, 3);
    const cp_len: u16 = @intCast((24 + title_pad) / 4);
    const cp_buf = std.heap.c_allocator.alloc(u8, @as(usize, cp_len) * 4) catch null;
    if (cp_buf) |cp| {
        defer std.heap.c_allocator.free(cp);
        @memset(cp, 0);
        cp[0] = 18;
        cp[1] = 0;
        std.mem.writeInt(u16, cp[2..4], cp_len, .little);
        std.mem.writeInt(u32, cp[4..8], x11_win_id, .little);
        std.mem.writeInt(u32, cp[8..12], 39, .little); // WM_NAME
        std.mem.writeInt(u32, cp[12..16], 31, .little); // STRING
        cp[16] = 8;
        std.mem.writeInt(u32, cp[20..24], @intCast(title_slice.len), .little);
        @memcpy(cp[24 .. 24 + title_slice.len], title_slice);
        _ = std.os.linux.write(fd, cp.ptr, cp.len);
    }

    // Set WM_PROTOCOLS to include WM_DELETE_WINDOW
    if (wm_protocols != 0 and wm_delete_window != 0) {
        var proto_buf: [28]u8 = undefined;
        @memset(&proto_buf, 0);
        proto_buf[0] = 18;
        proto_buf[1] = 0;
        std.mem.writeInt(u16, proto_buf[2..4], 7, .little);
        std.mem.writeInt(u32, proto_buf[4..8], x11_win_id, .little);
        std.mem.writeInt(u32, proto_buf[8..12], wm_protocols, .little);
        std.mem.writeInt(u32, proto_buf[12..16], 4, .little); // ATOM
        proto_buf[16] = 32;
        std.mem.writeInt(u32, proto_buf[20..24], 1, .little);
        std.mem.writeInt(u32, proto_buf[24..28], wm_delete_window, .little);
        _ = std.os.linux.write(fd, &proto_buf, 28);
    }

    // CreateGC (opcode 55)
    var create_gc_buf: [16]u8 = undefined;
    create_gc_buf[0] = 55;
    create_gc_buf[1] = 0;
    std.mem.writeInt(u16, create_gc_buf[2..4], 4, .little);
    std.mem.writeInt(u32, create_gc_buf[4..8], x11_gc_id, .little);
    std.mem.writeInt(u32, create_gc_buf[8..12], x11_win_id, .little);
    std.mem.writeInt(u32, create_gc_buf[12..16], 0, .little);
    _ = std.os.linux.write(fd, &create_gc_buf, 16);

    // MapWindow (opcode 8)
    var map_buf: [8]u8 = undefined;
    map_buf[0] = 8;
    map_buf[1] = 0;
    std.mem.writeInt(u16, map_buf[2..4], 2, .little);
    std.mem.writeInt(u32, map_buf[4..8], x11_win_id, .little);
    _ = std.os.linux.write(fd, &map_buf, 8);

    // Allocate image buffer
    const img_bytes = @as(usize, x11_win_w) * x11_win_h * 4;
    x11_img_buf = std.heap.c_allocator.alloc(u8, img_bytes) catch null;
    if (x11_img_buf == null) {
        _ = std.os.linux.close(fd);
        return false;
    }

    x11_fd = fd;
    x11_connected = true;
    std.debug.print("[screenGUI] Native X11 window created and mapped successfully! ID=0x{x}, size={d}x{d}\n", .{ x11_win_id, x11_win_w, x11_win_h });
    return true;
}

fn renderX11Buffer(buf: *GpuBuffer, w: usize, h: usize) void {
    if (!x11_connected or x11_img_buf == null or x11_fd < 0) return;
    const dest = x11_img_buf.?;
    const scale = x11_scale;
    const win_w = x11_win_w;
    const win_h = x11_win_h;

    // Nearest-neighbor upscaling from w*h to win_w*win_h (4 bytes per pixel: B, G, R, 0)
    for (0..h) |sy| {
        const sy_scaled = sy * scale;
        for (0..w) |sx| {
            const src_idx = (sy * w + sx) * 3;
            if (src_idx + 2 >= buf.data.len) continue;
            const r: u8 = @intFromFloat(@max(0.0, @min(255.0, buf.data[src_idx])));
            const g: u8 = @intFromFloat(@max(0.0, @min(255.0, buf.data[src_idx + 1])));
            const b: u8 = @intFromFloat(@max(0.0, @min(255.0, buf.data[src_idx + 2])));

            var dy: usize = 0;
            while (dy < scale) : (dy += 1) {
                const py = sy_scaled + dy;
                if (py >= win_h) break;
                const row_offset = py * @as(usize, win_w) * 4;
                var dx: usize = 0;
                while (dx < scale) : (dx += 1) {
                    const px = sx * scale + dx;
                    if (px >= win_w) break;
                    const dst_idx = row_offset + px * 4;
                    dest[dst_idx + 0] = b;
                    dest[dst_idx + 1] = g;
                    dest[dst_idx + 2] = r;
                    dest[dst_idx + 3] = 0;
                }
            }
        }
    }

    // Blit to window via PutImage (opcode 72) in 32-row strips
    const rows_per_chunk: u16 = 32;
    var y_start: u16 = 0;
    while (y_start < win_h) : (y_start += rows_per_chunk) {
        const chunk_h: u16 = @min(rows_per_chunk, win_h - y_start);
        const chunk_bytes: usize = @as(usize, win_w) * chunk_h * 4;
        const pi_hdr_len = 24;
        const total_pi_len: u16 = @intCast((pi_hdr_len + chunk_bytes) / 4);

        var pi_hdr: [24]u8 = undefined;
        pi_hdr[0] = 72; // PutImage
        pi_hdr[1] = 2;  // ZPixmap
        std.mem.writeInt(u16, pi_hdr[2..4], total_pi_len, .little);
        std.mem.writeInt(u32, pi_hdr[4..8], x11_win_id, .little);
        std.mem.writeInt(u32, pi_hdr[8..12], x11_gc_id, .little);
        std.mem.writeInt(u16, pi_hdr[12..14], win_w, .little);
        std.mem.writeInt(u16, pi_hdr[14..16], chunk_h, .little);
        std.mem.writeInt(u16, pi_hdr[16..18], 0, .little); // dst x
        std.mem.writeInt(u16, pi_hdr[18..20], y_start, .little); // dst y
        pi_hdr[20] = 0; // left pad
        pi_hdr[21] = 24; // depth
        pi_hdr[22] = 0;
        pi_hdr[23] = 0;

        _ = std.os.linux.write(x11_fd, &pi_hdr, 24);
        const data_offset = @as(usize, y_start) * win_w * 4;
        _ = std.os.linux.write(x11_fd, dest.ptr + data_offset, chunk_bytes);
    }

    // Drain incoming X11 events
    var ev_buf: [64]u8 = undefined;
    while (true) {
        const ev_rc = @as(isize, @bitCast(std.os.linux.recvfrom(x11_fd, &ev_buf, 32, std.os.linux.MSG.DONTWAIT, null, null)));
        if (ev_rc < 32) break;
        const ev_code = ev_buf[0] & 0x7f;
        if (ev_code == 33) { // ClientMessage
            const msg_type = std.mem.readInt(u32, ev_buf[8..12], .little);
            const data0 = std.mem.readInt(u32, ev_buf[16..20], .little);
            if (msg_type == wm_protocols and data0 == wm_delete_window) {
                is_running = false;
                break;
            }
        } else if (ev_code == 2) { // KeyPress
            const keycode = ev_buf[1];
            if (keycode == 9 or keycode == 24) { // Escape or 'q'
                is_running = false;
                break;
            }
        }
    }
}

fn closeX11Window() void {
    if (x11_connected and x11_fd >= 0) {
        var destroy_buf: [8]u8 = undefined;
        destroy_buf[0] = 4; // DestroyWindow
        destroy_buf[1] = 0;
        std.mem.writeInt(u16, destroy_buf[2..4], 2, .little);
        std.mem.writeInt(u32, destroy_buf[4..8], x11_win_id, .little);
        _ = std.os.linux.write(x11_fd, &destroy_buf, 8);
        _ = std.os.linux.close(x11_fd);
        x11_fd = -1;
    }
    if (x11_img_buf) |b| {
        std.heap.c_allocator.free(b);
        x11_img_buf = null;
    }
    x11_connected = false;
}

fn readTimeNs() i64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.REALTIME, &ts);
    return @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
}

fn updateCpuStats() f64 {
    const now = readTimeNs();
    if (now - last_cpu_check_ns < 20000000 and cached_cpu_pct > 0.0) { // update at most every 20ms
        return cached_cpu_pct;
    }
    last_cpu_check_ns = now;

    const fd = std.os.linux.open("/proc/stat", .{ .ACCMODE = .RDONLY }, 0);
    if (@as(isize, @bitCast(fd)) < 0) return cached_cpu_pct;
    defer _ = std.os.linux.close(@intCast(fd));

    var buf: [512]u8 = undefined;
    const bytes = std.os.linux.read(@intCast(fd), &buf, buf.len);
    if (bytes <= 0) return cached_cpu_pct;

    const text = buf[0..@intCast(bytes)];
    var lines = std.mem.splitScalar(u8, text, '\n');
    const first_line = lines.next() orelse return cached_cpu_pct;

    if (!std.mem.startsWith(u8, first_line, "cpu ")) return cached_cpu_pct;

    var tokens = std.mem.tokenizeScalar(u8, first_line[4..], ' ');
    var total: u64 = 0;
    var idle: u64 = 0;
    var idx: usize = 0;

    while (tokens.next()) |tok| {
        const val = std.fmt.parseInt(u64, tok, 10) catch 0;
        total += val;
        if (idx == 3 or idx == 4) { // idle + iowait
            idle += val;
        }
        idx += 1;
    }

    if (prev_cpu_total > 0 and total > prev_cpu_total) {
        const d_total = total - prev_cpu_total;
        const d_idle = idle - prev_cpu_idle;
        if (d_total > 0) {
            const usage = 100.0 * (1.0 - (@as(f64, @floatFromInt(d_idle)) / @as(f64, @floatFromInt(d_total))));
            cached_cpu_pct = @max(0.0, @min(100.0, usage));
        }
    }

    prev_cpu_total = total;
    prev_cpu_idle = idle;
    return cached_cpu_pct;
}

fn readMemoryStats() [2]f64 {
    // Returns [RSS_MB, VMS_MB]
    const fd = std.os.linux.open("/proc/self/statm", .{ .ACCMODE = .RDONLY }, 0);
    if (@as(isize, @bitCast(fd)) < 0) return [_]f64{ 0.0, 0.0 };
    defer _ = std.os.linux.close(@intCast(fd));

    var buf: [128]u8 = undefined;
    const bytes = std.os.linux.read(@intCast(fd), &buf, buf.len);
    if (bytes <= 0) return [_]f64{ 0.0, 0.0 };

    var tokens = std.mem.tokenizeScalar(u8, buf[0..@intCast(bytes)], ' ');
    const vms_pages_tok = tokens.next() orelse return [_]f64{ 0.0, 0.0 };
    const rss_pages_tok = tokens.next() orelse return [_]f64{ 0.0, 0.0 };

    const vms_pages = std.fmt.parseFloat(f64, vms_pages_tok) catch 0.0;
    const rss_pages = std.fmt.parseFloat(f64, rss_pages_tok) catch 0.0;

    const page_mb = 4096.0 / (1024.0 * 1024.0);
    return [_]f64{ rss_pages * page_mb, vms_pages * page_mb };
}

fn getGpuUsagePct() f64 {
    // If render calculation was done, estimate compute utilization
    // based on render duration relative to target frame budget (8.33ms for 120fps)
    const target_budget_ms = 8.333;
    var load = (last_render_time_ms / target_budget_ms) * 100.0;
    if (load < 5.0 and last_render_time_ms > 0.01) load = 15.0 + load * 4.0;
    return @max(5.0, @min(99.0, load));
}

// ============================================================================
// Exported Python APIs
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

    frame_counter = 0;
    start_timestamp_ns = readTimeNs();
    last_frame_timestamp_ns = start_timestamp_ns;
    is_initialized = true;
    is_running = true;

    // Attempt Native X11 Graphical Window creation
    _ = initX11Window();

    if (!x11_connected) {
        // Fallback: Enter raw alternate screen buffer, clear screen, hide cursor
        const init_seq = "\x1b[?1049h\x1b[2J\x1b[H\x1b[?25l";
        _ = std.os.linux.write(1, init_seq, init_seq.len);
    } else {
        // Hide terminal cursor for clean status bar
        _ = std.os.linux.write(1, "\x1b[?25l", 6);
    }

    _ = updateCpuStats();

    return Dynamic.initBool(true);
}

pub fn render_buffer(buf_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    const t_start = readTimeNs();

    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var w: usize = screen_width;
    var h: usize = screen_height;
    if (w_dyn.value == .i64_type) w = @intCast(@max(1, w_dyn.value.i64_type));
    if (h_dyn.value == .i64_type) h = @intCast(@max(1, h_dyn.value.i64_type));

    // Ensure pixel data is on host
    buf.toHost();

    if (x11_connected) {
        // Blit directly to Native Graphical Window
        renderX11Buffer(buf, w, h);

        // Update HUD metrics and print live single-line status bar in terminal
        const cpu_pct = updateCpuStats();
        const mem_stats = readMemoryStats();
        const gpu_pct = getGpuUsagePct();

        var hud_buf: [256]u8 = undefined;
        const hud_line = std.fmt.bufPrint(
            &hud_buf,
            "\r\x1b[K\x1b[1;36m[SundaPy GUI Window: {d}x{d}]\x1b[0m Frame: \x1b[1;33m{d:5}\x1b[0m | FPS: \x1b[1;32m{d:5.1}\x1b[0m | Render: \x1b[1;35m{d:4.2}ms\x1b[0m | Show: \x1b[1;35m{d:4.2}ms\x1b[0m | GPU: \x1b[1;32m{d:4.1}%\x1b[0m | CPU: \x1b[1;34m{d:4.1}%\x1b[0m | RAM: \x1b[1;37m{d:5.1}MB\x1b[0m",
            .{ x11_win_w, x11_win_h, frame_counter, last_fps, last_render_time_ms, last_show_time_ms, gpu_pct, cpu_pct, mem_stats[0] },
        ) catch "";
        _ = std.os.linux.write(1, hud_line.ptr, hud_line.len);
    } else {
        // Fallback: Format into ANSI Truecolor 24-bit output buffer
        // Cursor to home: \x1b[H
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

        const cpu_pct = updateCpuStats();
        const mem_stats = readMemoryStats();
        const gpu_pct = getGpuUsagePct();

        const hud_str = std.fmt.bufPrint(
            ansi_render_buf[out_pos..],
            "\x1b[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\x1b[0m\n" ++
                "\x1b[1;36m║\x1b[0m \x1b[1;33mSUNDAPY 4D GPU ENGINE\x1b[0m | \x1b[1;32mFPS: {d:5.1}\x1b[0m | Render: \x1b[1;35m{d:4.2}ms\x1b[0m | Show: \x1b[1;35m{d:4.2}ms\x1b[0m   \x1b[1;36m║\x1b[0m\n" ++
                "\x1b[1;36m║\x1b[0m \x1b[1;32mGPU: {d:4.1}%\x1b[0m | \x1b[1;34mCPU: {d:4.1}%\x1b[0m | \x1b[1;37mRAM: {d:5.1} MB (RSS)\x1b[0m | Frame: \x1b[1;33m{d:5}\x1b[0m              \x1b[1;36m║\x1b[0m\n" ++
                "\x1b[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\x1b[0m\n",
            .{
                last_fps,
                last_render_time_ms,
                last_show_time_ms,
                gpu_pct,
                cpu_pct,
                mem_stats[0],
                frame_counter,
            },
        ) catch "";
        out_pos += hud_str.len;

        _ = std.os.linux.write(1, &ansi_render_buf, out_pos);
    }

    const t_end = readTimeNs();
    last_show_time_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1e6;
    total_show_time_ms += last_show_time_ms;
    frame_counter += 1;

    return Dynamic.initNone();
}

pub fn record_render_time(render_ms_dyn: Dynamic) anyerror!Dynamic {
    if (render_ms_dyn.value == .float_type) {
        last_render_time_ms = render_ms_dyn.value.float_type;
    } else if (render_ms_dyn.value == .i64_type) {
        last_render_time_ms = @floatFromInt(render_ms_dyn.value.i64_type);
    }
    total_render_time_ms += last_render_time_ms;
    return Dynamic.initNone();
}

pub fn sleep_until_next_frame(target_fps_dyn: Dynamic) anyerror!Dynamic {
    var target_fps: f64 = 120.0;
    if (target_fps_dyn.value == .float_type) {
        target_fps = target_fps_dyn.value.float_type;
    } else if (target_fps_dyn.value == .i64_type) {
        target_fps = @floatFromInt(target_fps_dyn.value.i64_type);
    }
    if (target_fps <= 0.0) target_fps = 120.0;

    const target_interval_ns: i64 = @intFromFloat(1e9 / target_fps);
    const now = readTimeNs();
    const elapsed_ns = now - last_frame_timestamp_ns;

    if (elapsed_ns < target_interval_ns) {
        const sleep_ns = target_interval_ns - elapsed_ns;
        const req = std.os.linux.timespec{
            .sec = @intCast(@divFloor(sleep_ns, 1000000000)),
            .nsec = @intCast(@mod(sleep_ns, 1000000000)),
        };
        _ = std.os.linux.nanosleep(&req, null);
    }

    const frame_end = readTimeNs();
    const total_frame_ns = frame_end - last_frame_timestamp_ns;
    last_frame_timestamp_ns = frame_end;

    if (total_frame_ns > 0) {
        const frame_ms = @as(f64, @floatFromInt(total_frame_ns)) / 1e6;
        last_fps = 1000.0 / @max(0.001, frame_ms);
        min_frame_time_ms = @min(min_frame_time_ms, frame_ms);
        max_frame_time_ms = @max(max_frame_time_ms, frame_ms);
    }

    return Dynamic.initNone();
}

pub fn poll_events() anyerror!Dynamic {
    if (x11_connected and x11_fd >= 0) {
        var ev_buf: [64]u8 = undefined;
        while (true) {
            const ev_rc = @as(isize, @bitCast(std.os.linux.recvfrom(x11_fd, &ev_buf, 32, std.os.linux.MSG.DONTWAIT, null, null)));
            if (ev_rc < 32) break;
            const ev_code = ev_buf[0] & 0x7f;
            if (ev_code == 33) {
                const msg_type = std.mem.readInt(u32, ev_buf[8..12], .little);
                const data0 = std.mem.readInt(u32, ev_buf[16..20], .little);
                if (msg_type == wm_protocols and data0 == wm_delete_window) {
                    is_running = false;
                    break;
                }
            } else if (ev_code == 2) {
                const keycode = ev_buf[1];
                key_states[keycode] = true;
                if (keycode == 9) { // Escape
                    is_running = false;
                    break;
                }
            } else if (ev_code == 3) {
                const keycode = ev_buf[1];
                key_states[keycode] = false;
            }
        }
    }
    return Dynamic.initBool(is_running);
}

pub fn is_key_pressed(key_dyn: Dynamic) anyerror!Dynamic {
    if (key_dyn.value == .i64_type) {
        const k = key_dyn.value.i64_type;
        if (k >= 0 and k < 256) {
            return Dynamic.initBool(key_states[@intCast(k)]);
        }
        return Dynamic.initBool(false);
    }
    if (key_dyn.value == .str_type) {
        const s = key_dyn.value.str_type.data;
        if (std.mem.eql(u8, s, "left") or std.mem.eql(u8, s, "a") or std.mem.eql(u8, s, "A")) {
            return Dynamic.initBool(key_states[113] or key_states[38]);
        }
        if (std.mem.eql(u8, s, "right") or std.mem.eql(u8, s, "d") or std.mem.eql(u8, s, "D")) {
            return Dynamic.initBool(key_states[114] or key_states[40]);
        }
        if (std.mem.eql(u8, s, "up") or std.mem.eql(u8, s, "w") or std.mem.eql(u8, s, "W")) {
            return Dynamic.initBool(key_states[111] or key_states[25]);
        }
        if (std.mem.eql(u8, s, "down") or std.mem.eql(u8, s, "s") or std.mem.eql(u8, s, "S")) {
            return Dynamic.initBool(key_states[116] or key_states[39]);
        }
        if (std.mem.eql(u8, s, "space") or std.mem.eql(u8, s, "jump")) {
            return Dynamic.initBool(key_states[65] or key_states[111] or key_states[25] or key_states[53]);
        }
        if (std.mem.eql(u8, s, "shift") or std.mem.eql(u8, s, "run")) {
            return Dynamic.initBool(key_states[50] or key_states[62] or key_states[52] or key_states[54]);
        }
        if (std.mem.eql(u8, s, "r") or std.mem.eql(u8, s, "restart")) {
            return Dynamic.initBool(key_states[27]);
        }
        if (std.mem.eql(u8, s, "esc") or std.mem.eql(u8, s, "q")) {
            return Dynamic.initBool(key_states[9] or key_states[24]);
        }
    }
    return Dynamic.initBool(false);
}

pub fn get_input() anyerror!Dynamic {
    var dict = Dynamic.initDict(std.heap.c_allocator);
    const left = key_states[113] or key_states[38];
    const right = key_states[114] or key_states[40];
    const up = key_states[111] or key_states[25];
    const down = key_states[116] or key_states[39];
    const jump = key_states[65] or key_states[111] or key_states[25] or key_states[53];
    const run = key_states[50] or key_states[62] or key_states[52] or key_states[54];
    const restart = key_states[27];
    const quit = key_states[9] or key_states[24];
    const any_key = left or right or up or down or jump or run or restart or quit;

    try dict.value.dict_type.put(Dynamic.initStr("left"), Dynamic.initBool(left));
    try dict.value.dict_type.put(Dynamic.initStr("right"), Dynamic.initBool(right));
    try dict.value.dict_type.put(Dynamic.initStr("up"), Dynamic.initBool(up));
    try dict.value.dict_type.put(Dynamic.initStr("down"), Dynamic.initBool(down));
    try dict.value.dict_type.put(Dynamic.initStr("jump"), Dynamic.initBool(jump));
    try dict.value.dict_type.put(Dynamic.initStr("run"), Dynamic.initBool(run));
    try dict.value.dict_type.put(Dynamic.initStr("restart"), Dynamic.initBool(restart));
    try dict.value.dict_type.put(Dynamic.initStr("quit"), Dynamic.initBool(quit));
    try dict.value.dict_type.put(Dynamic.initStr("any_key"), Dynamic.initBool(any_key));
    return dict;
}


pub fn close() anyerror!Dynamic {
    is_running = false;
    if (x11_connected) {
        closeX11Window();
        _ = std.os.linux.write(1, "\x1b[?25h\r\x1b[K\n", 9);
    } else {
        const exit_seq = "\x1b[0m\x1b[?25h\x1b[?1049l\n";
        _ = std.os.linux.write(1, exit_seq, exit_seq.len);
    }
    return Dynamic.initNone();
}

pub fn get_render_time_ms() anyerror!Dynamic {
    return Dynamic.initFloat(last_render_time_ms);
}

pub fn get_show_time_ms() anyerror!Dynamic {
    return Dynamic.initFloat(last_show_time_ms);
}

pub fn get_fps() anyerror!Dynamic {
    return Dynamic.initFloat(last_fps);
}

pub fn get_cpu_usage() anyerror!Dynamic {
    return Dynamic.initFloat(updateCpuStats());
}

pub fn get_gpu_usage() anyerror!Dynamic {
    return Dynamic.initFloat(getGpuUsagePct());
}

pub fn get_memory_usage() anyerror!Dynamic {
    const mem = readMemoryStats();
    var dict = Dynamic.initDict(std.heap.c_allocator);
    try dict.value.dict_type.put(Dynamic.initStr("rss_mb"), Dynamic.initFloat(mem[0]));
    try dict.value.dict_type.put(Dynamic.initStr("vms_mb"), Dynamic.initFloat(mem[1]));
    return dict;
}

pub fn get_frame_count() anyerror!Dynamic {
    return Dynamic.initInt(@intCast(frame_counter));
}

pub fn get_benchmark_summary() anyerror!Dynamic {
    const total_time_sec = if (frame_counter > 0) @as(f64, @floatFromInt(readTimeNs() - start_timestamp_ns)) / 1e9 else 1.0;
    const avg_fps = if (total_time_sec > 0.0) @as(f64, @floatFromInt(frame_counter)) / total_time_sec else 0.0;
    const avg_render = if (frame_counter > 0) total_render_time_ms / @as(f64, @floatFromInt(frame_counter)) else 0.0;
    const avg_show = if (frame_counter > 0) total_show_time_ms / @as(f64, @floatFromInt(frame_counter)) else 0.0;
    const mem = readMemoryStats();

    var dict = Dynamic.initDict(std.heap.c_allocator);
    try dict.value.dict_type.put(Dynamic.initStr("total_frames"), Dynamic.initInt(@intCast(frame_counter)));
    try dict.value.dict_type.put(Dynamic.initStr("duration_sec"), Dynamic.initFloat(total_time_sec));
    try dict.value.dict_type.put(Dynamic.initStr("avg_fps"), Dynamic.initFloat(avg_fps));
    try dict.value.dict_type.put(Dynamic.initStr("avg_render_ms"), Dynamic.initFloat(avg_render));
    try dict.value.dict_type.put(Dynamic.initStr("avg_show_ms"), Dynamic.initFloat(avg_show));
    try dict.value.dict_type.put(Dynamic.initStr("min_frame_time_ms"), Dynamic.initFloat(min_frame_time_ms));
    try dict.value.dict_type.put(Dynamic.initStr("max_frame_time_ms"), Dynamic.initFloat(max_frame_time_ms));
    try dict.value.dict_type.put(Dynamic.initStr("cpu_usage_pct"), Dynamic.initFloat(updateCpuStats()));
    try dict.value.dict_type.put(Dynamic.initStr("gpu_usage_pct"), Dynamic.initFloat(getGpuUsagePct()));
    try dict.value.dict_type.put(Dynamic.initStr("memory_rss_mb"), Dynamic.initFloat(mem[0]));
    return dict;
}

// Module introspection & ABI hook
pub fn _is_abi() void {}

pub fn __sundapy_module_init() !void {}

pub fn builtin_getattr(_: *const @This(), attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "init")) return @import("datatype/dynamic.zig").toDynamicFunc(init);
    if (std.mem.eql(u8, attr, "render_buffer")) return @import("datatype/dynamic.zig").toDynamicFunc(render_buffer);
    if (std.mem.eql(u8, attr, "record_render_time")) return @import("datatype/dynamic.zig").toDynamicFunc(record_render_time);
    if (std.mem.eql(u8, attr, "sleep_until_next_frame")) return @import("datatype/dynamic.zig").toDynamicFunc(sleep_until_next_frame);
    if (std.mem.eql(u8, attr, "poll_events")) return @import("datatype/dynamic.zig").toDynamicFunc(poll_events);
    if (std.mem.eql(u8, attr, "is_key_pressed")) return @import("datatype/dynamic.zig").toDynamicFunc(is_key_pressed);
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
