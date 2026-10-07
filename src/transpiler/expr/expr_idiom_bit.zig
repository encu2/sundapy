const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const bit_ops = @import("expr_idiom_bit_ops.zig");
const getIntLiteral = bit_ops.getIntLiteral;

pub fn tryLowerBitwiseIdiom(self: *Transpiler, node: *ast.Node) anyerror!bool {
    if (node.* != .binary) return false;
    const b = node.binary;

    if (try tryLowerEvenOdd(self, b)) return true;
    if (try tryLowerPow2Mod(self, b)) return true;
    if (try tryLowerPow2Mul(self, b)) return true;
    if (try tryLowerPow2Div(self, b)) return true;
    if (try bit_ops.tryLowerBitRotation(self, b)) return true;
    if (try bit_ops.tryLowerBitTwiddling(self, b)) return true;
    if (try bit_ops.tryLowerNativeBitOp(self, b)) return true;

    return false;
}

pub fn tryLowerBitUnary(self: *Transpiler, node: *ast.Node) anyerror!bool {
    if (node.* != .unary) return false;
    const u = node.unary;
    if (!std.mem.eql(u8, u.op, "~")) return false;

    if (self.isStrict()) {
        try self.emit("~", .{});
        try self.transpileExprStrict(u.right);
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(u.right);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(~_v_{d}.value.i64_type);\n", .{ lid, lid });
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} _v_{d}.bitNot();\n", .{ lid, lid });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});
    return true;
}

pub fn tryLowerBitMethodCall(self: *Transpiler, m: anytype) anyerror!bool {
    if (std.mem.eql(u8, m.method, "bit_count") and m.args.items.len == 0) {
        if (self.isStrict()) {
            self.label_counter += 1;
            const lid = self.label_counter;
            try self.emit("(blk_{d}: {{\n", .{lid});
            try self.emit("    const _v_{d}: i64 = @as(i64, ", .{lid});
            try self.transpileExprStrict(m.target);
            try self.emit(");\n", .{});
            try self.emit("    const _abs_{d} = if (_v_{d} < 0) -%_v_{d} else _v_{d};\n", .{ lid, lid, lid, lid });
            try self.emit("    break :blk_{d} @as(i64, @intCast(@popCount(@as(u64, @bitCast(_abs_{d})))));\n", .{ lid, lid });
            try self.emit("}})", .{});
            return true;
        }
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("(blk_{d}: {{\n", .{lid});
        try self.emit("    const _t_{d} = dynamic.Dynamic.fromAny(", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(");\n", .{});
        try self.emit("    if (_t_{d}.value == .i64_type) {{\n", .{lid});
        try self.emit("        const _abs_{d} = @abs(_t_{d}.value.i64_type);\n", .{ lid, lid });
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(@as(i64, @intCast(@popCount(_abs_{d}))));\n", .{ lid, lid });
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(0);\n", .{lid});
        try self.emit("    }}\n", .{});
        try self.emit("}})", .{});
        return true;
    }

    if (std.mem.eql(u8, m.method, "bit_length") and m.args.items.len == 0) {
        if (self.isStrict()) {
            self.label_counter += 1;
            const lid = self.label_counter;
            try self.emit("(blk_{d}: {{\n", .{lid});
            try self.emit("    const _v_{d}: i64 = @as(i64, ", .{lid});
            try self.transpileExprStrict(m.target);
            try self.emit(");\n", .{});
            try self.emit("    if (_v_{d} == 0) break :blk_{d} 0;\n", .{ lid, lid });
            try self.emit("    const _abs_{d} = if (_v_{d} < 0) -%_v_{d} else _v_{d};\n", .{ lid, lid, lid, lid });
            try self.emit("    break :blk_{d} (64 - @as(i64, @intCast(@clz(@as(u64, @bitCast(_abs_{d})))));\n", .{ lid, lid });
            try self.emit("}})", .{});
            return true;
        }
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("(blk_{d}: {{\n", .{lid});
        try self.emit("    const _t_{d} = dynamic.Dynamic.fromAny(", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(");\n", .{});
        try self.emit("    if (_t_{d}.value == .i64_type) {{\n", .{lid});
        try self.emit("        const _val_{d} = _t_{d}.value.i64_type;\n", .{ lid, lid });
        try self.emit("        if (_val_{d} == 0) break :blk_{d} dynamic.Dynamic.initInt(0);\n", .{ lid, lid });
        try self.emit("        const _abs_{d} = @abs(_val_{d});\n", .{ lid, lid });
        try self.emit("        const _len_{d}: i64 = 64 - @as(i64, @intCast(@clz(_abs_{d})));\n", .{ lid, lid });
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_len_{d});\n", .{ lid, lid });
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(0);\n", .{lid});
        try self.emit("    }}\n", .{});
        try self.emit("}})", .{});
        return true;
    }

    if (std.mem.eql(u8, m.method, "count") and m.args.items.len == 1) {
        if (m.target.* == .call and m.target.call.callee.* == .identifier and
            std.mem.eql(u8, m.target.call.callee.identifier.name, "bin") and
            m.target.call.args.items.len == 1)
        {
            if (m.args.items[0].* == .string and std.mem.eql(u8, m.args.items[0].string, "1")) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _t_{d} = dynamic.Dynamic.fromAny(", .{lid});
                try self.transpileExpr(m.target.call.args.items[0]);
                try self.emit(");\n", .{});
                try self.emit("    if (_t_{d}.value == .i64_type) {{\n", .{lid});
                try self.emit("        const _abs_{d} = @abs(_t_{d}.value.i64_type);\n", .{ lid, lid });
                try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(@as(i64, @intCast(@popCount(_abs_{d}))));\n", .{ lid, lid });
                try self.emit("    }} else {{\n", .{});
                try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(0);\n", .{lid});
                try self.emit("    }}\n", .{});
                try self.emit("}})", .{});
                return true;
            }
        }
    }

    return false;
}

fn tryLowerEvenOdd(self: *Transpiler, b: anytype) anyerror!bool {
    const is_eq = std.mem.eql(u8, b.op, "==");
    const is_neq = std.mem.eql(u8, b.op, "!=");
    if (!is_eq and !is_neq) return false;

    var x_node: ?*ast.Node = null;
    var cmp_val: i64 = 0;

    if (isModTwo(b.left)) |left_x| {
        cmp_val = getIntLiteral(b.right) orelse return false;
        x_node = left_x;
    } else if (isModTwo(b.right)) |right_x| {
        cmp_val = getIntLiteral(b.left) orelse return false;
        x_node = right_x;
    } else {
        return false;
    }

    if (cmp_val != 0 and cmp_val != 1) return false;
    const x = x_node orelse return false;

    const expect_zero = if (is_eq) (cmp_val == 0) else (cmp_val != 0);

    if (self.isStrict()) {
        if (expect_zero) {
            try self.emit("((", .{});
            try self.transpileExprStrict(x);
            try self.emit(" & 1) == 0)", .{});
        } else {
            try self.emit("((", .{});
            try self.transpileExprStrict(x);
            try self.emit(" & 1) != 0)", .{});
        }
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(x);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    if (expect_zero) {
        try self.emit("        break :blk_{d} dynamic.Dynamic.initBool((_v_{d}.value.i64_type & 1) == 0);\n", .{ lid, lid });
    } else {
        try self.emit("        break :blk_{d} dynamic.Dynamic.initBool((_v_{d}.value.i64_type & 1) != 0);\n", .{ lid, lid });
    }
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} (_v_{d}.mod(dynamic.Dynamic.initInt(2))).{s}(dynamic.Dynamic.initInt({d}));\n", .{ lid, lid, if (is_eq) "eq" else "neq", cmp_val });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});

    return true;
}

fn tryLowerPow2Mod(self: *Transpiler, b: anytype) anyerror!bool {
    if (!std.mem.eql(u8, b.op, "%")) return false;
    const r_val = getIntLiteral(b.right) orelse return false;
    if (r_val <= 1 or !isPowerOfTwo(r_val)) return false;

    const mask = r_val - 1;
    if (self.isStrict()) {
        try self.emit("(", .{});
        try self.transpileExprStrict(b.left);
        try self.emit(" & {d})", .{mask});
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(b.left);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_v_{d}.value.i64_type & {d});\n", .{ lid, lid, mask });
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} _v_{d}.mod(dynamic.Dynamic.initInt({d}));\n", .{ lid, lid, r_val });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});

    return true;
}

