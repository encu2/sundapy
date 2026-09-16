const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn add(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMath(a.value.py_obj_type.?, b, "+") catch std.debug.panic("Python ABI Math Error for +\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMathReverse(a, b.value.py_obj_type.?, "+") catch std.debug.panic("Python ABI Math Error for +\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av + bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) + bv),
                .bool_type => |bv| return Dynamic.initInt(av + if(bv) @as(i64, 1) else @as(i64, 0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'int' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initFloat(av + bv),
                .i64_type => |bv| return Dynamic.initFloat(av + @as(f64, @floatFromInt(bv))),
                .bool_type => |bv| return Dynamic.initFloat(av + if(bv) @as(f64, 1.0) else @as(f64, 0.0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'float' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .bool_type => |av| {
            const ai: i64 = if (av) 1 else 0;
            switch (b.value) {
                .bool_type => |bv| return Dynamic.initInt(ai + if(bv) @as(i64, 1) else @as(i64, 0)),
                .i64_type => |bv| return Dynamic.initInt(ai + bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(ai)) + bv),
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'bool' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| {
                    const allocator = std.heap.page_allocator;
                    var new_str = allocator.alloc(u8, av.len + bv.len) catch unreachable;
                    @memcpy(new_str[0..av.len], av);
                    @memcpy(new_str[av.len..av.len + bv.len], bv);
                    return Dynamic{ .value = .{ .str_type = new_str } };
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'str' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for +\n", .{}),
    }
}

pub fn sub(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMath(a.value.py_obj_type.?, b, "-") catch std.debug.panic("Python ABI Math Error for -\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMathReverse(a, b.value.py_obj_type.?, "-") catch std.debug.panic("Python ABI Math Error for -\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av - bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) - bv),
                .bool_type => |bv| return Dynamic.initInt(av - if(bv) @as(i64, 1) else @as(i64, 0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for -: 'int' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initFloat(av - bv),
                .i64_type => |bv| return Dynamic.initFloat(av - @as(f64, @floatFromInt(bv))),
                .bool_type => |bv| return Dynamic.initFloat(av - if(bv) @as(f64, 1.0) else @as(f64, 0.0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for -: 'float' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for -\n", .{}),
    }
}

pub fn mul(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMath(a.value.py_obj_type.?, b, "*") catch std.debug.panic("Python ABI Math Error for *\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMathReverse(a, b.value.py_obj_type.?, "*") catch std.debug.panic("Python ABI Math Error for *\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av * bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) * bv),
                .list_type => |bv| {
                    const count = @max(0, av);
                    const allocator = std.heap.page_allocator;
                    var new_list = std.ArrayList(Dynamic).empty;
                    const orig_items = bv.items.items;
                    const total_len = orig_items.len * @as(usize, @intCast(count));
                    new_list.ensureTotalCapacity(allocator, total_len) catch unreachable;
                    var rep: usize = 0;
                    while (rep < count) : (rep += 1) {
                        new_list.appendSlice(allocator, orig_items) catch unreachable;
                    }
                    return Dynamic.initList(new_list);
                },
                .str_type => |sv| {
                    const count = @max(0, av);
                    const allocator = std.heap.page_allocator;
                    const total_len = sv.len * @as(usize, @intCast(count));
                    var new_str = allocator.alloc(u8, total_len) catch unreachable;
                    var rep: usize = 0;
                    while (rep < count) : (rep += 1) {
                        @memcpy(new_str[rep * sv.len .. (rep + 1) * sv.len], sv);
                    }
                    return Dynamic{ .value = .{ .str_type = new_str } };
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initFloat(av * bv),
                .i64_type => |bv| return Dynamic.initFloat(av * @as(f64, @floatFromInt(bv))),
                else => std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{}),
            }
        },
        .list_type => |lv| {
            if (b.value == .i64_type) {
                const count = @max(0, b.value.i64_type);
                const allocator = std.heap.page_allocator;
                var new_list = std.ArrayList(Dynamic).empty;
                const orig_items = lv.items.items;
                const total_len = orig_items.len * @as(usize, @intCast(count));
                new_list.ensureTotalCapacity(allocator, total_len) catch unreachable;
                var rep: usize = 0;
                while (rep < count) : (rep += 1) {
                    new_list.appendSlice(allocator, orig_items) catch unreachable;
                }
                return Dynamic.initList(new_list);
            }
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        .str_type => |sv| {
            if (b.value == .i64_type) {
                const count = @max(0, b.value.i64_type);
                const allocator = std.heap.page_allocator;
                const total_len = sv.len * @as(usize, @intCast(count));
                var new_str = allocator.alloc(u8, total_len) catch unreachable;
                var rep: usize = 0;
                while (rep < count) : (rep += 1) {
                    @memcpy(new_str[rep * sv.len .. (rep + 1) * sv.len], sv);
                }
                return Dynamic{ .value = .{ .str_type = new_str } };
            }
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{}),
    }
}

pub fn div(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMath(a.value.py_obj_type.?, b, "/") catch std.debug.panic("Python ABI Math Error for /\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").PikaPython.doMathReverse(a, b.value.py_obj_type.?, "/") catch std.debug.panic("Python ABI Math Error for /\n", .{});
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
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(@divFloor(av, bv));
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for //\n", .{}),
    }
}

pub fn mod(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| {
                    if (bv == 0) std.debug.panic("ZeroDivisionError: integer division or modulo by zero\n", .{});
                    return Dynamic.initInt(@mod(av, bv));
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for %\n", .{}),
    }
}

pub const eq = @import("dynamic_ops_cmp.zig").eq;
pub const neq = @import("dynamic_ops_cmp.zig").neq;
pub const lt = @import("dynamic_ops_cmp.zig").lt;
pub const gt = @import("dynamic_ops_cmp.zig").gt;
pub const le = @import("dynamic_ops_cmp.zig").le;
pub const ge = @import("dynamic_ops_cmp.zig").ge;


pub const pow = @import("dynamic_ops_bitwise.zig").pow;
pub const bitAnd = @import("dynamic_ops_bitwise.zig").bitAnd;
pub const bitOr = @import("dynamic_ops_bitwise.zig").bitOr;
pub const bitXor = @import("dynamic_ops_bitwise.zig").bitXor;
pub const shl = @import("dynamic_ops_bitwise.zig").shl;
pub const shr = @import("dynamic_ops_bitwise.zig").shr;
pub const bitNot = @import("dynamic_ops_bitwise.zig").bitNot;

pub fn isTruthy(a: Dynamic) bool {
    return a.toBool();
}

pub fn logicAnd(a: Dynamic, b: Dynamic) Dynamic {
    if (isTruthy(a)) {
        return b;
    }
    return a;
}

pub fn logicOr(a: Dynamic, b: Dynamic) Dynamic {
    if (isTruthy(a)) {
        return a;
    }
    return b;
}

pub fn logicNot(a: Dynamic) Dynamic {
    return Dynamic.initBool(!isTruthy(a));
}

pub fn neg(a: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |v| return Dynamic.initInt(-v),
        .float_type => |v| return Dynamic.initFloat(-v),
        .bool_type => |v| return Dynamic.initInt(if(v) @as(i64, -1) else @as(i64, 0)),
        else => std.debug.panic("TypeError: bad operand type for unary -\n", .{}),
    }
}

pub fn pos(a: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type, .float_type, .bool_type => return a,
        else => std.debug.panic("TypeError: bad operand type for unary +\n", .{}),
    }
}

