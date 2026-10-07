const std = @import("std");

pub const Point = extern struct {
    x: i32,
    y: i32,
};

export fn add_i32(a: i32, b: i32) callconv(.c) i32 {
    return a + b;
}

export fn mul_i64(a: i64, b: i64) callconv(.c) i64 {
    return a * b;
}

export fn add_f64(a: f64, b: f64) callconv(.c) f64 {
    return a + b;
}

export fn square_f64(x: f64) callconv(.c) f64 {
    return x * x;
}

export fn point_sum(p: *const Point) callconv(.c) i32 {
    return p.x + p.y;
}

export fn str_len(s: [*c]const u8) callconv(.c) i32 {
    var len: i32 = 0;
    while (s[@intCast(len)] != 0) : (len += 1) {}
    return len;
}
