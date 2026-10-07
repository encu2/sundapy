const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

fn transpilePatternCond(self: *Transpiler, subject: *ast.Node, pattern: *ast.Node) anyerror!void {
    if (pattern.* == .binary and std.mem.eql(u8, pattern.binary.op, "|")) {
        try self.emit("(", .{});
        try transpilePatternCond(self, subject, pattern.binary.left);
        if (self.is_strict) {
            try self.emit(" or ", .{});
        } else {
            try self.emit(").logicOr(", .{});
        }
        try transpilePatternCond(self, subject, pattern.binary.right);
        try self.emit(")", .{});
    } else if (pattern.* == .list_expr) {
        // Sequence pattern matching (PEP 634: case [a, b])
        const items = pattern.list_expr.items.items;
        if (self.is_strict) {
            try self.emit("((", .{});
            try self.transpileExprStrict(subject);
            try self.emit(").len == {d}", .{items.len});
            for (items, 0..) |item, idx| {
                if (item.* == .identifier) continue; // capture variable matches anything
                try self.emit(" and (", .{});
                try self.transpileExprStrict(subject);
                try self.emit("[{d}] == ", .{idx});
                try self.transpileExprStrict(item);
                try self.emit(")", .{});
            }
            try self.emit(")", .{});
        } else {
            try self.emit("(Dynamic.initBool((", .{});
            try self.transpileExpr(subject);
            try self.emit(").len() == {d})", .{items.len});
            for (items, 0..) |item, idx| {
                if (item.* == .identifier) continue; // capture variable matches anything
                try self.emit(".logicAnd((", .{});
                try self.transpileExpr(subject);
                try self.emit(").getItem({d}).eq(", .{idx});
                try self.transpileExpr(item);
                try self.emit("))", .{});
            }
            try self.emit(")", .{});
        }
    } else {
        if (self.is_strict) {
            try self.emit("(", .{});
            try self.transpileExprStrict(subject);
            try self.emit(" == ", .{});
            try self.transpileExprStrict(pattern);
            try self.emit(")", .{});
        } else {
            try self.emit("(", .{});
            try self.transpileExpr(subject);
            try self.emit(").eq(", .{});
            try self.transpileExpr(pattern);
            try self.emit(")", .{});
        }
    }
}

pub fn transpileMatchStmt(self: *Transpiler, m: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
    var is_first = true;
    for (m.cases.items) |case_branch| {
        const is_wildcard = (case_branch.pattern.* == .identifier and std.mem.eql(u8, case_branch.pattern.identifier.name, "_"));
        const is_capture = (case_branch.pattern.* == .identifier and !std.mem.eql(u8, case_branch.pattern.identifier.name, "_"));

        if (is_wildcard and case_branch.guard == null) {
            // Unconditional default case
            if (!is_first) {
                try self.emit(" else {{\n", .{});
            } else {
                try self.emit("{{\n", .{});
            }
            self.indent_level += 1;
            for (case_branch.body.items) |stmt| {
                try @import("../stmt_dispatcher.zig").transpileStmt(self, stmt, declared_vars, strict_funcs);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}", .{});
            break;
        } else {
            if (is_first) {
                try self.emit("if (", .{});
            } else {
                try self.emit(" else if (", .{});
            }

            if (is_capture) {
                const cap_name = case_branch.pattern.identifier.name;
                if (case_branch.guard) |guard| {
                    self.label_counter += 1;
                    const lid = self.label_counter;
                    if (self.is_strict) {
                        try self.emit("(blk_{d}: {{ const {s} = ", .{ lid, cap_name });
                        try self.transpileExprStrict(m.subject);
                        try self.emit("; break :blk_{d} ", .{lid});
                        try self.transpileExprStrict(guard);
                        try self.emit("; }})", .{});
                    } else {
                        try self.emit("((blk_{d}: {{ const {s} = ", .{ lid, cap_name });
                        try self.transpileExpr(m.subject);
                        try self.emit("; break :blk_{d} ", .{lid});
                        try self.transpileExpr(guard);
                        try self.emit("; }}).toBool())", .{});
                    }
                } else {
                    try self.emit("true", .{});
                }
            } else if (is_wildcard) {
                if (case_branch.guard) |guard| {
                    if (self.is_strict) {
                        try self.transpileExprStrict(guard);
                    } else {
                        try self.transpileExpr(guard);
                        try self.emit(".toBool()", .{});
                    }
                }
            } else {
                try transpilePatternCond(self, m.subject, case_branch.pattern);

                if (case_branch.guard) |guard| {
                    if (self.is_strict) {
                        try self.emit(" and (", .{});
                        try self.transpileExprStrict(guard);
                        try self.emit(")", .{});
                    } else {
                        try self.emit(".logicAnd((", .{});
                        try self.transpileExpr(guard);
                        try self.emit("))", .{});
                    }
                }

                if (!self.is_strict) {
                    try self.emit(".toBool()", .{});
                }
            }

            try self.emit(") {{\n", .{});

            self.indent_level += 1;

            // Bind capture variable inside branch body if present
            if (is_capture) {
                const cap_name = case_branch.pattern.identifier.name;
                try self.emitIndent();
                if (self.is_strict) {
                    try self.emit("var {s} = ", .{cap_name});
                    try self.transpileExprStrict(m.subject);
                    try self.emit(";\n", .{});
                } else {
                    try self.emit("var {s} = ", .{cap_name});
                    try self.transpileExpr(m.subject);
                    try self.emit(";\n", .{});
                }
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{cap_name});
                try declared_vars.put(cap_name, true);
            } else if (case_branch.pattern.* == .list_expr) {
                for (case_branch.pattern.list_expr.items.items, 0..) |item, idx| {
                    if (item.* == .identifier and !std.mem.eql(u8, item.identifier.name, "_")) {
                        try self.emitIndent();
                        if (self.is_strict) {
                            try self.emit("var {s} = (", .{item.identifier.name});
                            try self.transpileExprStrict(m.subject);
                            try self.emit(")[{d}];\n", .{idx});
                        } else {
                            try self.emit("var {s} = (", .{item.identifier.name});
                            try self.transpileExpr(m.subject);
                            try self.emit(").getItem({d});\n", .{idx});
                        }
                        try self.emitIndent();
                        try self.emit("_ = &{s};\n", .{item.identifier.name});
                        try declared_vars.put(item.identifier.name, true);
                    }
                }
            }

            for (case_branch.body.items) |stmt| {
                try @import("../stmt_dispatcher.zig").transpileStmt(self, stmt, declared_vars, strict_funcs);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}", .{});
            is_first = false;
        }
    }
    try self.emit("\n", .{});
}
