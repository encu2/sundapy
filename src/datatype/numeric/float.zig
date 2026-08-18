const std = @import("std");

/// Provides Python's float.is_integer() functionality
pub fn is_integer(val: f64) bool {
    if (std.math.isNan(val) or std.math.isInf(val)) return false;
    return std.math.floor(val) == val;
}
