const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub const TYPE_VOID: u8 = 0;
pub const TYPE_I8: u8 = 1;
pub const TYPE_I16: u8 = 2;
pub const TYPE_I32: u8 = 3;
pub const TYPE_I64: u8 = 4;
pub const TYPE_U8: u8 = 5;
pub const TYPE_U16: u8 = 6;
pub const TYPE_U32: u8 = 7;
pub const TYPE_U64: u8 = 8;
pub const TYPE_F32: u8 = 9;
pub const TYPE_F64: u8 = 10;
pub const TYPE_BOOL: u8 = 11;
pub const TYPE_C_STR: u8 = 12;
pub const TYPE_PTR: u8 = 13;
pub const TYPE_STRUCT: u8 = 14;

pub const TYPE_NAMES = [_][]const u8{
    "void", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64",
    "f32", "f64", "bool", "c_str", "ptr", "struct",
};

pub fn parseTypeId(val: Dynamic) u8 {
    switch (val.value) {
        .i64_type => |i| {
            if (i >= 0 and i < TYPE_NAMES.len) return @intCast(i);
            return TYPE_VOID;
        },
        .str_type => |s| {
            for (TYPE_NAMES, 0..) |name, idx| {
                if (std.mem.eql(u8, s, name)) return @intCast(idx);
            }
            if (std.mem.eql(u8, s, "int") or std.mem.eql(u8, s, "long")) return TYPE_I64;
            if (std.mem.eql(u8, s, "short")) return TYPE_I16;
            if (std.mem.eql(u8, s, "char")) return TYPE_I8;
            if (std.mem.eql(u8, s, "float")) return TYPE_F32;
            if (std.mem.eql(u8, s, "double")) return TYPE_F64;
            if (std.mem.eql(u8, s, "str") or std.mem.eql(u8, s, "string")) return TYPE_C_STR;
            if (std.mem.eql(u8, s, "bytes") or std.mem.eql(u8, s, "pointer")) return TYPE_PTR;
            return TYPE_VOID;
        },
        else => return TYPE_VOID,
    }
}

pub fn typeSize(type_id: u8) usize {
    return switch (type_id) {
        TYPE_VOID => 0,
        TYPE_I8, TYPE_U8, TYPE_BOOL => 1,
        TYPE_I16, TYPE_U16 => 2,
        TYPE_I32, TYPE_U32, TYPE_F32 => 4,
        TYPE_I64, TYPE_U64, TYPE_F64, TYPE_C_STR, TYPE_PTR => 8,
        else => 8,
    };
}

pub fn typeAlign(type_id: u8) usize {
    return switch (type_id) {
        TYPE_VOID => 1,
        TYPE_I8, TYPE_U8, TYPE_BOOL => 1,
        TYPE_I16, TYPE_U16 => 2,
        TYPE_I32, TYPE_U32, TYPE_F32 => 4,
        TYPE_I64, TYPE_U64, TYPE_F64, TYPE_C_STR, TYPE_PTR => 8,
        else => 8,
    };
}
