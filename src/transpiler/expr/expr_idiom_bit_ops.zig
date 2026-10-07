const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn tryLowerBitRotation(self: *Transpiler, b: anytype) anyerror!bool {
    if (!std.mem.eql(u8, b.op, "|")) return false;
    if (b.left.* != .binary or b.right.* != .binary) return false;

    var shl_node: ?*ast.Node = null;
    var shr_node: ?*ast.Node = null;

    if (std.mem.eql(u8, b.left.binary.op, "<<") and std.mem.eql(u8, b.right.binary.op, ">>")) {
        shl_node = b.left;
        shr_node = b.right;
    } else if (std.mem.eql(u8, b.left.binary.op, ">>") and std.mem.eql(u8, b.right.binary.op, "<<")) {
        shl_node = b.right;
        shr_node = b.left;
    } else {
        return false;
    }

    const sl = shl_node orelse return false;
    const sr = shr_node orelse return false;

    if (!isSameTarget(sl.binary.left, sr.binary.left)) return false;

    const k1 = getIntLiteral(sl.binary.right) orelse return false;
    const k2 = getIntLiteral(sr.binary.right) orelse return false;
    if (k1 <= 0 or k2 <= 0 or (k1 + k2 != 64)) return false;

    if (self.isStrict()) {
        try self.emit("@as(i64, @bitCast(std.math.rotl(u64, @as(u64, @bitCast(", .{});
        try self.transpileExprStrict(sl.binary.left);
        try self.emit(")), {d})))", .{k1});
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(sl.binary.left);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        const _u_{d} = @as(u64, @bitCast(_v_{d}.value.i64_type));\n", .{ lid, lid });
    try self.emit("        const _rot_{d} = std.math.rotl(u64, _u_{d}, {d});\n", .{ lid, lid, k1 });
    try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(@as(i64, @bitCast(_rot_{d})));\n", .{ lid, lid });
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} (_v_{d}.shl(dynamic.Dynamic.initInt({d}))).bitOr(_v_{d}.shr(dynamic.Dynamic.initInt({d})));\n", .{ lid, lid, k1, lid, k2 });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});

    return true;
}

const TwiddleKind = enum {
    isolate_lsb,
    clear_lsb,
    clear_trailing_ones,
    isolate_lowest_zero,
    set_lowest_zero,
    bits_below_lsb,
    lsb_mask,
};

fn isOffsetOne(candidate: *ast.Node, target: *ast.Node, op: []const u8) bool {
    if (candidate.* != .binary) return false;
    if (!std.mem.eql(u8, candidate.binary.op, op)) return false;
    if (!isSameTarget(target, candidate.binary.left)) return false;
    const lit = getIntLiteral(candidate.binary.right) orelse return false;
    return lit == 1;
}

