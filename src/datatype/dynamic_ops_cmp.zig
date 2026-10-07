const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn eq(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        if (a.value.py_obj_type) |p| return Dynamic.initBool(@import("python_abi.zig").PikaPython.compare(p, b, 2));
        return Dynamic.initBool(false);
    }
    if (b.value == .py_obj_type) {
        if (b.value.py_obj_type) |p| return Dynamic.initBool(@import("python_abi.zig").PikaPython.compare(p, a, 2));
        return Dynamic.initBool(false);
    }
    switch (a.value) {
        .bool_type => |av| {
            switch (b.value) {
                .bool_type => |bv| return Dynamic.initBool(av == bv),
                .i64_type => |bv| return Dynamic.initBool((if (av) @as(i64, 1) else @as(i64, 0)) == bv),
                else => return Dynamic.initBool(false),
            }
        },
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av == bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) == bv),
                .bool_type => |bv| return Dynamic.initBool(av == (if (bv) @as(i64, 1) else @as(i64, 0))),
                else => return Dynamic.initBool(false),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .float_type => |bv| return Dynamic.initBool(av == bv),
                .i64_type => |bv| return Dynamic.initBool(av == @as(f64, @floatFromInt(bv))),
                else => return Dynamic.initBool(false),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| return Dynamic.initBool(std.mem.eql(u8, av, bv)),
                .bytes_type => |bv| return Dynamic.initBool(std.mem.eql(u8, av, bv)),
                else => return Dynamic.initBool(false),
            }
        },
        .bytes_type => |av| {
            switch (b.value) {
                .bytes_type => |bv| return Dynamic.initBool(std.mem.eql(u8, av, bv)),
                .str_type => |bv| return Dynamic.initBool(std.mem.eql(u8, av, bv)),
                else => return Dynamic.initBool(false),
            }
        },
        .none_type => {
            switch (b.value) {
                .none_type => return Dynamic.initBool(true),
                else => return Dynamic.initBool(false),
            }
        },
        .py_obj_type => |obj| {
            if (obj) |p| return Dynamic.initBool(@import("python_abi.zig").PikaPython.compare(p, b, 2));
            return Dynamic.initBool(false);
        },
        .list_type => |av| {
            switch (b.value) {
                .list_type => |bv| {
                    if (av.items.items.len != bv.items.items.len) return Dynamic.initBool(false);
                    for (av.items.items, bv.items.items) |elem_a, elem_b| {
                        if (!eq(elem_a, elem_b).toBool()) return Dynamic.initBool(false);
                    }
                    return Dynamic.initBool(true);
                },
                else => return Dynamic.initBool(false),
            }
        },
        .tuple_type => |av| {
            switch (b.value) {
                .tuple_type => |bv| {
                    if (av.items.len != bv.items.len) return Dynamic.initBool(false);
                    for (av.items, bv.items) |elem_a, elem_b| {
                        if (!eq(elem_a, elem_b).toBool()) return Dynamic.initBool(false);
                    }
                    return Dynamic.initBool(true);
                },
                else => return Dynamic.initBool(false),
            }
        },
        else => return Dynamic.initBool(false),
    }
}

pub fn neq(a: Dynamic, b: Dynamic) Dynamic {
    const res = eq(a, b);
    return Dynamic.initBool(!res.value.bool_type);
}

pub fn lt(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av < bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) < bv),
                else => std.debug.panic("TypeError: '<' not supported between instances\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av < @as(f64, @floatFromInt(bv))),
                .float_type => |bv| return Dynamic.initBool(av < bv),
                else => std.debug.panic("TypeError: '<' not supported between instances\n", .{}),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| return Dynamic.initBool(std.mem.lessThan(u8, av, bv)),
                else => std.debug.panic("TypeError: '<' not supported between instances\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: '<' not supported between instances\n", .{}),
    }
}

pub fn gt(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av > bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) > bv),
                else => std.debug.panic("TypeError: '>' not supported between instances\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av > @as(f64, @floatFromInt(bv))),
                .float_type => |bv| return Dynamic.initBool(av > bv),
                else => std.debug.panic("TypeError: '>' not supported between instances\n", .{}),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| return Dynamic.initBool(std.mem.lessThan(u8, bv, av)),
                else => std.debug.panic("TypeError: '>' not supported between instances\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: '>' not supported between instances\n", .{}),
    }
}

pub fn le(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av <= bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) <= bv),
                else => std.debug.panic("TypeError: '<=' not supported between instances\n", .{}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av <= @as(f64, @floatFromInt(bv))),
                .float_type => |bv| return Dynamic.initBool(av <= bv),
                else => std.debug.panic("TypeError: '<=' not supported between instances\n", .{}),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| return Dynamic.initBool(std.mem.lessThan(u8, av, bv) or std.mem.eql(u8, av, bv)),
                else => std.debug.panic("TypeError: '<=' not supported between instances\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: '<=' not supported between instances\n", .{}),
    }
}

pub fn ge(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av >= bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) >= bv),
                else => std.debug.panic("TypeError: '>=' not supported between instances of '{s}' and '{s}'\n", .{@tagName(a.value), @tagName(b.value)}),
            }
        },
        .float_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av >= @as(f64, @floatFromInt(bv))),
                .float_type => |bv| return Dynamic.initBool(av >= bv),
                else => std.debug.panic("TypeError: '>=' not supported between instances of '{s}' and '{s}'\n", .{@tagName(a.value), @tagName(b.value)}),
            }
        },
        .str_type => |av| {
            switch (b.value) {
                .str_type => |bv| return Dynamic.initBool(std.mem.lessThan(u8, bv, av) or std.mem.eql(u8, av, bv)),
                else => std.debug.panic("TypeError: '>=' not supported between instances of '{s}' and '{s}'\n", .{@tagName(a.value), @tagName(b.value)}),
            }
        },
        else => std.debug.panic("TypeError: '>=' not supported between instances of '{s}' and '{s}'\n", .{@tagName(a.value), @tagName(b.value)}),
    }
}

pub fn contains(collection: Dynamic, item: Dynamic) Dynamic {
    switch (collection.value) {
        .list_type => |lv| {
            for (lv.items.items) |elem| {
                if (eq(elem, item).toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        },
        .tuple_type => |tv| {
            for (tv.items) |elem| {
                if (eq(elem, item).toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        },
        .str_type => |sv| {
            if (item.value == .str_type) {
                if (std.mem.indexOf(u8, sv, item.value.str_type) != null) return Dynamic.initBool(true);
                return Dynamic.initBool(false);
            }
            return Dynamic.initBool(false);
        },
        .dict_type => |dv| {
            var it = dv.map.keyIterator();
            while (it.next()) |k| {
                if (item.value == .str_type and std.mem.eql(u8, k.*, item.value.str_type)) {
                    return Dynamic.initBool(true);
                }
            }
            return Dynamic.initBool(false);
        },
        .set_type => |sv| {
            for (sv.items.items) |elem| {
                if (eq(elem, item).toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        },
        else => return Dynamic.initBool(false),
    }
}

pub fn notContains(collection: Dynamic, item: Dynamic) Dynamic {
    return Dynamic.initBool(!contains(collection, item).toBool());
}
