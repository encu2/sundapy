const std = @import("std");
const Dynamic = @import("datatype/dynamic.zig").Dynamic;

pub fn sleep(seconds: Dynamic) anyerror!Dynamic {
    var ts: std.os.linux.timespec = undefined;
    if (seconds.value == .i64_type) {
        ts.sec = @intCast(seconds.value.i64_type);
        ts.nsec = 0;
    } else if (seconds.value == .float_type) {
        const ms: u64 = @intFromFloat(seconds.value.float_type * 1_000.0);
        ts.sec = @intCast(ms / 1000);
        ts.nsec = @intCast((ms % 1000) * 1_000_000);
    } else {
        ts.sec = 0;
        ts.nsec = 0;
    }
    _ = std.os.linux.nanosleep(&ts, null);
    return Dynamic.initNone();
}

pub fn builtin_getattr(name: []const u8) Dynamic {
    if (std.mem.eql(u8, name, "sleep")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(sleep);
    }
    if (std.mem.eql(u8, name, "time_ns")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(time_ns);
    }
    return Dynamic.initNone();
}

pub fn time_ns() anyerror!Dynamic {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts);
    const ns = @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
    return Dynamic{ .value = .{ .i64_type = ns } };
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
