const std = @import("std");

pub const LOCAL_VAL: i32 = 12345;

pub fn local_double(x: i32) i32 {
    return x * 2;
}

pub fn local_str() []const u8 {
    return "local zig module";
}
