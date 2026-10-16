const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn add(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "+") catch std.debug.panic("Python ABI Math Error for +\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "+") catch std.debug.panic("Python ABI Math Error for +\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av + bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) + bv),
                .bool_type => |bv| return Dynamic.initInt(av + if (bv) @as(i64, 1) else @as(i64, 0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'int' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initFloat(av + bv),
                .i64_type => |bv| return Dynamic.initFloat(av + @as(f64, @floatFromInt(bv))),
                .bool_type => |bv| return Dynamic.initFloat(av + if (bv) @as(f64, 1.0) else @as(f64, 0.0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'float' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .bool_type => |av| {
            const ai: i64 = if (av) 1 else 0;
            switch (b.value) {
                .bool_type => |bv| return Dynamic.initInt(ai + if (bv) @as(i64, 1) else @as(i64, 0)),
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
                    @memcpy(new_str[av.len..], bv);
                    return Dynamic{ .value = .{ .str_type = new_str } };
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for +: 'str' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .bytes_type => |av| {
            switch (b.value) {
                .bytes_type => |bv| {
                    const allocator = std.heap.page_allocator;
                    var new_bytes = allocator.alloc(u8, av.len + bv.len) catch unreachable;
                    @memcpy(new_bytes[0..av.len], av);
                    @memcpy(new_bytes[av.len..], bv);
                    return Dynamic{ .value = .{ .bytes_type = new_bytes } };
                },
                else => std.debug.panic("TypeError: can't concat {s} to bytes\n", .{@tagName(b.value)}),
            }
        },
        .list_type => |av| {
            switch (b.value) {
                .list_type => |bv| {
                    const allocator = std.heap.page_allocator;
                    var new_list = std.ArrayList(Dynamic).empty;
                    const total_len = av.items.items.len + bv.items.items.len;
                    new_list.ensureTotalCapacity(allocator, total_len) catch unreachable;
                    new_list.appendSlice(allocator, av.items.items) catch unreachable;
                    new_list.appendSlice(allocator, bv.items.items) catch unreachable;
                    return Dynamic.initList(new_list);
                },
                else => std.debug.panic("TypeError: can only concatenate list to list\n", .{}),
            }
        },
        .tuple_type => |av| {
            switch (b.value) {
                .tuple_type => |bv| {
                    const allocator = std.heap.page_allocator;
                    var combined = allocator.alloc(Dynamic, av.items.len + bv.items.len) catch unreachable;
                    @memcpy(combined[0..av.items.len], av.items);
                    @memcpy(combined[av.items.len..], bv.items);
                    return Dynamic{ .value = .{ .tuple_type = .{ .items = combined, .allocator = allocator } } };
                },
                else => std.debug.panic("TypeError: can only concatenate tuple to tuple\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for +\n", .{}),
    }
}

pub fn sub(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "-") catch std.debug.panic("Python ABI Math Error for -\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "-") catch std.debug.panic("Python ABI Math Error for -\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av - bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) - bv),
                .bool_type => |bv| return Dynamic.initInt(av - if (bv) @as(i64, 1) else @as(i64, 0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for -: 'int' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initFloat(av - bv),
                .i64_type => |bv| return Dynamic.initFloat(av - @as(f64, @floatFromInt(bv))),
                .bool_type => |bv| return Dynamic.initFloat(av - if (bv) @as(f64, 1.0) else @as(f64, 0.0)),
                else => std.debug.panic("TypeError: unsupported operand type(s) for -: 'float' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        .set_type => |av| {
            switch (b.value) {
                .set_type => |bv| {
                    const allocator = std.heap.page_allocator;
                    var res_set = @import("set.zig").Set.init(allocator);
                    for (av.items.items) |elem| {
                        var in_b = false;
                        for (bv.items.items) |belem| {
                            if (elem.eq(belem).toBool()) { in_b = true; break; }
                        }
                        if (!in_b) res_set.add(allocator, elem) catch unreachable;
                    }
                    return Dynamic{ .value = .{ .set_type = res_set } };
                },
                else => std.debug.panic("TypeError: unsupported operand type(s) for -: 'set' and '{s}'\n", .{@tagName(b.value)}),
            }
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for -\n", .{}),
    }
}

pub fn mul(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMath(a.value.py_obj_type.?, b, "*") catch std.debug.panic("Python ABI Math Error for *\n", .{});
    }
    if (b.value == .py_obj_type) {
        return @import("python_abi.zig").sundapyBridge.doMathReverse(a, b.value.py_obj_type.?, "*") catch std.debug.panic("Python ABI Math Error for *\n", .{});
    }

    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initInt(av * bv),
                .float_type => |bv| return Dynamic.initFloat(@as(f64, @floatFromInt(av)) * bv),
                .list_type => |bv| return repeatList(bv.items.items, av),
                .tuple_type => |tv| return repeatTuple(tv.items, av),
                .str_type => |sv| return repeatStr(sv, av),
                .bytes_type => |bv| return repeatBytes(bv, av),
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
            if (b.value == .i64_type) return repeatList(lv.items.items, b.value.i64_type);
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        .tuple_type => |tv| {
            if (b.value == .i64_type) return repeatTuple(tv.items, b.value.i64_type);
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        .str_type => |sv| {
            if (b.value == .i64_type) return repeatStr(sv, b.value.i64_type);
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        .bytes_type => |bv| {
            if (b.value == .i64_type) return repeatBytes(bv, b.value.i64_type);
            std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{});
        },
        else => std.debug.panic("TypeError: unsupported operand type(s) for *\n", .{}),
    }
}

fn repeatList(items: []const Dynamic, count_i64: i64) Dynamic {
    const count = @max(0, count_i64);
    const allocator = std.heap.page_allocator;
    var new_list = std.ArrayList(Dynamic).empty;
    const total_len = items.len * @as(usize, @intCast(count));
    new_list.ensureTotalCapacity(allocator, total_len) catch unreachable;
    var rep: usize = 0;
    while (rep < count) : (rep += 1) {
        new_list.appendSlice(allocator, items) catch unreachable;
    }
    return Dynamic.initList(new_list);
}

fn repeatTuple(items: []const Dynamic, count_i64: i64) Dynamic {
    const count = @max(0, count_i64);
    const allocator = std.heap.page_allocator;
    const total_len = items.len * @as(usize, @intCast(count));
    var new_items = allocator.alloc(Dynamic, total_len) catch unreachable;
    var rep: usize = 0;
    while (rep < count) : (rep += 1) {
        @memcpy(new_items[rep * items.len .. (rep + 1) * items.len], items);
    }
    return Dynamic{ .value = .{ .tuple_type = .{ .items = new_items, .allocator = allocator } } };
}

fn repeatStr(sv: []const u8, count_i64: i64) Dynamic {
    const count = @max(0, count_i64);
    const allocator = std.heap.page_allocator;
    const total_len = sv.len * @as(usize, @intCast(count));
    var new_str = allocator.alloc(u8, total_len) catch unreachable;
    var rep: usize = 0;
    while (rep < count) : (rep += 1) {
        @memcpy(new_str[rep * sv.len .. (rep + 1) * sv.len], sv);
    }
    return Dynamic{ .value = .{ .str_type = new_str } };
}

fn repeatBytes(bv: []const u8, count_i64: i64) Dynamic {
    const count = @max(0, count_i64);
    const allocator = std.heap.page_allocator;
    const total_len = bv.len * @as(usize, @intCast(count));
    var new_bytes = allocator.alloc(u8, total_len) catch unreachable;
    var rep: usize = 0;
    while (rep < count) : (rep += 1) {
        @memcpy(new_bytes[rep * bv.len .. (rep + 1) * bv.len], bv);
    }
    return Dynamic{ .value = .{ .bytes_type = new_bytes } };
}

pub const div = @import("dynamic_ops_div.zig").div;
pub const floorDiv = @import("dynamic_ops_div.zig").floorDiv;
pub const mod = @import("dynamic_ops_div.zig").mod;

pub const eq = @import("dynamic_ops_cmp.zig").eq;
pub const neq = @import("dynamic_ops_cmp.zig").neq;
pub const lt = @import("dynamic_ops_cmp.zig").lt;
pub const gt = @import("dynamic_ops_cmp.zig").gt;
pub const le = @import("dynamic_ops_cmp.zig").le;
pub const ge = @import("dynamic_ops_cmp.zig").ge;
pub const contains = @import("dynamic_ops_cmp.zig").contains;
pub const notContains = @import("dynamic_ops_cmp.zig").notContains;

pub const pow = @import("dynamic_ops_bitwise.zig").pow;
pub const bitAnd = @import("dynamic_ops_bitwise.zig").bitAnd;
pub const bitOr = @import("dynamic_ops_bitwise.zig").bitOr;
pub const bitXor = @import("dynamic_ops_bitwise.zig").bitXor;
pub const shl = @import("dynamic_ops_bitwise.zig").shl;
pub const shr = @import("dynamic_ops_bitwise.zig").shr;
pub const bitNot = @import("dynamic_ops_bitwise.zig").bitNot;

pub const isTruthy = @import("dynamic_ops_logic.zig").isTruthy;
pub const logicAnd = @import("dynamic_ops_logic.zig").logicAnd;
pub const logicOr = @import("dynamic_ops_logic.zig").logicOr;
pub const logicNot = @import("dynamic_ops_logic.zig").logicNot;
pub const neg = @import("dynamic_ops_logic.zig").neg;
pub const pos = @import("dynamic_ops_logic.zig").pos;
