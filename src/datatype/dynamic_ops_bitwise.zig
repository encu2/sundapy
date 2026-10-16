const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

inline fn toIntVal(d: Dynamic) ?i64 {
    return switch (d.value) {
        .i64_type => |v| v,
        .bool_type => |v| if (v) 1 else 0,
        else => null,
    };
}

pub fn pow(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "**") catch std.debug.panic("Python ABI Math Error for **\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "**") catch std.debug.panic("Python ABI Math Error for **\n", .{});
    }

    if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            if (bi < 0) {
                return Dynamic.initFloat(std.math.pow(f64, @as(f64, @floatFromInt(ai)), @as(f64, @floatFromInt(bi))));
            }
            return Dynamic.initInt(std.math.pow(i64, ai, bi));
        } else if (b.value == .float_type) {
            return Dynamic.initFloat(std.math.pow(f64, @as(f64, @floatFromInt(ai)), b.value.float_type));
        }
    } else if (a.value == .float_type) {
        if (b.value == .float_type) {
            return Dynamic.initFloat(std.math.pow(f64, a.value.float_type, b.value.float_type));
        } else if (toIntVal(b)) |bi| {
            return Dynamic.initFloat(std.math.pow(f64, a.value.float_type, @as(f64, @floatFromInt(bi))));
        }
    }
    std.debug.panic("TypeError: unsupported operand type(s) for **\n", .{});
}

pub fn bitAnd(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "&") catch std.debug.panic("Python ABI Math Error for &\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "&") catch std.debug.panic("Python ABI Math Error for &\n", .{});
    }

    if (a.value == .bool_type and b.value == .bool_type) {
        return Dynamic.initBool(a.value.bool_type and b.value.bool_type);
    } else if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            return Dynamic.initInt(ai & bi);
        }
    } else if (a.value == .set_type and b.value == .set_type) {
        const alloc = std.heap.page_allocator;
        var res_set = @import("set.zig").Set.init(alloc);
        for (a.value.set_type.items.items) |elem| {
            for (b.value.set_type.items.items) |belem| {
                if (elem.eq(belem).toBool()) {
                    res_set.add(alloc, elem) catch unreachable;
                    break;
                }
            }
        }
        return Dynamic{ .value = .{ .set_type = res_set } };
    }
    std.debug.panic("TypeError: unsupported operand type(s) for &\n", .{});
}

pub fn bitOr(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "|") catch std.debug.panic("Python ABI Math Error for |\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "|") catch std.debug.panic("Python ABI Math Error for |\n", .{});
    }

    if (a.value == .bool_type and b.value == .bool_type) {
        return Dynamic.initBool(a.value.bool_type or b.value.bool_type);
    } else if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            return Dynamic.initInt(ai | bi);
        }
    } else if (a.value == .set_type and b.value == .set_type) {
        const alloc = std.heap.page_allocator;
        var res_set = @import("set.zig").Set.init(alloc);
        for (a.value.set_type.items.items) |elem| {
            res_set.add(alloc, elem) catch unreachable;
        }
        for (b.value.set_type.items.items) |elem| {
            res_set.add(alloc, elem) catch unreachable;
        }
        return Dynamic{ .value = .{ .set_type = res_set } };
    }
    std.debug.panic("TypeError: unsupported operand type(s) for |\n", .{});
}

pub fn bitXor(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "^") catch std.debug.panic("Python ABI Math Error for ^\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "^") catch std.debug.panic("Python ABI Math Error for ^\n", .{});
    }

    if (a.value == .bool_type and b.value == .bool_type) {
        return Dynamic.initBool(a.value.bool_type != b.value.bool_type);
    } else if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            return Dynamic.initInt(ai ^ bi);
        }
    } else if (a.value == .set_type and b.value == .set_type) {
        const alloc = std.heap.page_allocator;
        var res_set = @import("set.zig").Set.init(alloc);
        for (a.value.set_type.items.items) |elem| {
            var in_b = false;
            for (b.value.set_type.items.items) |belem| {
                if (elem.eq(belem).toBool()) { in_b = true; break; }
            }
            if (!in_b) res_set.add(alloc, elem) catch unreachable;
        }
        for (b.value.set_type.items.items) |elem| {
            var in_a = false;
            for (a.value.set_type.items.items) |aelem| {
                if (elem.eq(aelem).toBool()) { in_a = true; break; }
            }
            if (!in_a) res_set.add(alloc, elem) catch unreachable;
        }
        return Dynamic{ .value = .{ .set_type = res_set } };
    }
    std.debug.panic("TypeError: unsupported operand type(s) for ^\n", .{});
}

pub fn shl(a: Dynamic, b: Dynamic) Dynamic {
    if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            if (bi < 0) std.debug.panic("ValueError: negative shift count\n", .{});
            if (bi >= 64) return Dynamic.initInt(0);
            return Dynamic.initInt(ai << @as(u6, @intCast(bi)));
        }
    }
    std.debug.panic("TypeError: unsupported operand type(s) for <<\n", .{});
}

pub fn shr(a: Dynamic, b: Dynamic) Dynamic {
    if (toIntVal(a)) |ai| {
        if (toIntVal(b)) |bi| {
            if (bi < 0) std.debug.panic("ValueError: negative shift count\n", .{});
            if (bi >= 64) return Dynamic.initInt(if (ai < 0) -1 else 0);
            return Dynamic.initInt(ai >> @as(u6, @intCast(bi)));
        }
    }
    std.debug.panic("TypeError: unsupported operand type(s) for >>\n", .{});
}

pub fn bitNot(a: Dynamic) Dynamic {
    if (a.value == .i64_type) {
        return Dynamic.initInt(~a.value.i64_type);
    } else if (a.value == .bool_type) {
        const v: i64 = if (a.value.bool_type) 1 else 0;
        return Dynamic.initInt(~v);
    }
    std.debug.panic("TypeError: bad operand type for unary ~\n", .{});
}
