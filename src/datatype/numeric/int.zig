const std = @import("std");

/// Provides Python's int.bit_length() functionality for any int type
pub fn bit_length(val: anytype) u64 {
    const T = @TypeOf(val);
    const info = @typeInfo(T);
    if (info != .int) @compileError("bit_length expects an integer");
    
    if (val == 0) return 0;
    const abs_val = @abs(val);
    const bit_width = info.int.bits;
    return bit_width - @clz(abs_val);
}

/// Provides Python's int.bit_count() functionality for any int type
pub fn bit_count(val: anytype) u64 {
    const T = @TypeOf(val);
    if (@typeInfo(T) != .int) @compileError("bit_count expects an integer");
    
    const abs_val = @abs(val);
    return @popCount(abs_val);
}

