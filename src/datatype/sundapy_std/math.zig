const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const pi = Dynamic.initFloat(std.math.pi);
pub const e = Dynamic.initFloat(std.math.e);
pub const tau = Dynamic.initFloat(std.math.tau);

fn toF64(d: Dynamic) f64 {
    return switch (d.value) {
        .float_type => |f| f,
        .i64_type => |i| @floatFromInt(i),
        .i32_type => |i| @floatFromInt(i),
        .u32_type => |u| @floatFromInt(u),
        .u64_type => |u| @floatFromInt(u),
        else => 0.0,
    };
}

pub fn sin(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@sin(toF64(x)));
}

pub fn cos(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@cos(toF64(x)));
}

pub fn tan(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@tan(toF64(x)));
}

pub fn sqrt(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val < 0.0) return error.ValueError;
    return Dynamic.initFloat(@sqrt(val));
}

pub fn atan2(y: Dynamic, x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.atan2(toF64(y), toF64(x)));
}

pub fn pow(x: Dynamic, y: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.pow(f64, toF64(x), toF64(y)));
}

pub fn floor(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@floor(toF64(x)));
}

pub fn ceil(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@ceil(toF64(x)));
}

pub fn radians(deg: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(toF64(deg) * (std.math.pi / 180.0));
}

pub fn degrees(rad: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(toF64(rad) * (180.0 / std.math.pi));
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}

pub fn builtin_getattr(_: *const @This(), attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "sin")) return @import("datatype/dynamic.zig").toDynamicFunc(sin);
    if (std.mem.eql(u8, attr, "cos")) return @import("datatype/dynamic.zig").toDynamicFunc(cos);
    if (std.mem.eql(u8, attr, "tan")) return @import("datatype/dynamic.zig").toDynamicFunc(tan);
    if (std.mem.eql(u8, attr, "sqrt")) return @import("datatype/dynamic.zig").toDynamicFunc(sqrt);
    if (std.mem.eql(u8, attr, "atan2")) return @import("datatype/dynamic.zig").toDynamicFunc(atan2);
    if (std.mem.eql(u8, attr, "pow")) return @import("datatype/dynamic.zig").toDynamicFunc(pow);
    if (std.mem.eql(u8, attr, "floor")) return @import("datatype/dynamic.zig").toDynamicFunc(floor);
    if (std.mem.eql(u8, attr, "ceil")) return @import("datatype/dynamic.zig").toDynamicFunc(ceil);
    if (std.mem.eql(u8, attr, "radians")) return @import("datatype/dynamic.zig").toDynamicFunc(radians);
    if (std.mem.eql(u8, attr, "degrees")) return @import("datatype/dynamic.zig").toDynamicFunc(degrees);
    if (std.mem.eql(u8, attr, "pi")) return pi;
    if (std.mem.eql(u8, attr, "e")) return e;
    if (std.mem.eql(u8, attr, "tau")) return tau;
    return error.AttributeError;
}
