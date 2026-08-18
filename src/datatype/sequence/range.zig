const std = @import("std");

pub const Range = struct {
    start: i64,
    stop: i64,
    step: i64,

    pub fn init(start: i64, stop: i64, step: i64) Range {
        return .{
            .start = start,
            .stop = stop,
            .step = step,
        };
    }
};