fn detectTwiddle(b: anytype) ?struct { target: *ast.Node, kind: TwiddleKind } {
    if (std.mem.eql(u8, b.op, "&")) {
        if (b.right.* == .unary and std.mem.eql(u8, b.right.unary.op, "-") and isSameTarget(b.left, b.right.unary.right)) {
            return .{ .target = b.left, .kind = .isolate_lsb };
        }
        if (b.left.* == .unary and std.mem.eql(u8, b.left.unary.op, "-") and isSameTarget(b.right, b.left.unary.right)) {
            return .{ .target = b.right, .kind = .isolate_lsb };
        }
        if (isOffsetOne(b.right, b.left, "-")) return .{ .target = b.left, .kind = .clear_lsb };
        if (isOffsetOne(b.left, b.right, "-")) return .{ .target = b.right, .kind = .clear_lsb };
        if (isOffsetOne(b.right, b.left, "+")) return .{ .target = b.left, .kind = .clear_trailing_ones };
        if (isOffsetOne(b.left, b.right, "+")) return .{ .target = b.right, .kind = .clear_trailing_ones };
        if (b.left.* == .unary and std.mem.eql(u8, b.left.unary.op, "~") and isOffsetOne(b.right, b.left.unary.right, "+")) {
            return .{ .target = b.left.unary.right, .kind = .isolate_lowest_zero };
        }
        if (b.right.* == .unary and std.mem.eql(u8, b.right.unary.op, "~") and isOffsetOne(b.left, b.right.unary.right, "+")) {
            return .{ .target = b.right.unary.right, .kind = .isolate_lowest_zero };
        }
    } else if (std.mem.eql(u8, b.op, "|")) {
        if (isOffsetOne(b.right, b.left, "+")) return .{ .target = b.left, .kind = .set_lowest_zero };
        if (isOffsetOne(b.left, b.right, "+")) return .{ .target = b.right, .kind = .set_lowest_zero };
        if (isOffsetOne(b.right, b.left, "-")) return .{ .target = b.left, .kind = .bits_below_lsb };
        if (isOffsetOne(b.left, b.right, "-")) return .{ .target = b.right, .kind = .bits_below_lsb };
    } else if (std.mem.eql(u8, b.op, "^")) {
        if (isOffsetOne(b.right, b.left, "-")) return .{ .target = b.left, .kind = .lsb_mask };
        if (isOffsetOne(b.left, b.right, "-")) return .{ .target = b.right, .kind = .lsb_mask };
    }
    return null;
}

