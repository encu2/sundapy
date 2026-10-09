const std = @import("std");
const t = @import("screen_x11_types.zig");

// ============================================================================
// Screen GUI Native X11 Window & Connection Initialization
// ============================================================================

pub fn initX11Window(width: usize, height: usize, title: []const u8) bool {
    var disp_num: usize = 0;
    var has_display = false;

    if (t.getenv("DISPLAY")) |val| {
        const disp_str = std.mem.span(val);
        if (disp_str.len > 0) {
            if (std.mem.indexOfScalar(u8, disp_str, ':')) |colon_idx| {
                const rest = disp_str[colon_idx + 1 ..];
                const dot_idx = std.mem.indexOfScalar(u8, rest, '.') orelse rest.len;
                disp_num = std.fmt.parseInt(usize, rest[0..dot_idx], 10) catch 0;
                has_display = true;
            }
        }
    }

    if (!has_display) {
        if (std.os.linux.access("/tmp/.X11-unix/X0", 0) == 0) {
            disp_num = 0;
            has_display = true;
        } else if (std.os.linux.access("/tmp/.X11-unix/X1", 0) == 0) {
            disp_num = 1;
            has_display = true;
        } else {
            return false;
        }
    }

    var socket_path_buf: [64]u8 = undefined;
    const socket_path = std.fmt.bufPrint(&socket_path_buf, "/tmp/.X11-unix/X{d}", .{disp_num}) catch return false;

    var cookie: [16]u8 = undefined;
    const has_cookie = t.readXauthCookie(std.heap.c_allocator, &cookie);

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
    std.mem.writeInt(u16, packet[2..4], 11, .little);
    std.mem.writeInt(u16, packet[4..6], 0, .little);
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
    if (!t.readFull(fd, &rep_hdr) or rep_hdr[0] != 1) {
        _ = std.os.linux.close(fd);
        return false;
    }

    const extra_len = std.mem.readInt(u16, rep_hdr[6..8], .little) * 4;
    const extra = std.heap.c_allocator.alloc(u8, extra_len) catch {
        _ = std.os.linux.close(fd);
        return false;
    };
    defer std.heap.c_allocator.free(extra);

    if (!t.readFull(fd, extra)) {
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

    t.wm_protocols = t.internAtom(fd, "WM_PROTOCOLS") orelse 0;
    t.wm_delete_window = t.internAtom(fd, "WM_DELETE_WINDOW") orelse 0;

    var q_buf: [16]u8 = undefined;
    q_buf[0] = 98; // QueryExtension
    q_buf[1] = 0;
    std.mem.writeInt(u16, q_buf[2..4], 4, .little);
    std.mem.writeInt(u16, q_buf[4..6], 7, .little);
    std.mem.writeInt(u16, q_buf[6..8], 0, .little);
    @memcpy(q_buf[8..15], "MIT-SHM");
    q_buf[15] = 0;
    _ = std.os.linux.write(fd, &q_buf, 16);

    var q_rep: [32]u8 = undefined;
    if (t.readFull(fd, &q_rep) and q_rep[0] == 1 and q_rep[8] != 0) {
        t.x11_shm_opcode = q_rep[9];
        t.x11_shm_supported = true;
    } else {
        t.x11_shm_supported = false;
    }

    t.x11_win_id = id_base + 1;
    t.x11_gc_id = id_base + 2;

    var scale: usize = 1;
    while (width * (scale + 1) <= 960 and height * (scale + 1) <= 720) {
        scale += 1;
    }
    t.x11_scale = @max(1, scale);
    t.x11_win_w = @intCast(width * t.x11_scale);
    t.x11_win_h = @intCast(height * t.x11_scale);

    var create_win_buf: [40]u8 = undefined;
    create_win_buf[0] = 1;
    create_win_buf[1] = 0;
    std.mem.writeInt(u16, create_win_buf[2..4], 10, .little);
    std.mem.writeInt(u32, create_win_buf[4..8], t.x11_win_id, .little);
    std.mem.writeInt(u32, create_win_buf[8..12], root_win, .little);
    std.mem.writeInt(u16, create_win_buf[12..14], 100, .little);
    std.mem.writeInt(u16, create_win_buf[14..16], 100, .little);
    std.mem.writeInt(u16, create_win_buf[16..18], t.x11_win_w, .little);
    std.mem.writeInt(u16, create_win_buf[18..20], t.x11_win_h, .little);
    std.mem.writeInt(u16, create_win_buf[20..22], 0, .little);
    std.mem.writeInt(u16, create_win_buf[22..24], 1, .little);
    std.mem.writeInt(u32, create_win_buf[24..28], 0, .little);
    std.mem.writeInt(u32, create_win_buf[28..32], 0x802, .little);
    std.mem.writeInt(u32, create_win_buf[32..36], 0x00000000, .little);
    std.mem.writeInt(u32, create_win_buf[36..40], 0x208007, .little);
    _ = std.os.linux.write(fd, &create_win_buf, 40);

    const title_pad: usize = (title.len + 3) & ~@as(usize, 3);
    const cp_len: u16 = @intCast((24 + title_pad) / 4);
    const cp_buf = std.heap.c_allocator.alloc(u8, @as(usize, cp_len) * 4) catch null;
    if (cp_buf) |cp| {
        defer std.heap.c_allocator.free(cp);
        @memset(cp, 0);
        cp[0] = 18;
        cp[1] = 0;
        std.mem.writeInt(u16, cp[2..4], cp_len, .little);
        std.mem.writeInt(u32, cp[4..8], t.x11_win_id, .little);
        std.mem.writeInt(u32, cp[8..12], 39, .little); // WM_NAME
        std.mem.writeInt(u32, cp[12..16], 31, .little); // STRING
        cp[16] = 8;
        std.mem.writeInt(u32, cp[20..24], @intCast(title.len), .little);
        @memcpy(cp[24 .. 24 + title.len], title);
        _ = std.os.linux.write(fd, cp.ptr, cp.len);

        const net_wm_name = t.internAtom(fd, "_NET_WM_NAME");
        const utf8_string = t.internAtom(fd, "UTF8_STRING");
        if (net_wm_name != null and utf8_string != null) {
            std.mem.writeInt(u32, cp[8..12], net_wm_name.?, .little);
            std.mem.writeInt(u32, cp[12..16], utf8_string.?, .little);
            _ = std.os.linux.write(fd, cp.ptr, cp.len);
        }

        const net_wm_pid = t.internAtom(fd, "_NET_WM_PID");
        if (net_wm_pid) |pid_atom| {
            var pid_buf: [28]u8 = undefined;
            @memset(&pid_buf, 0);
            pid_buf[0] = 18;
            pid_buf[1] = 0;
            std.mem.writeInt(u16, pid_buf[2..4], 7, .little);
            std.mem.writeInt(u32, pid_buf[4..8], t.x11_win_id, .little);
            std.mem.writeInt(u32, pid_buf[8..12], pid_atom, .little);
            std.mem.writeInt(u32, pid_buf[12..16], 6, .little);
            pid_buf[16] = 32;
            std.mem.writeInt(u32, pid_buf[20..24], 1, .little);
            std.mem.writeInt(u32, pid_buf[24..28], @intCast(std.os.linux.getpid()), .little);
            _ = std.os.linux.write(fd, &pid_buf, 28);
        }
    }

    if (t.wm_protocols != 0 and t.wm_delete_window != 0) {
        var proto_buf: [28]u8 = undefined;
        @memset(&proto_buf, 0);
        proto_buf[0] = 18;
        proto_buf[1] = 0;
        std.mem.writeInt(u16, proto_buf[2..4], 7, .little);
        std.mem.writeInt(u32, proto_buf[4..8], t.x11_win_id, .little);
        std.mem.writeInt(u32, proto_buf[8..12], t.wm_protocols, .little);
        std.mem.writeInt(u32, proto_buf[12..16], 4, .little);
        proto_buf[16] = 32;
        std.mem.writeInt(u32, proto_buf[20..24], 1, .little);
        std.mem.writeInt(u32, proto_buf[24..28], t.wm_delete_window, .little);
        _ = std.os.linux.write(fd, &proto_buf, 28);
    }

    var hints_buf: [60]u8 = undefined;
    @memset(&hints_buf, 0);
    hints_buf[0] = 18;
    hints_buf[1] = 0;
    std.mem.writeInt(u16, hints_buf[2..4], 15, .little);
    std.mem.writeInt(u32, hints_buf[4..8], t.x11_win_id, .little);
    std.mem.writeInt(u32, hints_buf[8..12], 35, .little);
    std.mem.writeInt(u32, hints_buf[12..16], 35, .little);
    hints_buf[16] = 32;
    std.mem.writeInt(u32, hints_buf[20..24], 9, .little);
    std.mem.writeInt(u32, hints_buf[24..28], 3, .little);
    std.mem.writeInt(u32, hints_buf[28..32], 1, .little);
    std.mem.writeInt(u32, hints_buf[32..36], 1, .little);
    _ = std.os.linux.write(fd, &hints_buf, 60);

    const wm_class_str = "sundapy\x00sundapy\x00";
    const wm_class_len: u16 = @intCast((24 + wm_class_str.len) / 4);
    var class_buf: [40]u8 = undefined;
    @memset(&class_buf, 0);
    class_buf[0] = 18;
    class_buf[1] = 0;
    std.mem.writeInt(u16, class_buf[2..4], wm_class_len, .little);
    std.mem.writeInt(u32, class_buf[4..8], t.x11_win_id, .little);
    std.mem.writeInt(u32, class_buf[8..12], 67, .little);
    std.mem.writeInt(u32, class_buf[12..16], 31, .little);
    class_buf[16] = 8;
    std.mem.writeInt(u32, class_buf[20..24], @intCast(wm_class_str.len), .little);
    @memcpy(class_buf[24 .. 24 + wm_class_str.len], wm_class_str);
    _ = std.os.linux.write(fd, &class_buf, @as(usize, wm_class_len) * 4);

    const net_wm_win_type = t.internAtom(fd, "_NET_WM_WINDOW_TYPE");
    const net_wm_type_normal = t.internAtom(fd, "_NET_WM_WINDOW_TYPE_NORMAL");
    if (net_wm_win_type != null and net_wm_type_normal != null) {
        var wt_buf: [28]u8 = undefined;
        @memset(&wt_buf, 0);
        wt_buf[0] = 18;
        wt_buf[1] = 0;
        std.mem.writeInt(u16, wt_buf[2..4], 7, .little);
        std.mem.writeInt(u32, wt_buf[4..8], t.x11_win_id, .little);
        std.mem.writeInt(u32, wt_buf[8..12], net_wm_win_type.?, .little);
        std.mem.writeInt(u32, wt_buf[12..16], 4, .little);
        wt_buf[16] = 32;
        std.mem.writeInt(u32, wt_buf[20..24], 1, .little);
        std.mem.writeInt(u32, wt_buf[24..28], net_wm_type_normal.?, .little);
        _ = std.os.linux.write(fd, &wt_buf, 28);
    }

    var create_gc_buf: [16]u8 = undefined;
    create_gc_buf[0] = 55;
    create_gc_buf[1] = 0;
    std.mem.writeInt(u16, create_gc_buf[2..4], 4, .little);
    std.mem.writeInt(u32, create_gc_buf[4..8], t.x11_gc_id, .little);
    std.mem.writeInt(u32, create_gc_buf[8..12], t.x11_win_id, .little);
    std.mem.writeInt(u32, create_gc_buf[12..16], 0, .little);
    _ = std.os.linux.write(fd, &create_gc_buf, 16);

    var map_buf: [8]u8 = undefined;
    map_buf[0] = 8;
    map_buf[1] = 0;
    std.mem.writeInt(u16, map_buf[2..4], 2, .little);
    std.mem.writeInt(u32, map_buf[4..8], t.x11_win_id, .little);
    _ = std.os.linux.write(fd, &map_buf, 8);

    const img_bytes = @as(usize, t.x11_win_w) * t.x11_win_h * 4;
    t.x11_shmseg_id = id_base + 3;
    t.x11_shm_active = false;

    if (t.x11_shm_supported) {
        const shm_alloc_bytes = img_bytes * 2;
        const shmid = t.shmget(t.IPC_PRIVATE, shm_alloc_bytes, t.IPC_CREAT | 0o777);
        if (shmid >= 0) {
            const shmaddr = t.shmat(shmid, null, 0);
            if (@intFromPtr(shmaddr) != @as(usize, @bitCast(@as(isize, -1)))) {
                _ = t.shmctl(shmid, t.IPC_RMID, null);
                t.x11_shm_id = shmid;
                t.x11_shm_addr = shmaddr;

                var attach_buf: [16]u8 = undefined;
                attach_buf[0] = t.x11_shm_opcode;
                attach_buf[1] = 1;
                std.mem.writeInt(u16, attach_buf[2..4], 4, .little);
                std.mem.writeInt(u32, attach_buf[4..8], t.x11_shmseg_id, .little);
                std.mem.writeInt(u32, attach_buf[8..12], @intCast(shmid), .little);
                attach_buf[12] = 0;
                attach_buf[13] = 0;
                attach_buf[14] = 0;
                attach_buf[15] = 0;
                _ = std.os.linux.write(fd, &attach_buf, 16);

                var gif_buf: [4]u8 = undefined;
                gif_buf[0] = 43;
                gif_buf[1] = 0;
                std.mem.writeInt(u16, gif_buf[2..4], 1, .little);
                _ = std.os.linux.write(fd, &gif_buf, 4);

                var gif_rep: [32]u8 = undefined;
                if (t.readFull(fd, &gif_rep) and gif_rep[0] == 1) {
                    const ptr: [*]u8 = @ptrCast(shmaddr.?);
                    t.x11_img_buf = ptr[0..img_bytes];
                    t.x11_shm_active = true;
                } else {
                    _ = t.shmdt(shmaddr);
                    t.x11_shm_addr = null;
                }
            }
        }
    }

    if (!t.x11_shm_active) {
        t.x11_heap_buf = std.heap.c_allocator.alloc(u8, img_bytes) catch null;
        if (t.x11_heap_buf == null) {
            _ = std.os.linux.close(fd);
            return false;
        }
        t.x11_img_buf = t.x11_heap_buf;
    }

    const pool = @import("screen_buffer_pool.zig");
    const dirty = @import("screen_dirty.zig");
    dirty.initGrid(t.x11_win_w, t.x11_win_h);
    _ = pool.initPool(std.heap.c_allocator, t.x11_win_w, t.x11_win_h, t.x11_shm_active, if (t.x11_shm_addr) |a| @ptrCast(a) else null) catch {};
    if (pool.isInitialized()) {
        t.x11_img_buf = pool.getBackBuffer();
    }

    t.x11_fd = fd;
    t.x11_connected = true;
    return true;
}
