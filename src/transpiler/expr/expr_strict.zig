const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileExprStrict(self: *Transpiler, node: *ast.Node) anyerror!void {
    switch (node.*) {
        .number => |n| try self.emit("{d}", .{n}),
        .integer => |i| try self.emit("{s}", .{i}),
        .float => |f| try self.emit("{s}", .{f}),
        .string => |s| try self.emit("\"{s}\"", .{s}),
        .none => try self.emit("null", .{}),
        .ellipsis => try self.emit("{{}}", .{}),
        .identifier => |i| {
            if (std.mem.eql(u8, i.name, "True")) {
                try self.emit("true", .{});
            } else if (std.mem.eql(u8, i.name, "False")) {
                try self.emit("false", .{});
            } else if (std.mem.eql(u8, i.name, "None")) {
                try self.emit("null", .{});
            } else if (std.mem.eql(u8, i.name, "Ellipsis")) {
                try self.emit("{{}}", .{});
            } else if (std.mem.eql(u8, i.name, "__name__")) {
                try self.emit("__name__", .{});
            } else {
                if (self.scoped_aliases.get(i.name)) |alias| {
                    try self.emit("{s}", .{alias});
                    return;
                }
                const escaped = try self.escapeKeyword(i.name);
                defer self.allocator.free(escaped);
                try self.emit("{s}", .{escaped});
            }
        },
        .unary => |u| {
            if (try @import("expr_idiom_bit.zig").tryLowerBitUnary(self, node)) {
                return;
            }
            if (std.mem.eql(u8, u.op, "not")) {
                try self.emit("!", .{});
                try self.transpileExprStrict(u.right);
            } else {
                try self.emit("{s}", .{u.op});
                try self.transpileExprStrict(u.right);
            }
        },
        .starred => |s| {
            try self.transpileExprStrict(s.value);
        },
        .binary => |b| {
            if (try @import("expr_idiom_bit.zig").tryLowerBitwiseIdiom(self, node)) {
                return;
            }
            if (std.mem.eql(u8, b.op, "%")) {
                try self.emit("@mod(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(", ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            } else if (std.mem.eql(u8, b.op, "/")) {
                const is_float_expr = (b.left.* == .float or b.left.* == .number or b.right.* == .float or b.right.* == .number);
                if (is_float_expr) {
                    try self.emit("(", .{});
                    try self.transpileExprStrict(b.left);
                    try self.emit(" / ", .{});
                    try self.transpileExprStrict(b.right);
                    try self.emit(")", .{});
                } else {
                    try self.emit("@divTrunc(", .{});
                    try self.transpileExprStrict(b.left);
                    try self.emit(", ", .{});
                    try self.transpileExprStrict(b.right);
                    try self.emit(")", .{});
                }
            } else if (std.mem.eql(u8, b.op, "//")) {
                try self.emit("@divFloor(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(", ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            } else if (std.mem.eql(u8, b.op, "**")) {
                try self.emit("_sundapy_pow(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(", ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            } else if (std.mem.eql(u8, b.op, "in")) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _l = ", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(";\n", .{});
                try self.emit("    const _r = ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(";\n", .{});
                try self.emit("    var _found = false;\n", .{});
                try self.emit("    inline for (_r) |v| {{\n", .{});
                try self.emit("        if (_l == v) {{ _found = true; break; }}\n", .{});
                try self.emit("    }}\n", .{});
                try self.emit("    break :blk_{d} _found;\n", .{lid});
                try self.emit("}})", .{});
            } else if (std.mem.eql(u8, b.op, "not_in") or std.mem.eql(u8, b.op, "not in")) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _l = ", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(";\n", .{});
                try self.emit("    const _r = ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(";\n", .{});
                try self.emit("    var _found = false;\n", .{});
                try self.emit("    inline for (_r) |v| {{\n", .{});
                try self.emit("        if (_l == v) {{ _found = true; break; }}\n", .{});
                try self.emit("    }}\n", .{});
                try self.emit("    break :blk_{d} !_found;\n", .{lid});
                try self.emit("}})", .{});
            } else if (std.mem.eql(u8, b.op, "is") or std.mem.eql(u8, b.op, "==")) {
                try self.emit("_sundapy_eq(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(", ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            } else if (std.mem.eql(u8, b.op, "is_not") or std.mem.eql(u8, b.op, "!=")) {
                try self.emit("_sundapy_ne(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(", ", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            } else if (std.mem.eql(u8, b.op, "<<")) {
                try self.emit("(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(" << @as(u6, @intCast(", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")))", .{});
            } else if (std.mem.eql(u8, b.op, ">>")) {
                try self.emit("(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(" >> @as(u6, @intCast(", .{});
                try self.transpileExprStrict(b.right);
                try self.emit(")))", .{});
            } else {
                try self.emit("(", .{});
                try self.transpileExprStrict(b.left);
                try self.emit(" {s} ", .{b.op});
                try self.transpileExprStrict(b.right);
                try self.emit(")", .{});
            }
        },
        .list_expr => |l| {
            try self.emit(".{{", .{});
            for (l.items.items, 0..) |item, idx| {
                try self.transpileExprStrict(item);
                if (idx < l.items.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit("}}", .{});
        },
        .tuple_expr => |t| {
            if (self.is_strict) {
                try self.emit(".{{", .{});
                for (t.items.items, 0..) |item, idx| {
                    try self.transpileExprStrict(item);
                    if (idx < t.items.items.len - 1) try self.emit(", ", .{});
                }
                try self.emit("}}", .{});
            } else {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("Dynamic{{ .value = .{{ .tuple_type = blk_{d}: {{\n", .{lid});
                try self.emit("    const _t_{d} = alloc.alloc(Dynamic, {d}) catch unreachable;\n", .{lid, t.items.items.len});
                for (t.items.items, 0..) |item, i| {
                    try self.emit("    _t_{d}[{d}] = dynamic.Dynamic.fromAny(", .{lid, i});
                    try self.transpileExpr(item);
                    try self.emit(");\n", .{});
                }
                try self.emit("    break :blk_{d} .{{ .items = _t_{d}, .allocator = alloc }};\n", .{lid, lid});
                try self.emit("}} }} }}", .{});
            }
        },
        .list_comp => {
            if (try @import("expr_idiom_lowering.zig").tryLowerMultidimList(self, node)) {
                return;
            }
            try self.emit("@compileError(\"List comprehensions are dynamic by nature and not yet supported in #strict mode without an allocator.\");", .{});
        },
        .dict_expr => |d| {
            try self.emit(".{{ ", .{});
            for (d.keys.items, 0..) |k, i| {
                if (k.* == .string) {
                    try self.emit(".{s} = ", .{k.string});
                } else {
                    // Fallback if not string key
                    try self.emit(".unknown_key = ", .{});
                }
                try self.transpileExprStrict(d.values.items[i]);
                if (i < d.keys.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(" }}", .{});
        },
        .ternary_expr => |t| {
            try self.emit("if (", .{});
            try self.transpileExprStrict(t.condition);
            try self.emit(") ", .{});
            try self.transpileExprStrict(t.true_expr);
            try self.emit(" else ", .{});
            try self.transpileExprStrict(t.false_expr);
        },
        .call => |c| {
            try @import("expr_strict_call.zig").transpileStrictCall(self, c);
        },
        .method_call => |m| {
            try @import("expr_strict_method.zig").transpileStrictMethodCall(self, m);
        },
        .subscript => |s| {
            if (self.try_depth == 0) {
                try self.emit("(try (", .{});
            } else if (self.try_depth > 0) {
                try self.emit("((", .{});
            }
            try self.transpileExpr(s.target);
            try self.emit(").getDynamicItem(", .{});
            try self.transpileExpr(s.index);
            if (self.try_depth == 0) {
                try self.emit("))", .{});
            } else if (self.try_depth > 0) {
                self.label_counter += 1;
                try self.emit(") catch |err_{d}| break :try_blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
            }
        },
        .slice => |s| {
            if (s.target.* == .dummy_expr) {
                try self.emit("dynamic.Dynamic.initSlice(", .{});
                if (s.start) |n| {
                    try self.transpileExpr(n);
                } else {
                    try self.emit("Dynamic.initNone()", .{});
                }
                try self.emit(", ", .{});
                if (s.stop) |n| {
                    try self.transpileExpr(n);
                } else {
                    try self.emit("Dynamic.initNone()", .{});
                }
                try self.emit(", ", .{});
                if (s.step) |n| {
                    try self.transpileExpr(n);
                } else {
                    try self.emit("Dynamic.initNone()", .{});
                }
                try self.emit(")", .{});
                return;
            }
            if (self.try_depth == 0) {
                try self.emit("try (", .{});
            } else if (self.try_depth > 0) {
                try self.emit("((", .{});
            }
            try self.transpileExpr(s.target);
            try self.emit(").getDynamicSlice(", .{});
            if (s.start) |n| {
                try self.transpileExpr(n);
            } else {
                try self.emit("Dynamic.initNone()", .{});
            }
            try self.emit(", ", .{});
            if (s.stop) |n| {
                try self.transpileExpr(n);
            } else {
                try self.emit("Dynamic.initNone()", .{});
            }
            try self.emit(", ", .{});
            if (s.step) |n| {
                try self.transpileExpr(n);
            } else {
                try self.emit("Dynamic.initNone()", .{});
            }
            try self.emit(")", .{});
            if (self.try_depth > 0) {
                self.label_counter += 1;
                try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
            }
        },
        .getattr => |g| {
            if (try @import("expr_math_intrinsics.zig").tryLowerMathAttr(self, g)) return;
            if (self.try_depth == 0) {
                // Not needed for getattr on structs, but we keep format
            }
            try self.transpileExpr(g.target);
            try self.emit(".{s}", .{g.attr});
        },
        .assign_expr => |a| {
            self.label_counter += 1;
            const lid = self.label_counter;
            try self.emit("(blk_{d}: {{\n", .{lid});
            try self.emit("    const _res = ", .{});
            try self.transpileExpr(a.value);
            try self.emit(";\n", .{});
            try self.emit("    ", .{});
            try self.transpileExpr(a.target);
            try self.emit(" = _res;\n", .{});
            try self.emit("    break :blk_{d} _res;\n", .{lid});
            try self.emit("}})", .{});
        },
        .safe_getattr => |g| {
            try self.emit("(if (", .{});
            try self.transpileExprStrict(g.target);
            try self.emit(") |_v| _v.{s} else null)", .{g.attr});
        },
        .coalesce_expr => |c| {
            try self.emit("((", .{});
            try self.transpileExprStrict(c.left);
            try self.emit(") orelse (", .{});
            try self.transpileExprStrict(c.right);
            try self.emit("))", .{});
        },
        .dstring => |d| {
            const dedented = @import("expr_string_tools.zig").dedentString(self.allocator, d.value);
            const escaped = @import("expr_string_tools.zig").escapeForZig(self.allocator, dedented);
            try self.emit("\"{s}\"", .{escaped});
        },
        .fstring => |f| try @import("expr_fstring.zig").transpileFString(self, f, true),
        .tstring => |t| {
            const escaped = @import("expr_string_tools.zig").escapeForZig(self.allocator, t.value);
            try self.emit(".{{ .template = \"{s}\" }}", .{escaped});
        },
        .dummy_expr => try self.emit("dynamic.Dynamic.initNone()", .{}),
        else => try self.emit("/* unhandled expr */", .{}),
    }
}

