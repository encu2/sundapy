const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const name = Dynamic.initStr("socket");
pub const AF_INET = Dynamic.initInt(2);
pub const AF_INET6 = Dynamic.initInt(10);
pub const SOCK_STREAM = Dynamic.initInt(1);

pub fn gethostname() anyerror!Dynamic {
    const uname = std.posix.uname();
    const len = std.mem.indexOfScalar(u8, &uname.nodename, 0) orelse uname.nodename.len;
    return Dynamic.initStr(uname.nodename[0..len]);
}




pub const socket_class = struct {
    fd: Dynamic = undefined,
    family: i64 = 2,

    pub inline fn __init__(self: *socket_class, family: Dynamic, type_: Dynamic) anyerror!Dynamic {
        var fam: u32 = std.os.linux.AF.INET;
        if (family.value == .i64_type) {
            self.family = family.value.i64_type;
            if (self.family != 0) {
                fam = @intCast(self.family);
            }
        }
        var typ: u32 = std.os.linux.SOCK.STREAM;
        if (type_.value == .i64_type) {
            typ = @intCast(type_.value.i64_type);
        }
        
        const sockfd = std.os.linux.socket(fam, typ | std.os.linux.SOCK.CLOEXEC, 0);
        if (@as(isize, @bitCast(sockfd)) < 0) std.debug.panic("OSError: failed to create socket\n", .{});
        self.fd = Dynamic.initInt(@intCast(sockfd));
        return Dynamic{ .value = .none_type };
    }

    pub fn connect(self: *socket_class, address: Dynamic) anyerror!Dynamic {
        if (address.value != .list_type) std.debug.panic("TypeError: connect() argument must be tuple (list in sundapy)\n", .{});
        const host_dyn = address.getItem(0);
        const port_dyn = address.getItem(1);
        if (host_dyn.value != .str_type or port_dyn.value != .i64_type) std.debug.panic("TypeError: address must be (str, int)\n", .{});
        
        const host = host_dyn.value.str_type;
        const port = @as(u16, @intCast(port_dyn.value.i64_type));
        
        var hints: std.c.addrinfo = undefined;
        @memset(std.mem.asBytes(&hints), 0);
        hints.family = @intCast(self.family);
        hints.socktype = std.os.linux.SOCK.STREAM;
        
        var host_z: [256]u8 = undefined;
        if (host.len >= 256) std.debug.panic("ValueError: host too long\n", .{});
        @memcpy(host_z[0..host.len], host);
        host_z[host.len] = 0;
        
        var port_z: [16]u8 = undefined;
        const port_slice = std.fmt.bufPrintZ(&port_z, "{d}", .{port}) catch unreachable;
        
        var res: ?*std.c.addrinfo = null;
        const rc = std.c.getaddrinfo(@ptrCast(&host_z), @ptrCast(port_slice), &hints, &res);
        if (@intFromEnum(rc) != 0) std.debug.panic("socket.gaierror: nodename nor servname provided, or not known\n", .{});
        defer std.c.freeaddrinfo(res.?);
        
        const sockfd = @as(i32, @intCast(self.fd.value.i64_type));
        
        var curr = res;
        var connected = false;
        while (curr) |addr| {
            const sa_ptr: *const std.os.linux.sockaddr = @ptrCast(addr.addr.?);
            // Re-create socket with the resolved family if needed
            if (self.family == 0) { // AF_UNSPEC
                _ = std.os.linux.close(sockfd);
                const new_sockfd = std.os.linux.socket(@intCast(addr.family), std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC, 0);
                if (@as(isize, @bitCast(new_sockfd)) >= 0) {
                    self.fd = Dynamic.initInt(@intCast(new_sockfd));
                }
            }
            
            const cur_sockfd = @as(i32, @intCast(self.fd.value.i64_type));
            // Add a timeout to connect so it doesn't hang forever
            var tv = std.os.linux.timeval{ .sec = 2, .usec = 0 };
            _ = std.os.linux.setsockopt(cur_sockfd, std.os.linux.SOL.SOCKET, std.os.linux.SO.SNDTIMEO, @ptrCast(&tv), @sizeOf(std.os.linux.timeval));
            
            const connect_res = std.os.linux.connect(cur_sockfd, sa_ptr, addr.addrlen);
            if (@as(isize, @bitCast(connect_res)) >= 0) {
                connected = true;
                break;
            }
            curr = addr.next;
        }
        
        if (!connected) std.debug.panic("ConnectionError: connection refused or timed out\n", .{});
        
        return Dynamic{ .value = .none_type };
    }
    
    pub fn send(self: *socket_class, data: Dynamic) anyerror!Dynamic {
        if (data.value != .str_type) std.debug.panic("TypeError: a bytes-like object is required, not '{s}'\n", .{@tagName(data.value)});
        const sockfd = @as(i32, @intCast(self.fd.value.i64_type));
        const sent = std.os.linux.sendto(sockfd, data.value.str_type.ptr, data.value.str_type.len, 0, null, 0);
        if (@as(isize, @bitCast(sent)) < 0) std.debug.panic("BrokenPipeError: broken pipe\n", .{});
        return Dynamic.initInt(@intCast(sent));
    }
    
    pub fn recv(self: *socket_class, bufsize: Dynamic) anyerror!Dynamic {
        if (bufsize.value != .i64_type) std.debug.panic("TypeError: an integer is required\n", .{});
        const size = @as(usize, @intCast(bufsize.value.i64_type));
        const buf = std.heap.page_allocator.alloc(u8, size) catch unreachable;
        
        const sockfd = @as(i32, @intCast(self.fd.value.i64_type));
        
        // Add a read timeout to prevent infinite blocking
        var tv = std.os.linux.timeval{ .sec = 5, .usec = 0 };
        _ = std.os.linux.setsockopt(sockfd, std.os.linux.SOL.SOCKET, std.os.linux.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(std.os.linux.timeval));
        
        const received = std.os.linux.recvfrom(sockfd, buf.ptr, buf.len, 0, null, null);
        const recv_isize = @as(isize, @bitCast(received));
        if (recv_isize < 0) {
            const err = -recv_isize;
            if (err == 11) return Dynamic.initStr(""); // EAGAIN / EWOULDBLOCK
            std.debug.panic("ConnectionResetError: connection reset by peer (errno {d})\n", .{err});
        }
        if (received == 0) return Dynamic.initStr("");
        return Dynamic.initStr(buf[0..received]);
    }

    pub fn close(self: *socket_class) anyerror!Dynamic {
        const sockfd = @as(i32, @intCast(self.fd.value.i64_type));
        _ = std.os.linux.close(sockfd);
        return Dynamic{ .value = .none_type };
    }
};

pub fn socket(family: Dynamic, type_: Dynamic) anyerror!socket_class {
    var obj = socket_class{};
    _ = try obj.__init__(family, type_);
    return obj;
}
