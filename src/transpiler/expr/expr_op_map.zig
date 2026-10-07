const std = @import("std");

pub fn mapOpToMethod(op: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, op, "+")) return "add";
    if (std.mem.eql(u8, op, "-")) return "sub";
    if (std.mem.eql(u8, op, "*")) return "mul";
    if (std.mem.eql(u8, op, "/")) return "div";
    if (std.mem.eql(u8, op, "//")) return "floorDiv";
    if (std.mem.eql(u8, op, "%")) return "mod";
    if (std.mem.eql(u8, op, "==")) return "eq";
    if (std.mem.eql(u8, op, "!=")) return "neq";
    if (std.mem.eql(u8, op, "is")) return "eq";
    if (std.mem.eql(u8, op, "is_not")) return "neq";
    if (std.mem.eql(u8, op, "<")) return "lt";
    if (std.mem.eql(u8, op, ">")) return "gt";
    if (std.mem.eql(u8, op, "<=")) return "le";
    if (std.mem.eql(u8, op, ">=")) return "ge";
    if (std.mem.eql(u8, op, "&")) return "bitAnd";
    if (std.mem.eql(u8, op, "|")) return "bitOr";
    if (std.mem.eql(u8, op, "^")) return "bitXor";
    if (std.mem.eql(u8, op, "<<")) return "shl";
    if (std.mem.eql(u8, op, ">>")) return "shr";
    if (std.mem.eql(u8, op, "**")) return "pow";
    if (std.mem.eql(u8, op, "and")) return "logicAnd";
    if (std.mem.eql(u8, op, "or")) return "logicOr";
    return null;
}
