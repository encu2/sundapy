const std = @import("std");

// Boolean and None types are natively handled by Zig's `bool` and `void` (or `null`).
// This directory acts as an aggregator if future methods need to be attached 
// to Python's bool or None objects.

pub const bool_type = @import("bool.zig");
