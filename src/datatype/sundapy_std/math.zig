const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const pi = Dynamic.initFloat(std.math.pi);
pub const e = Dynamic.initFloat(std.math.e);
pub const tau = Dynamic.initFloat(std.math.tau);
pub const inf = Dynamic.initFloat(std.math.inf(f64));
pub const nan = Dynamic.initFloat(std.math.nan(f64));

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

pub fn asin(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val < -1.0 or val > 1.0) return error.ValueError;
    return Dynamic.initFloat(std.math.asin(val));
}

pub fn acos(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val < -1.0 or val > 1.0) return error.ValueError;
    return Dynamic.initFloat(std.math.acos(val));
}

pub fn atan(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.atan(toF64(x)));
}

pub fn atan2(y: Dynamic, x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.atan2(toF64(y), toF64(x)));
}

pub fn sinh(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.sinh(toF64(x)));
}

pub fn cosh(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.cosh(toF64(x)));
}

pub fn tanh(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.tanh(toF64(x)));
}

pub fn asinh(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.asinh(toF64(x)));
}

pub fn acosh(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val < 1.0) return error.ValueError;
    return Dynamic.initFloat(std.math.acosh(val));
}

pub fn atanh(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val <= -1.0 or val >= 1.0) return error.ValueError;
    return Dynamic.initFloat(std.math.atanh(val));
}

pub fn sqrt(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val < 0.0) return error.ValueError;
    return Dynamic.initFloat(@sqrt(val));
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

pub fn trunc(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@trunc(toF64(x)));
}

pub fn round(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@round(toF64(x)));
}

pub fn radians(deg: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(toF64(deg) * (std.math.pi / 180.0));
}

pub fn degrees(rad: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(toF64(rad) * (180.0 / std.math.pi));
}

pub fn exp(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@exp(toF64(x)));
}

pub fn log(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val <= 0.0) return error.ValueError;
    return Dynamic.initFloat(@log(val));
}

pub fn log2(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val <= 0.0) return error.ValueError;
    return Dynamic.initFloat(@log2(val));
}

pub fn log10(x: Dynamic) anyerror!Dynamic {
    const val = toF64(x);
    if (val <= 0.0) return error.ValueError;
    return Dynamic.initFloat(@log10(val));
}

pub fn fabs(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(@abs(toF64(x)));
}

pub fn hypot(x: Dynamic, y: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.hypot(toF64(x), toF64(y)));
}

pub fn copysign(x: Dynamic, y: Dynamic) anyerror!Dynamic {
    return Dynamic.initFloat(std.math.copysign(toF64(x), toF64(y)));
}

pub fn fmod(x: Dynamic, y: Dynamic) anyerror!Dynamic {
    const vy = toF64(y);
    if (vy == 0.0) return error.ZeroDivisionError;
    return Dynamic.initFloat(@mod(toF64(x), vy));
}

pub fn isnan(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initBool(std.math.isNan(toF64(x)));
}

pub fn isinf(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initBool(std.math.isInf(toF64(x)));
}

pub fn isfinite(x: Dynamic) anyerror!Dynamic {
    return Dynamic.initBool(std.math.isFinite(toF64(x)));
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}

pub const math_int = @import("math_integer.zig");
pub const gcd = math_int.gcd;
pub const lcm = math_int.lcm;
pub const isqrt = math_int.isqrt;
pub const comb = math_int.binomial;
pub const binomial = math_int.binomial;
pub const factorial = math_int.factorial;
pub const popcount = math_int.popcount;
pub const bit_length = math_int.bit_length;

