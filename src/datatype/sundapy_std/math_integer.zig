const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

fn toI64(d: anytype) i64 {
    const T = @TypeOf(d);
    if (T == Dynamic) {
        return switch (d.value) {
            .i64_type => |i| i,
            .i32_type => |i| @intCast(i),
            .u32_type => |u| @intCast(u),
            .u64_type => |u| @intCast(u),
            .float_type => |f| @intFromFloat(f),
            else => 0,
        };
    }
    if (T == comptime_int or @typeInfo(T) == .int) return @as(i64, @intCast(d));
    if (T == comptime_float or @typeInfo(T) == .float) return @as(i64, @intFromFloat(d));
    return 0;
}

pub fn gcd(a: anytype, b: anytype) anyerror!Dynamic {
    const val_a: u64 = @intCast(@abs(toI64(a)));
    const val_b: u64 = @intCast(@abs(toI64(b)));
    const res = std.math.gcd(val_a, val_b);
    return Dynamic.initInt(@intCast(res));
}

pub fn lcm(a: anytype, b: anytype) anyerror!Dynamic {
    const val_a: u64 = @intCast(@abs(toI64(a)));
    const val_b: u64 = @intCast(@abs(toI64(b)));
    if (val_a == 0 or val_b == 0) return Dynamic.initInt(0);
    const g = std.math.gcd(val_a, val_b);
    const res = (val_a / g) * val_b;
    return Dynamic.initInt(@intCast(res));
}

pub fn isqrt(n: anytype) anyerror!Dynamic {
    const val = toI64(n);
    if (val < 0) return error.ValueError;
    if (val == 0) return Dynamic.initInt(0);
    const u: u64 = @intCast(val);
    const res = std.math.sqrt(u);
    return Dynamic.initInt(@intCast(res));
}

pub fn popcount(n: anytype) anyerror!Dynamic {
    const val = toI64(n);
    const u: u64 = @bitCast(val);
    const count: i64 = @intCast(@popCount(u));
    return Dynamic.initInt(count);
}

pub fn bit_length(n: anytype) anyerror!Dynamic {
    const val = toI64(n);
    if (val == 0) return Dynamic.initInt(0);
    const u: u64 = @intCast(@abs(val));
    const leading: i64 = @intCast(@clz(u));
    return Dynamic.initInt(64 - leading);
}

pub fn factorial(n: anytype) anyerror!Dynamic {
    const val = toI64(n);
    if (val < 0) return error.ValueError;
    if (val <= 1) return Dynamic.initInt(1);
    var acc: i64 = 1;
    var i: i64 = 2;
    while (i <= val) : (i += 1) {
        acc *%= i;
    }
    return Dynamic.initInt(acc);
}

pub fn binomial(n: anytype, k: anytype) anyerror!Dynamic {
    const n_val = toI64(n);
    var k_val = toI64(k);
    if (k_val < 0 or k_val > n_val) return Dynamic.initInt(0);
    if (k_val == 0 or k_val == n_val) return Dynamic.initInt(1);
    if (k_val > n_val - k_val) k_val = n_val - k_val;
    var c: i64 = 1;
    var i: i64 = 0;
    while (i < k_val) : (i += 1) {
        c = @divExact(c *% (n_val - i), (i + 1));
    }
    return Dynamic.initInt(c);
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "gcd")) return @import("datatype/dynamic.zig").toDynamicFunc(gcd);
    if (std.mem.eql(u8, attr, "lcm")) return @import("datatype/dynamic.zig").toDynamicFunc(lcm);
    if (std.mem.eql(u8, attr, "isqrt")) return @import("datatype/dynamic.zig").toDynamicFunc(isqrt);
    if (std.mem.eql(u8, attr, "popcount") or std.mem.eql(u8, attr, "bit_count")) return @import("datatype/dynamic.zig").toDynamicFunc(popcount);
    if (std.mem.eql(u8, attr, "bit_length")) return @import("datatype/dynamic.zig").toDynamicFunc(bit_length);
    if (std.mem.eql(u8, attr, "factorial")) return @import("datatype/dynamic.zig").toDynamicFunc(factorial);
    if (std.mem.eql(u8, attr, "binomial") or std.mem.eql(u8, attr, "comb")) return @import("datatype/dynamic.zig").toDynamicFunc(binomial);
    return error.AttributeError;
}
