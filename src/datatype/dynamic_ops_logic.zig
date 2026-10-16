const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub inline fn isTruthy(a: Dynamic) bool {
    return a.toBool();
}

pub inline fn logicAnd(a: Dynamic, b: Dynamic) Dynamic {
    if (isTruthy(a)) {
        return b;
    }
    return a;
}

pub inline fn logicOr(a: Dynamic, b: Dynamic) Dynamic {
    if (isTruthy(a)) {
        return a;
    }
    return b;
}

pub inline fn logicNot(a: Dynamic) Dynamic {
    return Dynamic.initBool(!isTruthy(a));
}

pub inline fn neg(a: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |v| return Dynamic.initInt(-%v),
        .float_type => |v| return Dynamic.initFloat(-v),
        .bool_type => |v| return Dynamic.initInt(if (v) @as(i64, -1) else @as(i64, 0)),
        else => std.debug.panic("TypeError: bad operand type for unary -\n", .{}),
    }
}

pub inline fn pos(a: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type, .float_type, .bool_type => return a,
        else => std.debug.panic("TypeError: bad operand type for unary +\n", .{}),
    }
}
