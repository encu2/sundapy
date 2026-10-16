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
            .dstring => |d| {
                const dedented = @import("expr_string_tools.zig").dedentString(self.allocator, d.value);
                const escaped = @import("expr_string_tools.zig").escapeForZig(self.allocator, dedented);
                try self.emit("(Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }})", .{escaped});
            },
            .tstring => |t| {
                const escaped = @import("expr_string_tools.zig").escapeForZig(self.allocator, t.value);
                try self.emit("(Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }})", .{escaped});
            },
            .await_expr => |aw| {
            try self.emit("(", .{});
            try self.transpileExpr(aw.value);
            try self.emit(").awaitResult()", .{});
        },
        .fstring => |f| try @import("expr_fstring.zig").transpileFString(self, f, false),
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
                    if (self.is_root) {
                        try self.emit("(Dynamic{{ .value = .{{ .str_type = \"__main__\" }} }})", .{});
                    } else {
                        try self.emit("(Dynamic{{ .value = .{{ .str_type = \"module\" }} }})", .{});
                    }
                } else {
                    if (self.scoped_aliases.get(i.name)) |alias| {
                        try self.emit("{s}", .{alias});
                        return;
                    }
                    const escaped = try self.escapeKeyword(i.name);
                    defer self.allocator.free(escaped);
                    // Box it if we inferred it as stack primitive
                    if (self.escape_analyzer.variables.get(i.name)) |v| {
                        if (v.class == .stack and v.is_primitive) {
                            try self.emit("(dynamic.Dynamic.fromAny({s}))", .{escaped});
                            return;
                        }
                    }
                    var is_module = false;
                    for (self.imported_modules.items) |mod| {
                        if (std.mem.eql(u8, i.name, mod)) {
                            is_module = true;
                            break;
                        }
                    }
                    if (!is_module and self.module_aliases.get(i.name) != null) is_module = true;

                    if (self.is_strict or self.escape_analyzer.variables.contains(i.name) or is_module) {
                        try self.emit("{s}", .{escaped});
                    } else {
                        try self.emit("(if (comptime @TypeOf({s}) == type or (@typeInfo(@TypeOf({s})) == .pointer and @typeInfo(@typeInfo(@TypeOf({s})).pointer.child) == .@\"struct\" and @typeInfo(@TypeOf({s})).pointer.child != Dynamic) or (@typeInfo(@TypeOf({s})) == .@\"struct\" and !@typeInfo(@TypeOf({s})).@\"struct\".is_tuple and @TypeOf({s}) != Dynamic)) {s} else dynamic.Dynamic.fromAny({s}))", .{ escaped, escaped, escaped, escaped, escaped, escaped, escaped, escaped, escaped });
                    }
                }


            },
            .list_expr => |l| {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("Dynamic{{ .value = .{{ .list_type = .{{ .items = blk_{d}: {{\n", .{lid});
                try self.emit("    var _l_{d}: std.ArrayList(Dynamic) = .empty;\n", .{lid});
                try self.emit("    _ = &_l_{d};\n", .{lid});
                if (l.items.items.len > 0) {
                    try self.emit("    _l_{d}.ensureTotalCapacity(alloc, {d}) catch {{}};\n", .{lid, l.items.items.len});
                }
                for (l.items.items) |item| {
                    try self.emit("    _l_{d}.append(alloc, dynamic.Dynamic.fromAny(", .{lid});
                    try self.transpileExpr(item);
                    try self.emit(")) catch unreachable;\n", .{});
                }
                try self.emit("    break :blk_{d} _l_{d};\n", .{lid, lid});
                try self.emit("}} }} }} }}", .{});
            },
            .list_comp => |l| {
                if (try @import("expr_idiom_lowering.zig").tryLowerMultidimList(self, node)) {
                    return;
                }
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("Dynamic{{ .value = .{{ .list_type = .{{ .items = blk_{d}: {{\n", .{lid});
                try self.emit("    var _l_{d}: std.ArrayList(Dynamic) = .empty;\n", .{lid});
                try self.emit("    _ = &_l_{d};\n", .{lid});
                try self.emit("    var iter_obj_{d} = ", .{lid});
                try self.transpileExpr(l.iterable);
                try self.emit(";\n", .{});
                try self.emit("    _l_{d}.ensureTotalCapacity(alloc, iter_obj_{d}.len()) catch {{}};\n", .{lid, lid});
                try self.emit("    var iter_idx_{d}: usize = 0;\n", .{lid});
                try self.emit("    while (iter_idx_{d} < iter_obj_{d}.len()) : (iter_idx_{d} += 1) {{\n", .{lid, lid, lid});
                
                const escaped_target = try self.escapeKeyword(l.target);
                defer self.allocator.free(escaped_target);
                const already_declared = if (self.current_declared_vars) |vars| vars.contains(l.target) else false;
                if (!already_declared) {
                    if (self.current_declared_vars) |vars| {
                        try vars.put(l.target, true);
                    }
                    try self.emit("        var {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{escaped_target, lid, lid});
                    try self.emit("        _ = &{s};\n", .{escaped_target});
                } else {
                    try self.emit("        {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{escaped_target, lid, lid});
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
                    try self.emit("Dynamic{{ .value = .{{ .set_type = blk_{d}: {{\n", .{lid});
                    try self.emit("    var _s_{d} = @import(\"datatype/dynamic.zig\").set_type.Set.init(alloc);\n", .{lid});
                    try self.emit("    _ = &_s_{d};\n", .{lid});
                    for (d.keys.items) |k| {
                        try self.emit("    _s_{d}.add(alloc, dynamic.Dynamic.fromAny(", .{lid});
                        try self.transpileExpr(k);
                        try self.emit(")) catch unreachable;\n", .{});
                    }
                    try self.emit("    break :blk_{d} _s_{d};\n", .{lid, lid});
                    try self.emit("}} }} }}", .{});
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
                if (try @import("expr_idiom_cmp.zig").tryLowerBinaryIdiom(self, node)) {
                    return;
                }
                if (try @import("expr_idiom_bit.zig").tryLowerBitwiseIdiom(self, node)) {
                    return;
                }
                if (std.mem.eql(u8, b.op, "*")) {
                    if (try @import("expr_idiom_lowering.zig").tryLowerMultidimList(self, node)) {
                        return;
                    }
                }
                if (std.mem.eql(u8, b.op, "in")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(b.right);
                    try self.emit(").contains(", .{});
                    try self.transpileExpr(b.left);
                    try self.emit(")", .{});
                } else if (std.mem.eql(u8, b.op, "not_in") or std.mem.eql(u8, b.op, "not in")) {
                    try self.emit("(", .{});
                    try self.transpileExpr(b.right);
                    try self.emit(").notContains(", .{});
                    try self.transpileExpr(b.left);
                    try self.emit(")", .{});
                } else if (mapOpToMethod(b.op)) |m| {
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
                if (try @import("expr_idiom_bit.zig").tryLowerBitUnary(self, node)) {
                    return;
                }
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
            .getattr => |g| try @import("expr_access.zig").transpileGetattr(self, g),
            .safe_getattr => |g| try @import("expr_access.zig").transpileSafeGetattr(self, g),
            .coalesce_expr => |c| try @import("expr_access.zig").transpileCoalesceExpr(self, c),
            else => try self.transpileExprStrict(node),
        }
    } else {
        try self.transpileExprStrict(node);
    }
}

pub const mapOpToMethod = @import("expr_op_map.zig").mapOpToMethod;
