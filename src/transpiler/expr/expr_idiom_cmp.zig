const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn tryLowerBinaryIdiom(self: *Transpiler, node: *ast.Node) anyerror!bool {
    if (node.* != .binary) return false;
    const b = node.binary;

    if (std.mem.eql(u8, b.op, "in")) {
        if (b.right.* == .list_expr and b.right.list_expr.items.items.len <= 8) {
            return tryLowerInList(self, b.left, b.right.list_expr.items.items, false);
        }
    } else if (std.mem.eql(u8, b.op, "not_in") or std.mem.eql(u8, b.op, "not in")) {
        if (b.right.* == .list_expr and b.right.list_expr.items.items.len <= 8) {
            return tryLowerInList(self, b.left, b.right.list_expr.items.items, true);
        }
    }

    if (isComparisonOp(b.op)) {
        if (b.left.* == .binary and isComparisonOp(b.left.binary.op)) {
            return tryLowerChainedCmp(self, b);
        }
    }

    return false;
}

fn tryLowerInList(self: *Transpiler, left: *ast.Node, items: []const *ast.Node, is_negated: bool) anyerror!bool {
    self.label_counter += 1;
    const lid = self.label_counter;

    if (items.len == 0) {
        try self.emit("(blk_{d}: {{\n", .{lid});
        try self.emit("    _ = dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(left);
        try self.emit(");\n", .{});
        if (is_negated) {
            try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(true);\n", .{lid});
        } else {
            try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(false);\n", .{lid});
        }
        try self.emit("}})", .{});
        return true;
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _target_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(left);
    try self.emit(");\n", .{});

    try self.emit("    const _matched_{d} = ", .{lid});
    for (items, 0..) |item, idx| {
        if (idx > 0) try self.emit(" or ", .{});
        try self.emit("_target_{d}.eq(dynamic.Dynamic.fromAny(", .{lid});
        try self.transpileExpr(item);
        try self.emit(")).toBool()", .{});
    }
    try self.emit(";\n", .{});

    if (is_negated) {
        try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(!_matched_{d});\n", .{ lid, lid });
    } else {
        try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(_matched_{d});\n", .{ lid, lid });
    }
    try self.emit("}})", .{});

    return true;
}

fn tryLowerChainedCmp(self: *Transpiler, b: anytype) anyerror!bool {
    const left_bin = b.left.binary;
    const op1 = mapCmpMethod(left_bin.op) orelse return false;
    const op2 = mapCmpMethod(b.op) orelse return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _mid_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(left_bin.right);
    try self.emit(");\n", .{});

    try self.emit("    const _c1_{d} = (dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(left_bin.left);
    try self.emit(")).{s}(_mid_{d}).toBool();\n", .{ op1, lid });

    try self.emit("    if (!_c1_{d}) break :blk_{d} dynamic.Dynamic.initBool(false);\n", .{ lid, lid });

    try self.emit("    const _c2_{d} = _mid_{d}.{s}(dynamic.Dynamic.fromAny(", .{ lid, lid, op2 });
    try self.transpileExpr(b.right);
    try self.emit(")).toBool();\n", .{});

    try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(_c2_{d});\n", .{ lid, lid });
    try self.emit("}})", .{});

    return true;
}

fn isComparisonOp(op: []const u8) bool {
    return std.mem.eql(u8, op, "<") or
        std.mem.eql(u8, op, "<=") or
        std.mem.eql(u8, op, ">") or
        std.mem.eql(u8, op, ">=") or
        std.mem.eql(u8, op, "==") or
        std.mem.eql(u8, op, "!=");
}

fn mapCmpMethod(op: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, op, "<")) return "lt";
    if (std.mem.eql(u8, op, "<=")) return "le";
    if (std.mem.eql(u8, op, ">")) return "gt";
    if (std.mem.eql(u8, op, ">=")) return "ge";
    if (std.mem.eql(u8, op, "==")) return "eq";
    if (std.mem.eql(u8, op, "!=")) return "neq";
    return null;
}
