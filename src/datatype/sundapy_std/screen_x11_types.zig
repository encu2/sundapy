const std = @import("std");

// ============================================================================
// X11 Protocol Definitions, State & Authentication
// ============================================================================

pub extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
pub extern "c" fn shmget(key: c_int, size: usize, shmflg: c_int) c_int;
pub extern "c" fn shmat(shmid: c_int, shmaddr: ?*const anyopaque, shmflg: c_int) ?*anyopaque;
pub extern "c" fn shmdt(shmaddr: ?*const anyopaque) c_int;
pub extern "c" fn shmctl(shmid: c_int, cmd: c_int, buf: ?*anyopaque) c_int;

pub const IPC_PRIVATE: c_int = 0;
pub const IPC_CREAT: c_int = 0o1000;
pub const IPC_RMID: c_int = 0;

pub var x11_fd: std.posix.fd_t = -1;
pub var x11_connected: bool = false;
pub var x11_win_id: u32 = 0;
pub var x11_gc_id: u32 = 0;
pub var x11_win_w: u16 = 640;
pub var x11_win_h: u16 = 480;
pub var x11_scale: usize = 1;
pub var x11_img_buf: ?[]u8 = null;
pub var x11_heap_buf: ?[]u8 = null;
pub var x11_shm_supported: bool = false;
pub var x11_shm_active: bool = false;
pub var x11_shm_opcode: u8 = 0;
pub var x11_shmseg_id: u32 = 0;
pub var x11_shm_id: c_int = -1;
pub var x11_shm_addr: ?*anyopaque = null;
pub var wm_protocols: u32 = 0;
pub var wm_delete_window: u32 = 0;

pub fn readXauthCookie(allocator: std.mem.Allocator, cookie_out: *[16]u8) bool {
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
        pos += 2;
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

pub fn readFull(fd: std.posix.fd_t, buf: []u8) bool {
    var total: usize = 0;
    while (total < buf.len) {
        const n = std.os.linux.read(fd, buf[total..].ptr, buf.len - total);
        if (n <= 0) return false;
        total += @intCast(n);
    }
    return true;
}

pub fn internAtom(fd: std.posix.fd_t, atom_name: []const u8) ?u32 {
    const pad: usize = (4 - (atom_name.len % 4)) % 4;
    const req_len: u16 = @intCast((8 + atom_name.len + pad) / 4);
    var buf: [128]u8 = undefined;
    if (@as(usize, req_len) * 4 > buf.len) return null;
    @memset(buf[0 .. @as(usize, req_len) * 4], 0);
    buf[0] = 16;
    buf[1] = 0;
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
