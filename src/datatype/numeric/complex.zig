const std = @import("std");

/// Provides Python's complex.conjugate() functionality
pub fn conjugate(val: std.math.Complex(f64)) std.math.Complex(f64) {
    return std.math.Complex(f64).init(val.re, -val.im);
}
