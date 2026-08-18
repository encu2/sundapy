const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn pow(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(std.math.pow(i64, a.value.i64_type, b.value.i64_type));
    } else if (a.value == .float_type and b.value == .float_type) {
        return Dynamic.initFloat(std.math.pow(f64, a.value.float_type, b.value.float_type));
    } else if (a.value == .i64_type and b.value == .float_type) {
        return Dynamic.initFloat(std.math.pow(f64, @as(f64, @floatFromInt(a.value.i64_type)), b.value.float_type));
    } else if (a.value == .float_type and b.value == .i64_type) {
        return Dynamic.initFloat(std.math.pow(f64, a.value.float_type, @as(f64, @floatFromInt(b.value.i64_type))));
    }
    std.debug.panic("TypeError: unsupported operand type(s) for **\n", .{});
}

pub fn bitAnd(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(a.value.i64_type & b.value.i64_type);
    }
    std.debug.panic("TypeError: unsupported operand type(s) for &\n", .{});
}

pub fn bitOr(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(a.value.i64_type | b.value.i64_type);
    }
    std.debug.panic("TypeError: unsupported operand type(s) for |\n", .{});
}

pub fn bitXor(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(a.value.i64_type ^ b.value.i64_type);
    }
    std.debug.panic("TypeError: unsupported operand type(s) for ^\n", .{});
}

pub fn shl(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(a.value.i64_type << @as(std.math.Log2Int(i64), @intCast(b.value.i64_type)));
    }
    std.debug.panic("TypeError: unsupported operand type(s) for <<\n", .{});
}

pub fn shr(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .i64_type and b.value == .i64_type) {
        return Dynamic.initInt(a.value.i64_type >> @as(std.math.Log2Int(i64), @intCast(b.value.i64_type)));
    }
    std.debug.panic("TypeError: unsupported operand type(s) for >>\n", .{});
}

pub fn bitNot(a: Dynamic) Dynamic {
    if (a.value == .i64_type) {
        return Dynamic.initInt(~a.value.i64_type);
    }
    std.debug.panic("TypeError: bad operand type for unary ~\n", .{});
}
