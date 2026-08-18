const std = @import("std");

/// In Python, bool is a subclass of int. 
/// True + True == 2.
pub fn to_int(val: bool) i64 {
    return if (val) 1 else 0;
}