fn gcd_dyn(a: Dynamic, b: Dynamic) anyerror!Dynamic { return @import("math_integer.zig").gcd(a, b); }
fn lcm_dyn(a: Dynamic, b: Dynamic) anyerror!Dynamic { return @import("math_integer.zig").lcm(a, b); }
fn isqrt_dyn(n: Dynamic) anyerror!Dynamic { return @import("math_integer.zig").isqrt(n); }
fn binomial_dyn(n: Dynamic, k: Dynamic) anyerror!Dynamic { return @import("math_integer.zig").binomial(n, k); }
fn factorial_dyn(n: Dynamic) anyerror!Dynamic { return @import("math_integer.zig").factorial(n); }

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "sin")) return @import("datatype/dynamic.zig").toDynamicFunc(sin);
    if (std.mem.eql(u8, attr, "cos")) return @import("datatype/dynamic.zig").toDynamicFunc(cos);
    if (std.mem.eql(u8, attr, "tan")) return @import("datatype/dynamic.zig").toDynamicFunc(tan);
    if (std.mem.eql(u8, attr, "asin")) return @import("datatype/dynamic.zig").toDynamicFunc(asin);
    if (std.mem.eql(u8, attr, "acos")) return @import("datatype/dynamic.zig").toDynamicFunc(acos);
    if (std.mem.eql(u8, attr, "atan")) return @import("datatype/dynamic.zig").toDynamicFunc(atan);
    if (std.mem.eql(u8, attr, "atan2")) return @import("datatype/dynamic.zig").toDynamicFunc(atan2);
    if (std.mem.eql(u8, attr, "sinh")) return @import("datatype/dynamic.zig").toDynamicFunc(sinh);
    if (std.mem.eql(u8, attr, "cosh")) return @import("datatype/dynamic.zig").toDynamicFunc(cosh);
    if (std.mem.eql(u8, attr, "tanh")) return @import("datatype/dynamic.zig").toDynamicFunc(tanh);
    if (std.mem.eql(u8, attr, "asinh")) return @import("datatype/dynamic.zig").toDynamicFunc(asinh);
    if (std.mem.eql(u8, attr, "acosh")) return @import("datatype/dynamic.zig").toDynamicFunc(acosh);
    if (std.mem.eql(u8, attr, "atanh")) return @import("datatype/dynamic.zig").toDynamicFunc(atanh);
    if (std.mem.eql(u8, attr, "sqrt")) return @import("datatype/dynamic.zig").toDynamicFunc(sqrt);
    if (std.mem.eql(u8, attr, "pow")) return @import("datatype/dynamic.zig").toDynamicFunc(pow);
    if (std.mem.eql(u8, attr, "floor")) return @import("datatype/dynamic.zig").toDynamicFunc(floor);
    if (std.mem.eql(u8, attr, "ceil")) return @import("datatype/dynamic.zig").toDynamicFunc(ceil);
    if (std.mem.eql(u8, attr, "trunc")) return @import("datatype/dynamic.zig").toDynamicFunc(trunc);
    if (std.mem.eql(u8, attr, "round")) return @import("datatype/dynamic.zig").toDynamicFunc(round);
    if (std.mem.eql(u8, attr, "radians")) return @import("datatype/dynamic.zig").toDynamicFunc(radians);
    if (std.mem.eql(u8, attr, "degrees")) return @import("datatype/dynamic.zig").toDynamicFunc(degrees);
    if (std.mem.eql(u8, attr, "exp")) return @import("datatype/dynamic.zig").toDynamicFunc(exp);
    if (std.mem.eql(u8, attr, "log")) return @import("datatype/dynamic.zig").toDynamicFunc(log);
    if (std.mem.eql(u8, attr, "log2")) return @import("datatype/dynamic.zig").toDynamicFunc(log2);
    if (std.mem.eql(u8, attr, "log10")) return @import("datatype/dynamic.zig").toDynamicFunc(log10);
    if (std.mem.eql(u8, attr, "fabs")) return @import("datatype/dynamic.zig").toDynamicFunc(fabs);
    if (std.mem.eql(u8, attr, "hypot")) return @import("datatype/dynamic.zig").toDynamicFunc(hypot);
    if (std.mem.eql(u8, attr, "copysign")) return @import("datatype/dynamic.zig").toDynamicFunc(copysign);
    if (std.mem.eql(u8, attr, "fmod")) return @import("datatype/dynamic.zig").toDynamicFunc(fmod);
    if (std.mem.eql(u8, attr, "isnan")) return @import("datatype/dynamic.zig").toDynamicFunc(isnan);
    if (std.mem.eql(u8, attr, "isinf")) return @import("datatype/dynamic.zig").toDynamicFunc(isinf);
    if (std.mem.eql(u8, attr, "gcd")) return @import("datatype/dynamic.zig").toDynamicFunc(gcd_dyn);
    if (std.mem.eql(u8, attr, "lcm")) return @import("datatype/dynamic.zig").toDynamicFunc(lcm_dyn);
    if (std.mem.eql(u8, attr, "isqrt")) return @import("datatype/dynamic.zig").toDynamicFunc(isqrt_dyn);
    if (std.mem.eql(u8, attr, "comb") or std.mem.eql(u8, attr, "binomial")) return @import("datatype/dynamic.zig").toDynamicFunc(binomial_dyn);
    if (std.mem.eql(u8, attr, "factorial")) return @import("datatype/dynamic.zig").toDynamicFunc(factorial_dyn);
    if (std.mem.eql(u8, attr, "pi")) return pi;
    if (std.mem.eql(u8, attr, "e")) return e;
    if (std.mem.eql(u8, attr, "tau")) return tau;
    if (std.mem.eql(u8, attr, "inf")) return inf;
    if (std.mem.eql(u8, attr, "nan")) return nan;
    return error.AttributeError;
}
