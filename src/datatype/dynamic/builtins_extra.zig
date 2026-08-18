const std = @import("std");
const Dynamic = @import("../../datatype/dynamic.zig").Dynamic;

pub fn builtin_help(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.print("Help on sundapy builtin.\n", .{});
    return Dynamic.initNone();
}
pub fn builtin_memoryview(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.panic("NotImplementedError: memoryview() stub\n", .{});
    unreachable;
}
pub fn builtin_slice(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.panic("NotImplementedError: slice() stub\n", .{});
    unreachable;
}
pub fn builtin_vars(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.panic("NotImplementedError: vars() stub\n", .{});
    unreachable;
}
pub fn builtin___import__(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.panic("NotImplementedError: __import__() stub\n", .{});
    unreachable;
}
pub fn builtin_zip(alloc: std.mem.Allocator, args: []const Dynamic) Dynamic {
    _ = alloc; _ = args;
    std.debug.panic("NotImplementedError: zip() stub\n", .{});
    unreachable;
}
pub fn builtin_format(self: Dynamic, format_spec: Dynamic) Dynamic {
    _ = format_spec;
    // Stub for format
    return self; 
}
pub fn builtin_issubclass(self: Dynamic, classinfo: Dynamic) Dynamic {
    _ = self; _ = classinfo;
    std.debug.panic("NotImplementedError: issubclass() stub\n", .{});
    unreachable;
}
pub fn builtin_object(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc; _ = arg;
    return Dynamic.initStr("<object>");
}
pub fn builtin_super(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc; _ = arg;
    std.debug.panic("NotImplementedError: super() stub\n", .{});
    unreachable;
}
pub fn builtin_breakpoint(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc; _ = arg;
    // No-op for now
    return Dynamic.initNone();
}
