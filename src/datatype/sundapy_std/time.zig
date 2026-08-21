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

pub fn time_ns() anyerror!Dynamic {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.REALTIME, &ts); // 0 is CLOCK_REALTIME
    const ns = @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
    return Dynamic.initInt(ns);
}

fn dynamic_to_f64(d: Dynamic) f64 {
    return switch (d.value) {
        .i64_type => |v| @floatFromInt(v),
        .float_type => |v| v,
        else => 0.0,
    };
}

pub fn builtin_getattr(_: *const @This(), attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "sleep")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(sleep);
    }
    if (std.mem.eql(u8, attr, "time_ns")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(time_ns);
    }
    return error.AttributeError;
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