fn tryLowerPow2Mul(self: *Transpiler, b: anytype) anyerror!bool {
    if (!std.mem.eql(u8, b.op, "*")) return false;

    var val_node: ?*ast.Node = null;
    var shift_amt: ?u6 = null;

    if (getIntLiteral(b.right)) |r| {
        if (getPowerOfTwoExponent(r)) |k| {
            val_node = b.left;
            shift_amt = k;
        }
    } else if (getIntLiteral(b.left)) |l| {
        if (getPowerOfTwoExponent(l)) |k| {
            val_node = b.right;
            shift_amt = k;
        }
    }

    const val = val_node orelse return false;
    const k = shift_amt orelse return false;
    if (k == 0) return false;

    if (self.isStrict()) {
        try self.emit("(", .{});
        try self.transpileExprStrict(val);
        try self.emit(" << {d})", .{k});
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(val);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_v_{d}.value.i64_type << {d});\n", .{ lid, lid, k });
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} _v_{d}.mul(dynamic.Dynamic.initInt({d}));\n", .{ lid, lid, @as(i64, 1) << k });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});

    return true;
}

fn tryLowerPow2Div(self: *Transpiler, b: anytype) anyerror!bool {
    if (!std.mem.eql(u8, b.op, "//")) return false;
    const r_val = getIntLiteral(b.right) orelse return false;
    const k = getPowerOfTwoExponent(r_val) orelse return false;
    if (k == 0) return false;

    if (self.isStrict()) {
        try self.emit("(", .{});
        try self.transpileExprStrict(b.left);
        try self.emit(" >> {d})", .{k});
        return true;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _v_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(b.left);
    try self.emit(");\n", .{});
    try self.emit("    if (_v_{d}.value == .i64_type) {{\n", .{lid});
    try self.emit("        break :blk_{d} dynamic.Dynamic.initInt(_v_{d}.value.i64_type >> {d});\n", .{ lid, lid, k });
    try self.emit("    }} else {{\n", .{});
    try self.emit("        break :blk_{d} _v_{d}.floorDiv(dynamic.Dynamic.initInt({d}));\n", .{ lid, lid, r_val });
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});

    return true;
}

fn isModTwo(node: *ast.Node) ?*ast.Node {
    if (node.* != .binary) return null;
    if (!std.mem.eql(u8, node.binary.op, "%")) return null;
    const r_val = getIntLiteral(node.binary.right) orelse return null;
    if (r_val == 2) return node.binary.left;
    return null;
}

fn isPowerOfTwo(val: i64) bool {
    return val > 0 and (val & (val - 1)) == 0;
}

fn getPowerOfTwoExponent(val: i64) ?u6 {
    if (!isPowerOfTwo(val)) return null;
    return @as(u6, @intCast(@ctz(@as(u64, @intCast(val)))));
}
