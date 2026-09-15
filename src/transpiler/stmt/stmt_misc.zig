const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const mapType = @import("../transpiler.zig").Transpiler.mapType;

pub fn transpileCall(self: *Transpiler, c: anytype, node: *ast.Node) !void {
    if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "print")) {
        if (self.is_strict) {
            try self.emit("std.debug.print(\"", .{});
            for (c.args.items, 0..) |_, idx| {
                try self.emit("{{any}}", .{});
                if (idx < c.args.items.len - 1) try self.emit(" ", .{});
            }
            try self.emit("\\n\", .{{", .{});
        } else {
            try self.emit("dynamic.print(.{{", .{});
        }
        for (c.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < c.args.items.len - 1) {
                try self.emit(", ", .{});
            }
        }
        try self.emit("}});\n", .{});
    } else {
        try self.emit("_ = ", .{});
        try self.transpileExpr(node);
        try self.emit(";\n", .{});
    }
}

pub fn transpileMethodCall(self: *Transpiler, node: *ast.Node) !void {
    try self.emit("_ = ", .{});
    try self.transpileExpr(node);
    try self.emit(";\n", .{});
}

pub fn transpileReturn(self: *Transpiler, r: anytype) !void {
    if (r.value) |v| {
        try self.emit("return ", .{});
        if (self.is_strict) {
            try self.transpileExprStrict(v);
        } else {
            try self.transpileExpr(v);
        }
        try self.emit(";\n", .{});
    } else {
        if (!self.is_strict) {
            try self.emit("if (_has_yielded) return _yield_list else return Dynamic{{ .value = .none_type }};\n", .{});
        } else {
            try self.emit("return;\n", .{});
        }
    }
}

pub fn transpileRaise(self: *Transpiler, r: anytype) !void {
    try self.emit("var _raise = true; _ = &_raise;\n", .{});
    try self.emitIndent();
    try self.emit("if (_raise) {{\n", .{});
    self.indent_level += 1;
    try self.emitIndent();
    if (r.value) |v| {
        if (self.is_strict) {
            if (self.try_depth > 0) {
                try self.emit("break :try_blk_{d} error.Exception; // ", .{self.try_depth});
            } else {
                try self.emit("return error.Exception; // ", .{});
            }
            try self.transpileExprStrict(v);
            try self.emit("\n", .{});
        } else {
            if (self.try_depth > 0) {
                try self.emit("break :try_blk_{d} error.Exception; // ", .{self.try_depth});
            } else {
                try self.emit("return error.Exception; // ", .{});
            }
            try self.transpileExpr(v);
            try self.emit("\n", .{});
        }
    } else {
        if (self.try_depth > 0) {
            try self.emit("break :try_blk_{d} error.Exception;\n", .{self.try_depth});
        } else {
            try self.emit("return error.Exception;\n", .{});
        }
    }

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});
}

pub fn transpileYield(self: *Transpiler, yield_node: anytype) anyerror!void {
    try self.emit("_has_yielded = true;\n", .{});
    try self.emitIndent();
    try self.emit("_yield_list.value.list_type.items.append(alloc, ", .{});
    if (yield_node.value) |v| {
        try self.transpileExpr(v);
    } else {
        try self.emit("Dynamic.initNone()", .{});
    }
    try self.emit(") catch unreachable;\n", .{});
}
