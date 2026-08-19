const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const Response = struct {
    status_code: Dynamic = undefined,
    text: Dynamic = undefined,

    pub inline fn __init__(self: *Response, status_code: Dynamic, text: Dynamic) anyerror!Dynamic {
        self.status_code = status_code;
        self.text = text;
        return Dynamic{ .value = .none_type };
    }
};

pub fn request(method_str: []const u8, url: Dynamic) anyerror!Response {
    if (url.value != .str_type) std.debug.panic("TypeError: url must be string\n", .{});
    
    // ponytail: standard library already provides an excellent native HTTP/1.1 HTTPS client.
    // HTTP/2 and HTTP/3 are intentionally omitted (YAGNI) because Python's own 'requests' library
    // natively uses urllib3 which is HTTP/1.1 by default. HTTP/3 would require QUIC boilerplate.
    
    const allocator = std.heap.page_allocator;
    var threaded_io = std.Io.Threaded.init(allocator, .{});
    const io = threaded_io.io();
    
    var client = std.http.Client{ .allocator = allocator, .io = io };
    defer client.deinit();

    var writer = std.Io.Writer.Allocating.init(allocator);

    const uri = std.Uri.parse(url.value.str_type) catch std.debug.panic("ValueError: Invalid URL\n", .{});
    const method = if (std.mem.eql(u8, method_str, "GET")) std.http.Method.GET 
                   else if (std.mem.eql(u8, method_str, "POST")) std.http.Method.POST
                   else std.http.Method.GET;

    const res = client.fetch(.{
        .location = .{ .uri = uri },
        .method = method,
        .response_writer = &writer.writer,
    }) catch std.debug.panic("ConnectionError: Failed to fetch\n", .{});

    var resp_obj = Response{};
    _ = try resp_obj.__init__(Dynamic.initInt(@as(i64, @intCast(@intFromEnum(res.status)))), Dynamic.initStr(writer.writer.buffer));
    return resp_obj;
}

pub fn get(url: Dynamic) anyerror!Response {
    return request("GET", url);
}

pub fn post(url: Dynamic) anyerror!Response {
    return request("POST", url);
}
