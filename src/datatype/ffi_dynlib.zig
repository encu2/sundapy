const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

extern "c" fn dlopen(path: [*c]const u8, mode: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*c]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;
extern "c" fn dlerror() ?[*:0]const u8;

pub const RTLD_LOCAL: c_int = 0;
pub const RTLD_LAZY: c_int = 1;
pub const RTLD_NOW: c_int = 2;
pub const RTLD_GLOBAL: c_int = 256;

pub const DynLibHandle = struct {
    handle: *anyopaque,
    path: []const u8,

    pub fn getSymbol(self: *DynLibHandle, symbol_name: []const u8) !*anyopaque {
        var name_buf: [256]u8 = undefined;
        if (symbol_name.len >= 255) return error.SymbolNameTooLong;
        @memcpy(name_buf[0..symbol_name.len], symbol_name);
        name_buf[symbol_name.len] = 0;

        const sym = dlsym(self.handle, &name_buf);
        if (sym == null) {
            return error.SymbolNotFound;
        }
        return sym.?;
    }

    pub fn close(self: *DynLibHandle) void {
        _ = dlclose(self.handle);
    }

    pub fn callRaw(fn_ptr: *anyopaque, args: []const Dynamic) anyerror!Dynamic {
        const u = struct {
            fn toUsize(d: Dynamic) usize {
                return switch (d.value) {
                    .i64_type => |i| @as(usize, @bitCast(i)),
                    .bool_type => |b| if (b) 1 else 0,
                    .str_type => |s| @intFromPtr(s.ptr),
                    else => 0,
                };
            }
        };

        switch (args.len) {
            0 => {
                const f: *const fn () callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f());
            },
            1 => {
                const f: *const fn (usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0])));
            },
            2 => {
                const f: *const fn (usize, usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0]), u.toUsize(args[1])));
            },
            3 => {
                const f: *const fn (usize, usize, usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0]), u.toUsize(args[1]), u.toUsize(args[2])));
            },
            4 => {
                const f: *const fn (usize, usize, usize, usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0]), u.toUsize(args[1]), u.toUsize(args[2]), u.toUsize(args[3])));
            },
            5 => {
                const f: *const fn (usize, usize, usize, usize, usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0]), u.toUsize(args[1]), u.toUsize(args[2]), u.toUsize(args[3]), u.toUsize(args[4])));
            },
            6 => {
                const f: *const fn (usize, usize, usize, usize, usize, usize) callconv(.c) i64 = @ptrCast(fn_ptr);
                return Dynamic.initInt(f(u.toUsize(args[0]), u.toUsize(args[1]), u.toUsize(args[2]), u.toUsize(args[3]), u.toUsize(args[4]), u.toUsize(args[5])));
            },
            else => return error.TooManyArguments,
        }
    }
};

pub fn open(allocator: std.mem.Allocator, path: []const u8, flags: c_int) !*DynLibHandle {
    var path_buf: [1024]u8 = undefined;
    if (path.len >= 1023) return error.PathTooLong;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;

    const actual_flags = if (flags == 0) (RTLD_NOW | RTLD_GLOBAL) else flags;
    const handle = dlopen(&path_buf, actual_flags);
    if (handle == null) {
        return error.LibraryNotFound;
    }

    const obj = try allocator.create(DynLibHandle);
    obj.* = .{
        .handle = handle.?,
        .path = path,
    };
    return obj;
}
