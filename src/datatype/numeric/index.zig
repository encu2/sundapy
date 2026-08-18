const std = @import("std");

pub const int = @import("int.zig");
pub const float = @import("float.zig");
pub const complex = @import("complex.zig");

// Note: For memory efficiency, Transpiler translates Numeric types directly to Zig primitives (i64, f64).
// This module provides the Python-specific methods (like bit_length, hex) that 
// Zig primitives do not possess natively, ensuring 100% Python-like behavior.
