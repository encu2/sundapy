const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn div(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "/") catch std.debug.panic("Python ABI Math Error for /\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "/") catch std.debug.panic("Python ABI Math Error for /\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: division by zero\n", .{});
                    return Dynamic.initFloat(@as(f64, @floatFromInt(av)) / @as(f64, @floatFromInt(bv)));
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float division by zero\n", .{});
                    return Dynamic.initFloat(@as(f64, @floatFromInt(av)) / bv);
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for /\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: float division by zero\n", .{});
                    return Dynamic.initFloat(av / @as(f64, @floatFromInt(bv)));
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float division by zero\n", .{});
                    return Dynamic.initFloat(av / bv);
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for /\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for /\n", .{}),
    }
}

pub fn floorDiv(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "//") catch std.debug.panic("Python ABI Math Error for //\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "//") catch std.debug.panic("Python ABI Math Error for //\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    if (bv == -1 and av == std.math.minInt(i64)) return Dynamic.initInt(std.math.minInt(i64));
                    return Dynamic.initInt(@divFloor(av, bv));
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(av);
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float floor division by zero\n", .{});
                    return Dynamic.initFloat(@floor(@as(f64, @floatFromInt(av)) / bv));
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
            }
        },
        .bool_type => |av| {
            const ai: i64 = if (av) 1 else 0;
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(@divFloor(ai, bv));
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(ai);
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float floor division by zero\n", .{});
                    return Dynamic.initFloat(@floor(@as(f64, @floatFromInt(ai)) / bv));
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: float floor division by zero\n", .{});
                    return Dynamic.initFloat(@floor(av / @as(f64, @floatFromInt(bv))));
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: float floor division by zero\n", .{});
                    return Dynamic.initFloat(@floor(av));
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float floor division by zero\n", .{});
                    return Dynamic.initFloat(@floor(av / bv));
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
    }
}

pub fn mod(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "%") catch std.debug.panic("Python ABI Math Error for %\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "%") catch std.debug.panic("Python ABI Math Error for %\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    if (bv == -1) return Dynamic.initInt(0);
                    return Dynamic.initInt(@mod(av, bv));
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(0);
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float modulo by zero\n", .{});
                    const af: f64 = @floatFromInt(av);
                    return Dynamic.initFloat(af - @floor(af / bv) * bv);
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
            }
        },
        .bool_type => |av| {
            const ai: i64 = if (av) 1 else 0;
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    if (bv == -1) return Dynamic.initInt(0);
                    return Dynamic.initInt(@mod(ai, bv));
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(0);
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float modulo by zero\n", .{});
                    const af: f64 = @floatFromInt(ai);
                    return Dynamic.initFloat(af - @floor(af / bv) * bv);
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: float modulo by zero\n", .{});
                    const bf: f64 = @floatFromInt(bv);
                    return Dynamic.initFloat(av - @floor(av / bf) * bf);
                },
                .bool_type => |bv| {
                    if (!bv) std.debug.panic("ZeroDivisionError: float modulo by zero\n", .{});
                    return Dynamic.initFloat(av - @floor(av));
                },
                .float_type => |bv| {
                    if (bv == 0.0) std.debug.panic("ZeroDivisionError: float modulo by zero\n", .{});
                    return Dynamic.initFloat(av - @floor(av / bv) * bv);
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
    }
}
