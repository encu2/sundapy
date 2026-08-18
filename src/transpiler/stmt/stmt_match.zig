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
        if (case_branch.pattern.* == .identifier and std.mem.eql(u8, case_branch.pattern.identifier.name, "_")) {
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
            
            try transpilePatternCond(self, m.subject, case_branch.pattern);
            
            if (self.is_strict) {
                try self.emit(") {{\n", .{});
            } else {
                try self.emit(".toBool()) {{\n", .{});
            }
            
            self.indent_level += 1;
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
