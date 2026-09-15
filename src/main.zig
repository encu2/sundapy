const std = @import("std");

fn getTimeNs() isize {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts);
    return ts.sec * 1000000000 + ts.nsec;
}



pub fn main(ctx: std.process.Init) !void {
    return @import("cli/runner.zig").main(ctx);
}
