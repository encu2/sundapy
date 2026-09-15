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
        else => std.debug.panic("TypeError: '<=' not supported between instances\n", .{}),
    }
}

pub fn ge(a: Dynamic, b: Dynamic) Dynamic {
    switch (a.value) {
        .i64_type => |av| {
            switch (b.value) {
                .i64_type => |bv| return Dynamic.initBool(av >= bv),
                .float_type => |bv| return Dynamic.initBool(@as(f64, @floatFromInt(av)) >= bv),
                else => std.debug.panic("TypeError: '>=' not supported between instances\n", .{}),
            }
        },
        else => std.debug.panic("TypeError: '>=' not supported between instances\n", .{}),
    }
}
