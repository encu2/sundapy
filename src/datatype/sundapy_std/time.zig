const std = @import("std");
const dynamic = @import("dynamic");
const Dynamic = dynamic.Dynamic;

pub fn time_ns() !i64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts);
    return @as(i64, ts.sec) * 1000000000 + @as(i64, ts.nsec);
}
