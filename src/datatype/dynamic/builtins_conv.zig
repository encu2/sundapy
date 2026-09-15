const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub fn builtin_int(self: Dynamic) Dynamic {
    switch (self.value) {
        .i64_type => return self,
        .float_type => |f| return Dynamic.initInt(@as(i64, @intFromFloat(f))),
        .str_type => |s| {
            const val = std.fmt.parseInt(i64, s, 10) catch std.debug.panic("ValueError: invalid literal for int() with base 10: {s}\n", .{s});
            return Dynamic.initInt(val);
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").PikaPython.getString(obj);
                const val = std.fmt.parseInt(i64, s, 10) catch 0;
                return Dynamic.initInt(val);
            }
            return Dynamic.initInt(0);
        },
        else => std.debug.panic("TypeError: int() argument must be a string, a bytes-like object or a real number\n", .{}),
    }
}
pub fn builtin_float(self: Dynamic) Dynamic {
    switch (self.value) {
        .float_type => return self,
        .i64_type => |i| return Dynamic.initFloat(@as(f64, @floatFromInt(i))),
        .str_type => |s| {
            const val = std.fmt.parseFloat(f64, s) catch std.debug.panic("ValueError: could not convert string to float: {s}\n", .{s});
            return Dynamic.initFloat(val);
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").PikaPython.getString(obj);
                const val = std.fmt.parseFloat(f64, s) catch 0.0;
                return Dynamic.initFloat(val);
            }
            return Dynamic.initFloat(0.0);
        },
        else => std.debug.panic("TypeError: float() argument must be a string or a real number\n", .{}),
    }
}
pub fn builtin_str(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
    switch (self.value) {
        .str_type => return self,
        .i64_type => |i| {
            const s = std.fmt.allocPrint(alloc, "{d}", .{i}) catch unreachable;
            return Dynamic.initStr(s);
        },
        .float_type => |f| {
            const s = std.fmt.allocPrint(alloc, "{d}", .{f}) catch unreachable;
            return Dynamic.initStr(s);
        },
        .bool_type => |b| {
            if (b) return Dynamic.initStr("True");
            return Dynamic.initStr("False");
        },
        .none_type => return Dynamic.initStr("None"),
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").PikaPython.getString(obj);
                return Dynamic.initStr(s);
            }
            return Dynamic.initStr("None");
        },
        else => return Dynamic.initStr("<object>"),
    }
}
pub fn builtin_bool(self: Dynamic) Dynamic {
    return Dynamic.initBool(self.toBool());
}