pub fn tryLowerBitTwiddling(self: *Transpiler, b: anytype) anyerror!bool {
    const match = detectTwiddle(b) orelse return false;

    if (self.isStrict()) {
        try self.emit("(", .{});
        switch (match.kind) {
            .isolate_lsb => {
                try self.transpileExprStrict(match.target);
                try self.emit(" & -%", .{});
                try self.transpileExprStrict(match.target);
            },
            .clear_lsb => {
                try self.transpileExprStrict(match.target);
                try self.emit(" & (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" -% 1)", .{});
            },
            .clear_trailing_ones => {
                try self.transpileExprStrict(match.target);
                try self.emit(" & (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" +% 1)", .{});
            },
            .isolate_lowest_zero => {
                try self.emit("~", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" & (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" +% 1)", .{});
            },
            .set_lowest_zero => {
                try self.transpileExprStrict(match.target);
                try self.emit(" | (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" +% 1)", .{});
            },
            .bits_below_lsb => {
                try self.transpileExprStrict(match.target);
                try self.emit(" | (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" -% 1)", .{});
            },
            .lsb_mask => {
                try self.transpileExprStrict(match.target);
                try self.emit(" ^ (", .{});
                try self.transpileExprStrict(match.target);
                try self.emit(" -% 1)", .{});
            },
        }
        try self.emit(")", .{});
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(match.target);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        const _val_{d} = _v_{d}.value.i64_type;\n", .{ lid, lid });
    switch (match.kind) {
        .isolate_lsb => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} & -%_val_{d});\n", .{ lid, lid, lid }),
        .clear_lsb => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} & (_val_{d} -% 1));\n", .{ lid, lid, lid }),
        .clear_trailing_ones => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} & (_val_{d} +% 1));\n", .{ lid, lid, lid }),
        .isolate_lowest_zero => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(~_val_{d} & (_val_{d} +% 1));\n", .{ lid, lid, lid }),
        .set_lowest_zero => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} | (_val_{d} +% 1));\n", .{ lid, lid, lid }),
        .bits_below_lsb => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} | (_val_{d} -% 1));\n", .{ lid, lid, lid }),
        .lsb_mask => try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_val_{d} ^ (_val_{d} -% 1));\n", .{ lid, lid, lid }),
    }
    try self.emit("    }} else {{\n", .{});
    switch (match.kind) {
        .isolate_lsb => try self.emit("        break :blk_{d} _v_{d}.bitAnd(_v_{d}.neg());\n", .{ lid, lid, lid }),
        .clear_lsb => try self.emit("        break :blk_{d} _v_{d}.bitAnd(_v_{d}.sub(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
        .clear_trailing_ones => try self.emit("        break :blk_{d} _v_{d}.bitAnd(_v_{d}.add(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
        .isolate_lowest_zero => try self.emit("        break :blk_{d} (_v_{d}.bitNot()).bitAnd(_v_{d}.add(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
        .set_lowest_zero => try self.emit("        break :blk_{d} _v_{d}.bitOr(_v_{d}.add(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
        .bits_below_lsb => try self.emit("        break :blk_{d} _v_{d}.bitOr(_v_{d}.sub(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
        .lsb_mask => try self.emit("        break :blk_{d} _v_{d}.bitXor(_v_{d}.sub(dynamic.Dynamic.initInt(1)));\n", .{ lid, lid, lid }),
    }
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});
    return true;
}

pub fn tryLowerNativeBitOp(self: *Transpiler, b: anytype) anyerror!bool {
    const is_logic = std.mem.eql(u8, b.op, "&") or std.mem.eql(u8, b.op, "|") or std.mem.eql(u8, b.op, "^");
    const is_shift = std.mem.eql(u8, b.op, "<<") or std.mem.eql(u8, b.op, ">>");
    if (!is_logic and !is_shift) return false;

    if (self.isStrict()) {
        if (is_logic) {
            try self.emit("(", .{});
            try self.transpileExprStrict(b.left);
            try self.emit(" {s} ", .{b.op});
            try self.transpileExprStrict(b.right);
            try self.emit(")", .{});
            return true;
        } else {
            try self.emit("(", .{});
            try self.transpileExprStrict(b.left);
            try self.emit(" {s} @as(u6, @intCast(", .{b.op});
            try self.transpileExprStrict(b.right);
            try self.emit(")))", .{});
            return true;
        }
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _l_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(b.left);
    try self.emit(");\n", .{});
    try self.emit("    const _r_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(b.right);
    try self.emit(");\n", .{});

    if (is_logic) {
        try self.emit("    if (_l_{d}.value == .i64_type and _r_{d}.value == .i64_type) {{\n", .{ lid, lid });
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_l_{d}.value.i64_type {s} _r_{d}.value.i64_type);\n", .{ lid, lid, b.op, lid });
        try self.emit("    }} else {{\n", .{});
        const m = if (std.mem.eql(u8, b.op, "&")) "bitAnd" else if (std.mem.eql(u8, b.op, "|")) "bitOr" else "bitXor";
        try self.emit("        break :blk_{d} _l_{d}.{s}(_r_{d});\n", .{ lid, lid, m, lid });
        try self.emit("    }}\n", .{});
    } else {
        try self.emit("    if (_l_{d}.value == .i64_type and _r_{d}.value == .i64_type and _r_{d}.value.i64_type >= 0 and _r_{d}.value.i64_type < 64) {{\n", .{ lid, lid, lid, lid });
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_l_{d}.value.i64_type {s} @as(u6, @intCast(_r_{d}.value.i64_type)));\n", .{ lid, lid, b.op, lid });
        try self.emit("    }} else {{\n", .{});
        const m = if (std.mem.eql(u8, b.op, "<<")) "shl" else "shr";
        try self.emit("        break :blk_{d} _l_{d}.{s}(_r_{d});\n", .{ lid, lid, m, lid });
        try self.emit("    }}\n", .{});
    }
    try self.emit("}})", .{});

    return true;
}

pub fn isSameTarget(a: *ast.Node, b: *ast.Node) bool {
    if (a.* == .identifier and b.* == .identifier) {
        return std.mem.eql(u8, a.identifier.name, b.identifier.name);
    }
    return false;
}

pub fn getIntLiteral(node: *ast.Node) ?i64 {
    switch (node.*) {
        .number => |n| {
            if (@round(n) == n) return @intFromFloat(n);
            return null;
        },
        .integer => |i| {
            return std.fmt.parseInt(i64, i, 0) catch null;
        },
        else => return null,
    }
}
