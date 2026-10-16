const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn eq(a: Dynamic, b: Dynamic) Dynamic {
    if (a.value == .py_obj_type) {
        if (a.value.py_obj_type) |p| return Dynamic.initBool(@import("python_abi.zig").sundapyBridge.compare(p, b, 2));
        return Dynamic.initBool(false);
    }
    if (b.value == .py_obj_type) {
        if (b.value.py_obj_type) |p| return Dynamic.initBool(@import("python_abi.zig").sundapyBridge.compare(p, a, 2));
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
            if (obj) |p| return Dynamic.initBool(@import("python_abi.zig").sundapyBridge.compare(p, b, 2));
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
        .dict_type => |av| {
            switch (b.value) {
                .dict_type => |bv| {
                    if (av.count() != bv.count()) return Dynamic.initBool(false);
                    av.lock();
                    defer av.unlock();
                    var it = av.map.iterator();
                    while (it.next()) |entry| {
                        const val_b = bv.get(entry.value_ptr.key) orelse return Dynamic.initBool(false);
                        if (!eq(entry.value_ptr.value, val_b).toBool()) return Dynamic.initBool(false);
                    }
                    return Dynamic.initBool(true);

                },
                else => return Dynamic.initBool(false),
            }
        },
        .set_type => |av| {
            switch (b.value) {
                .set_type => |bv| {
                    if (av.items.items.len != bv.items.items.len) return Dynamic.initBool(false);
                    for (av.items.items) |elem_a| {
                        var found = false;
                        for (bv.items.items) |elem_b| {
                            if (eq(elem_a, elem_b).toBool()) { found = true; break; }
                        }
                        if (!found) return Dynamic.initBool(false);
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

inline fn isIntOrBool(d: Dynamic) bool {
    return switch (d.value) {
        .i64_type, .i32_type, .i16_type, .i8_type,
        .u64_type, .u32_type, .u16_type, .u8_type,
        .bool_type => true,
        else => false,
    };
}

inline fn isNumOrBool(d: Dynamic) bool {
    return isIntOrBool(d) or d.value == .float_type;
}

pub fn lt(a: Dynamic, b: Dynamic) Dynamic {
    if (isIntOrBool(a) and isIntOrBool(b)) return Dynamic.initBool(a.toInt() < b.toInt());
    if (isNumOrBool(a) and isNumOrBool(b)) return Dynamic.initBool(a.toFloat() < b.toFloat());
    if (a.value == .str_type and b.value == .str_type) return Dynamic.initBool(std.mem.lessThan(u8, a.value.str_type, b.value.str_type));
    std.debug.panic("TypeError: '<' not supported between instances\n", .{});
}

pub fn gt(a: Dynamic, b: Dynamic) Dynamic {
    if (isIntOrBool(a) and isIntOrBool(b)) return Dynamic.initBool(a.toInt() > b.toInt());
    if (isNumOrBool(a) and isNumOrBool(b)) return Dynamic.initBool(a.toFloat() > b.toFloat());
    if (a.value == .str_type and b.value == .str_type) return Dynamic.initBool(std.mem.lessThan(u8, b.value.str_type, a.value.str_type));
    std.debug.panic("TypeError: '>' not supported between instances\n", .{});
}

pub fn le(a: Dynamic, b: Dynamic) Dynamic {
    if (isIntOrBool(a) and isIntOrBool(b)) return Dynamic.initBool(a.toInt() <= b.toInt());
    if (isNumOrBool(a) and isNumOrBool(b)) return Dynamic.initBool(a.toFloat() <= b.toFloat());
    if (a.value == .str_type and b.value == .str_type) return Dynamic.initBool(std.mem.lessThan(u8, a.value.str_type, b.value.str_type) or std.mem.eql(u8, a.value.str_type, b.value.str_type));
    std.debug.panic("TypeError: '<=' not supported between instances\n", .{});
}

pub fn ge(a: Dynamic, b: Dynamic) Dynamic {
    if (isIntOrBool(a) and isIntOrBool(b)) return Dynamic.initBool(a.toInt() >= b.toInt());
    if (isNumOrBool(a) and isNumOrBool(b)) return Dynamic.initBool(a.toFloat() >= b.toFloat());
    if (a.value == .str_type and b.value == .str_type) return Dynamic.initBool(std.mem.lessThan(u8, b.value.str_type, a.value.str_type) or std.mem.eql(u8, a.value.str_type, b.value.str_type));
    std.debug.panic("TypeError: '>=' not supported between instances of '{s}' and '{s}'\n", .{@tagName(a.value), @tagName(b.value)});
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
            return Dynamic.initBool(dv.get(item) != null);
        },
        .set_type => |sv| {
            for (sv.items.items) |elem| {
                if (eq(elem, item).toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        },
        .frozenset_type => |fv| {
            for (fv.items) |elem| {
                if (eq(elem, item).toBool()) return Dynamic.initBool(true);
            }
            return Dynamic.initBool(false);
        },
        .range_type => |r| {
            if (item.value == .i64_type) {
                const val = item.value.i64_type;
                if (r.step > 0) {
                    if (val >= r.start and val < r.stop and @mod(val - r.start, r.step) == 0) return Dynamic.initBool(true);
                } else if (r.step < 0) {
                    if (val <= r.start and val > r.stop and @mod(r.start - val, -r.step) == 0) return Dynamic.initBool(true);
                }
            }
            return Dynamic.initBool(false);
        },
        else => return Dynamic.initBool(false),
    }
}

pub fn notContains(collection: Dynamic, item: Dynamic) Dynamic {
    return Dynamic.initBool(!contains(collection, item).toBool());
}
