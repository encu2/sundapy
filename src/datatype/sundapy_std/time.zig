const std = @import("std");
const Dynamic = @import("datatype/dynamic.zig").Dynamic;

pub fn sleep(seconds: anytype) anyerror!Dynamic {
    const sec = dynamic_to_f64(Dynamic.fromAny(seconds));
    const ns = @as(u64, @intFromFloat(sec * 1e9));
    const req = std.os.linux.timespec{
        .sec = @as(isize, @intCast(ns / 1000000000)),
        .nsec = @as(isize, @intCast(ns % 1000000000)),
    };
    _ = std.os.linux.nanosleep(&req, null);
    return Dynamic.initNone();
}

pub fn time_ns() anyerror!i64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.REALTIME, &ts); // 0 is CLOCK_REALTIME
    const ns = @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
    return ns;
}

pub fn time_ns_dynamic() anyerror!Dynamic {
    const val = try time_ns();
    return Dynamic.initInt(val);
}

fn dynamic_to_f64(d: Dynamic) f64 {
    return switch (d.value) {
        .i64_type => |v| @floatFromInt(v),
        .float_type => |v| v,
        else => 0.0,
    };
}

pub fn time() anyerror!Dynamic {
    const ns = try time_ns();
    const sec = @as(f64, @floatFromInt(ns)) / 1e9;
    return Dynamic.initFloat(sec);
}

pub fn builtin_getattr(_: *const @This(), attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "sleep")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(sleep);
    }
    if (std.mem.eql(u8, attr, "time")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(time);
    }
    if (std.mem.eql(u8, attr, "time_ns")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(time_ns_dynamic);
    }
    return error.AttributeError;
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
