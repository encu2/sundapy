const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileExpr(self: *Transpiler, node: *ast.Node) anyerror!void {
    if (!self.is_strict) {
        switch (node.*) {
            .number => |n| try self.emit("(Dynamic{{ .value = .{{ .float_type = {d} }} }})", .{n}),
            .integer => |i| try self.emit("(Dynamic{{ .value = .{{ .i64_type = {s} }} }})", .{i}),
            .float => |f| try self.emit("(Dynamic{{ .value = .{{ .float_type = {s} }} }})", .{f}),
            .string => |s| try self.emit("(Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }})", .{s}),
            .await_expr => |aw| {
            try self.emit("(", .{});
            try self.transpileExpr(aw.value);
            try self.emit(").awaitResult()", .{});
        },
        .fstring => |f| {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    var _res = Dynamic{{ .value = .{{ .str_type = \"\" }} }};\n", .{});
                
                var i: usize = 0;
                var start_idx: usize = 0;
                while (i < f.value.len) {
                    if (f.value[i] == '{') {
                        if (i > start_idx) {
                            try self.emit("    _res = _res.add(Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }});\n", .{f.value[start_idx..i]});
                        }
                        i += 1;
                        const var_start = i;
                        while (i < f.value.len and f.value[i] != '}') : (i += 1) {}
                        if (i < f.value.len and f.value[i] == '}') {
                            const var_name = f.value[var_start..i];
                            var actual_var = var_name;
                            if (std.mem.indexOfScalar(u8, var_name, ':')) |colon_idx| {
                                actual_var = var_name[0..colon_idx];
                            }
                            var sub_lexer = @import("../../lexer/lexer.zig").Lexer.init(self.allocator, actual_var);
                            var sub_parser = @import("../../parser/parser.zig").Parser.init(self.allocator, &sub_lexer);
                            if (sub_parser.parseExpr(.none)) |expr_node| {
                                try self.emit("    _res = _res.add(dynamic.stringify(alloc, ", .{});
                                try self.transpileExpr(expr_node);
                                try self.emit("));\n", .{});
                            } else |_| {
                                try self.emit("    _res = _res.add(dynamic.stringify(alloc, {s}));\n", .{actual_var});
                            }
                        }
                        start_idx = i + 1;
                    }
                    i += 1;
                }
                if (start_idx < f.value.len) {
                    try self.emit("    _res = _res.add(Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }});\n", .{f.value[start_idx..]});
                }
                try self.emit("    break :blk_{d} _res;\n", .{lid});
                try self.emit("}})", .{});
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
            .none => try self.emit("(Dynamic{{ .value = .none_type }})", .{}),
            .identifier => |i| {
                if (std.mem.eql(u8, i.name, "True")) {
                    try self.emit("dynamic.True", .{});
                } else if (std.mem.eql(u8, i.name, "False")) {
                    try self.emit("dynamic.False", .{});
                } else if (std.mem.eql(u8, i.name, "None")) {
                    try self.emit("dynamic.None", .{});
                } else if (std.mem.eql(u8, i.name, "__name__")) {
                    try self.emit("(Dynamic{{ .value = .{{ .str_type = \"__main__\" }} }})", .{});
                } else {
                    const escaped = try self.escapeKeyword(i.name);
                    defer self.allocator.free(escaped);
                    // Box it if we inferred it as stack primitive
                    if (self.escape_analyzer.variables.get(i.name)) |v| {
                        if (v.class == .stack and v.is_primitive) {
                            try self.emit("(Dynamic{{ .value = .{{ .{s}_type = {s} }} }})", .{
                                if (std.mem.eql(u8, self.escape_analyzer.primitiveTypeString(node), "f64")) "float" else "i64",
                                escaped
                            });
                            return;
                        }
                    }
                    if (self.is_strict) {
                        try self.emit("{s}", .{escaped});
                    } else {
                        try self.emit("(if (@typeInfo(@TypeOf({s})) == .@\"fn\") dynamic.toDynamicFunc({s}) else {s})", .{escaped, escaped, escaped});
                    }
                }
            },
            .list_expr => |l| {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("Dynamic{{ .value = .{{ .list_type = .{{ .items = blk_{d}: {{\n", .{lid});
                try self.emit("    var _l_{d}: std.ArrayList(Dynamic) = .empty;\n", .{lid});
                try self.emit("    _ = &_l_{d};\n", .{lid});
                for (l.items.items) |item| {
                    try self.emit("    _l_{d}.append(alloc, ", .{lid});
                    try self.transpileExpr(item);
                    try self.emit(") catch unreachable;\n", .{});
                }
                try self.emit("    break :blk_{d} _l_{d};\n", .{lid, lid});
                try self.emit("}} }} }} }}", .{});
            },
            .list_comp => |l| {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("Dynamic{{ .value = .{{ .list_type = .{{ .items = blk_{d}: {{\n", .{lid});
                try self.emit("    var _l_{d}: std.ArrayList(Dynamic) = .empty;\n", .{lid});
                try self.emit("    _ = &_l_{d};\n", .{lid});
                try self.emit("    var iter_obj_{d} = ", .{lid});
                try self.transpileExpr(l.iterable);
                try self.emit(";\n", .{});
                try self.emit("    var iter_idx_{d}: usize = 0;\n", .{lid});
                try self.emit("    while (iter_idx_{d} < iter_obj_{d}.len()) : (iter_idx_{d} += 1) {{\n", .{lid, lid, lid});
                
                const already_declared = if (self.current_declared_vars) |vars| vars.contains(l.target) else false;
                if (!already_declared) {
                    if (self.current_declared_vars) |vars| {
                        try vars.put(l.target, true);
                    }
                    try self.emit("        var {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{l.target, lid, lid});
                    try self.emit("        _ = &{s};\n", .{l.target});
                } else {
                    try self.emit("        {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{l.target, lid, lid});
                }
                
                if (l.condition) |cond| {
                    try self.emit("        if ((", .{});
                    try self.transpileExpr(cond);
                    try self.emit(").toBool()) {{\n", .{});
                    try self.emit("            _l_{d}.append(alloc, ", .{lid});
                    try self.transpileExpr(l.expression);
                    try self.emit(") catch unreachable;\n", .{});
                    try self.emit("        }}\n", .{});
                } else {
                    try self.emit("        _l_{d}.append(alloc, ", .{lid});
                    try self.transpileExpr(l.expression);
                    try self.emit(") catch unreachable;\n", .{});
                }
                
                try self.emit("    }}\n", .{});
                try self.emit("    break :blk_{d} _l_{d};\n", .{lid, lid});
                try self.emit("}} }} }} }}", .{});
            },
            .dict_expr => |d| {
                self.label_counter += 1;
                const lid = self.label_counter;
                
                if (d.keys.items.len > 0 and d.values.items.len == 0) {
                    try self.emit("Dynamic.initSet(alloc)", .{});
                } else {
                    try self.emit("Dynamic{{ .value = .{{ .dict_type = blk_{d}: {{\n", .{lid});
                    try self.emit("    var _d_{d} = @import(\"datatype/dynamic.zig\").mapping.Dict.init(alloc) catch unreachable;\n", .{lid});
                    try self.emit("    _ = &_d_{d};\n", .{lid});
                    for (d.keys.items, 0..) |k, i| {
                        try self.emit("    _d_{d}.put(", .{lid});
                        try self.transpileExpr(k);
                        try self.emit(", ", .{});
                        try self.transpileExpr(d.values.items[i]);
                        try self.emit(") catch unreachable;\n", .{});
                    }
                    try self.emit("    break :blk_{d} _d_{d};\n", .{lid, lid});
                    try self.emit("}} }} }}", .{});
                }
            },
            .ternary_expr => |t| {
                try self.emit("if ((", .{});
                try self.transpileExpr(t.condition);
                try self.emit(").toBool()) ", .{});
                try self.transpileExpr(t.true_expr);
                try self.emit(" else ", .{});
                try self.transpileExpr(t.false_expr);
            },
            .binary => |b| {
                const method = mapOpToMethod(b.op);
                if (method) |m| {
                    try self.emit("(", .{});
                    try self.transpileExpr(b.left);
                    try self.emit(").{s}(", .{m});
                    try self.transpileExpr(b.right);
                    try self.emit(")", .{});
                } else {
                    try self.transpileExprStrict(node);
                }
            },
            .unary => |u| {
                try self.emit("(", .{});
                if (std.mem.eql(u8, u.op, "~")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(u.right);
                    try self.emit(").bitNot()", .{});
                } else if (std.mem.eql(u8, u.op, "not")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(u.right);
                    try self.emit(").logicNot()", .{});
                } else if (std.mem.eql(u8, u.op, "-")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(u.right);
                    try self.emit(").neg()", .{});
                } else if (std.mem.eql(u8, u.op, "+")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(u.right);
                    try self.emit(").pos()", .{});
                } else if (std.mem.eql(u8, u.op, "*")) {
                    try self.transpileExpr(u.right);
                } else {
                    try self.emit("{s}(", .{u.op});
                    try self.transpileExpr(u.right);
                    try self.emit(")", .{});
                }
                try self.emit(")", .{});
            },
            .getattr => |g| {
                var target_is_module = false;
                if (g.target.* == .identifier) {
                    for (self.imported_modules.items) |mod| {
                        if (std.mem.eql(u8, g.target.identifier.name, mod)) {
                            target_is_module = true;
                            break;
                        }
                    }
                }
                
                if (target_is_module) {
                    try self.emit("(", .{});
                    try self.transpileExpr(g.target);
                    try self.emit(").{s}", .{g.attr});
                } else {
                    self.label_counter += 1;
                    const lid = self.label_counter;
                    try self.emit("((blk_{d}: {{\n", .{lid});
                    try self.emit("    const _target = ", .{});
                    try self.transpileExpr(g.target);
                    try self.emit(";\n", .{});
                    try self.emit("    const T = @TypeOf(_target);\n", .{});
                    try self.emit("    const info = @typeInfo(T);\n", .{});
                    try self.emit("    if (T == Dynamic) {{\n", .{});
                    try self.emit("        break :blk_{d} _target.builtin_getattr(\"{s}\");\n", .{lid, g.attr});
                    try self.emit("    }} else if (info == .pointer) {{\n", .{});
                    try self.emit("        const child_info = @typeInfo(info.pointer.child);\n", .{});
                    try self.emit("        if (child_info == .@\"struct\") {{\n", .{});
                    try self.emit("            if (@hasField(info.pointer.child, \"{s}\")) {{\n", .{g.attr});
                    try self.emit("                const _f = _target.{s};\n", .{g.attr});
                    try self.emit("                const F = @TypeOf(_f);\n", .{});
                    try self.emit("                if (F == Dynamic) break :blk_{d} _f;\n", .{lid});
                    try self.emit("                if (F == i64 or F == comptime_int) break :blk_{d} Dynamic{{ .value = .{{ .i64_type = @intCast(_f) }} }};\n", .{lid});
                    try self.emit("                if (F == f64 or F == comptime_float) break :blk_{d} Dynamic{{ .value = .{{ .float_type = @floatCast(_f) }} }};\n", .{lid});
                    try self.emit("                if (F == bool) break :blk_{d} Dynamic{{ .value = .{{ .bool_type = _f }} }};\n", .{lid});
                    try self.emit("                if (@typeInfo(F) == .pointer) break :blk_{d} Dynamic{{ .value = .{{ .str_type = _f }} }};\n", .{lid});
                    try self.emit("                break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
                    try self.emit("            }}\n", .{});
                    try self.emit("        }}\n", .{});
                    try self.emit("    }} else if (info == .@\"struct\") {{\n", .{});
                    try self.emit("        if (@hasField(T, \"{s}\")) {{\n", .{g.attr});
                    try self.emit("            const _f = _target.{s};\n", .{g.attr});
                    try self.emit("            const F = @TypeOf(_f);\n", .{});
                    try self.emit("            if (F == Dynamic) break :blk_{d} _f;\n", .{lid});
                    try self.emit("            if (F == i64 or F == comptime_int) break :blk_{d} Dynamic{{ .value = .{{ .i64_type = @intCast(_f) }} }};\n", .{lid});
                    try self.emit("            if (F == f64 or F == comptime_float) break :blk_{d} Dynamic{{ .value = .{{ .float_type = @floatCast(_f) }} }};\n", .{lid});
                    try self.emit("            if (F == bool) break :blk_{d} Dynamic{{ .value = .{{ .bool_type = _f }} }};\n", .{lid});
                    try self.emit("            if (@typeInfo(F) == .pointer) break :blk_{d} Dynamic{{ .value = .{{ .str_type = _f }} }};\n", .{lid});
                    try self.emit("            break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
                    try self.emit("        }}\n", .{});
                    try self.emit("    }}\n", .{});
                    try self.emit("    break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
                    try self.emit("}}))", .{});
                }
            },
            else => try self.transpileExprStrict(node),
        }
    } else {
        try self.transpileExprStrict(node);
    }
}

pub fn mapOpToMethod(op: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, op, "+")) return "add";
    if (std.mem.eql(u8, op, "-")) return "sub";
    if (std.mem.eql(u8, op, "*")) return "mul";
    if (std.mem.eql(u8, op, "/")) return "div";
    if (std.mem.eql(u8, op, "//")) return "floorDiv";
    if (std.mem.eql(u8, op, "%")) return "mod";
    if (std.mem.eql(u8, op, "==")) return "eq";
    if (std.mem.eql(u8, op, "!=")) return "neq";
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
