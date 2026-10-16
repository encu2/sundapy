const std = @import("std");

pub const PI: f64 = 3.141592653589793;
pub const ANSWER: i32 = 42;
pub const GREETING: []const u8 = "Hello from Zig!";

pub fn add_i32(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply_f64(a: f64, b: f64) f64 {
    return a * b;
}

pub fn get_message() []const u8 {
    return "Message from Zig function";
}

pub const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn sum(self: Point) i32 {
        return self.x + self.y;
    }

    pub fn fallible_sum(self: Point) !i32 {
        if (self.x < 0) return error.NegativeValue;
        return self.x + self.y;
    }
};

pub fn create_point(x: i32, y: i32) Point {
    return Point.init(x, y);
}

pub const Geometry = struct {
    pub const Vector2 = struct {
        x: i32,
        y: i32,

        pub fn init(x: i32, y: i32) Vector2 {
            return .{ .x = x, .y = y };
        }

        pub fn dot(self: Vector2, other: Vector2) i32 {
            return self.x * other.x + self.y * other.y;
        }
    };
};
