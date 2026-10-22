const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const mapType = @import("../transpiler.zig").Transpiler.mapType;

pub fn transpileCall(self: *Transpiler, c: anytype, node: *ast.Node) !void {
    if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "print")) {
        if (self.is_strict) {
            try self.emit("std.debug.print(\"", .{});
            for (c.args.items, 0..) |arg, idx| {
                const is_str = (arg.* == .string or arg.* == .fstring or arg.* == .dstring or (arg.* == .call and arg.call.callee.* == .identifier and std.mem.eql(u8, arg.call.callee.identifier.name, "str")) or (arg.* == .identifier and std.mem.eql(u8, arg.identifier.name, "__name__")));
                if (is_str) {
                    try self.emit("{{s}}", .{});
                } else {
                    try self.emit("{{any}}", .{});
                }
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
            try self.emit("dynamic.Dynamic.fromAny(", .{});
            try self.transpileExpr(v);
            try self.emit(")", .{});
        }
        try self.emit(";\n", .{});
    } else {
        if (!self.is_strict) {
            if (self.current_func_has_yield) {
                try self.emit("if (_has_yielded) return _yield_list else return Dynamic{{ .value = .none_type }};\n", .{});
            } else {
                try self.emit("return Dynamic{{ .value = .none_type }};\n", .{});
            }
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
    var err_name: []const u8 = "Exception";
    if (r.value) |v| {
        if (v.* == .identifier) {
            err_name = v.identifier.name;
        } else if (v.* == .call and v.call.callee.* == .identifier) {
            err_name = v.call.callee.identifier.name;
        }
    }
    if (self.try_depth > 0) {
        try self.emit("break :try_blk_{d} error.{s};\n", .{ self.try_depth, err_name });
    } else {
        try self.emit("return error.{s};\n", .{err_name});
    }
    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});
}

pub fn transpileYield(self: *Transpiler, yield_node: anytype) anyerror!void {
    if (yield_node.is_from) {
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("_has_yielded = true;\n", .{});
        try self.emitIndent();
        try self.emit("var _subiter_{d} = ", .{lid});
        if (yield_node.value) |v| {
            try self.transpileExpr(v);
        } else {
            try self.emit("Dynamic.initNone()", .{});
        }
        try self.emit(";\n", .{});
        try self.emitIndent();
        try self.emit("var _subiter_idx_{d}: usize = 0;\n", .{lid});
        try self.emitIndent();
        try self.emit("while (_subiter_idx_{d} < _subiter_{d}.len()) : (_subiter_idx_{d} += 1) {{\n", .{ lid, lid, lid });
        self.indent_level += 1;
        try self.emitIndent();
        try self.emit("_yield_list.value.list_type.items.append(alloc, _subiter_{d}.getItem(_subiter_idx_{d})) catch unreachable;\n", .{ lid, lid });
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
    } else {
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
}

pub fn transpileDel(self: *Transpiler, d: anytype) !void {
    switch (d.target.*) {
        .subscript => |s| {
            if (self.try_depth > 0) {
                try self.emit("(", .{});
                try self.transpileExpr(s.target);
                try self.emit(").delDynamicItem(", .{});
                try self.transpileExpr(s.index);
                try self.emit(") catch |_err| break :try_blk_{d} _err;\n", .{self.try_depth});
            } else {
                try self.emit("try (", .{});
                try self.transpileExpr(s.target);
                try self.emit(").delDynamicItem(", .{});
                try self.transpileExpr(s.index);
                try self.emit(");\n", .{});
            }
        },
        .identifier => |id| {
            const name = try self.escapeKeyword(id.name);
            defer self.allocator.free(name);
            var is_stack_primitive = false;
            if (self.escape_analyzer.variables.get(id.name)) |v_info| {
                if (v_info.class == .stack and v_info.is_primitive) {
                    is_stack_primitive = true;
                }
            }
            if (is_stack_primitive or self.is_strict) {
                try self.emit("{s} = undefined;\n", .{name});
            } else {
                try self.emit("{s} = Dynamic.initNone();\n", .{name});
            }
        },
        .getattr => |g| {
            try self.emit("if (comptime @TypeOf(", .{});
            try self.transpileExpr(g.target);
            try self.emit(") == dynamic.Dynamic) {{\n", .{});
            try self.emit("    _ = (", .{});
            try self.transpileExpr(g.target);
            try self.emit(").setAbiAttribute(\"{s}\", Dynamic.initNone());\n", .{g.attr});
            try self.emit("}} else {{\n", .{});
            try self.emit("    (", .{});
            try self.transpileExpr(g.target);
            try self.emit(").{s} = Dynamic.initNone();\n", .{g.attr});
            try self.emit("}}\n", .{});
        },
        else => {
            try self.emit("// Unhandled del target\n", .{});
        },
    }
}
