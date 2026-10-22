const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const mapType = @import("../transpiler.zig").Transpiler.mapType;

pub fn transpileTupleAssign(self: *Transpiler, t: anytype, declared_vars: *std.StringHashMap(bool)) anyerror!void {
    const targets = t.targets.items;
    self.label_counter += 1;
    const lid = self.label_counter;

    var star_idx: ?usize = null;
    for (targets, 0..) |tgt, i| {
        if (tgt.* == .starred) {
            star_idx = i;
            break;
        }
    }

    const has_star = (star_idx != null);
    const is_direct_rhs = !has_star and ((t.value.* == .list_expr and t.value.list_expr.items.items.len == targets.len) or (t.value.* == .tuple_expr and t.value.tuple_expr.items.items.len == targets.len));
    if (is_direct_rhs) {
        const rhs_items = if (t.value.* == .list_expr) t.value.list_expr.items.items else t.value.tuple_expr.items.items;
        for (rhs_items, 0..) |item, idx| {
            if (idx > 0) try self.emitIndent();
            try self.emit("const _tmp_{d}_{d} = Dynamic.fromAny(", .{ lid, idx });
            try self.transpileExpr(item);
            try self.emit(");\n", .{});
        }
        for (targets, 0..) |tgt, idx| {
            try self.emitIndent();
            try emitTargetAssign(self, tgt, lid, idx, declared_vars);
        }
    } else {
        try self.emit("var _tup_{d} = Dynamic.fromAny(", .{lid});
        try self.transpileExpr(t.value);
        try self.emit(");\n", .{});

        if (star_idx) |s_idx| {
            const suffix_count = targets.len - 1 - s_idx;
            const min_len = targets.len - 1;
            try self.emitIndent();
            try self.emit("const _tup_len_{d} = _tup_{d}.len();\n", .{ lid, lid });
            try self.emitIndent();
            if (self.try_depth > 0) {
                try self.emit("if (_tup_len_{d} < {d}) break :try_blk_{d} error.ValueError;\n", .{ lid, min_len, self.try_depth });
            } else {
                try self.emit("if (_tup_len_{d} < {d}) return error.ValueError;\n", .{ lid, min_len });
            }
            for (targets[0..s_idx], 0..) |tgt, idx| {
                try self.emitIndent();
                try self.emit("const _tmp_{d}_{d} = _tup_{d}.getItem({d});\n", .{ lid, idx, lid, idx });
                try self.emitIndent();
                try emitTargetAssign(self, tgt, lid, idx, declared_vars);
            }
            try self.emitIndent();
            try self.emit("var _star_list_{d} = Dynamic.initList(.empty);\n", .{lid});
            try self.emitIndent();
            try self.emit("const _star_end_{d} = _tup_len_{d} - {d};\n", .{ lid, lid, suffix_count });
            try self.emitIndent();
            try self.emit("var _star_i_{d}: usize = {d};\n", .{ lid, s_idx });
            try self.emitIndent();
            try self.emit("while (_star_i_{d} < _star_end_{d}) : (_star_i_{d} += 1) {{\n", .{ lid, lid, lid });
            try self.emitIndent();
            try self.emit("    _star_list_{d}.value.list_type.items.append(alloc, _tup_{d}.getItem(_star_i_{d})) catch unreachable;\n", .{ lid, lid, lid });
            try self.emitIndent();
            try self.emit("}}\n", .{});
            try self.emitIndent();
            try self.emit("const _tmp_{d}_{d} = _star_list_{d};\n", .{ lid, s_idx, lid });
            try self.emitIndent();
            try emitTargetAssign(self, targets[s_idx], lid, s_idx, declared_vars);

            for (targets[s_idx + 1 ..], 0..) |tgt, k| {
                const actual_idx = s_idx + 1 + k;
                const from_end = suffix_count - k;
                try self.emitIndent();
                try self.emit("const _tmp_{d}_{d} = _tup_{d}.getItem(_tup_len_{d} - {d});\n", .{ lid, actual_idx, lid, lid, from_end });
                try self.emitIndent();
                try emitTargetAssign(self, tgt, lid, actual_idx, declared_vars);
            }
        } else {
            if (!is_direct_rhs) {
                try self.emitIndent();
                try self.emit("const _tup_len_{d} = _tup_{d}.len();\n", .{ lid, lid });
                try self.emitIndent();
                if (self.try_depth > 0) {
                    try self.emit("if (_tup_len_{d} != {d}) break :try_blk_{d} error.ValueError;\n", .{ lid, targets.len, self.try_depth });
                } else {
                    try self.emit("if (_tup_len_{d} != {d}) return error.ValueError;\n", .{ lid, targets.len });
                }
            }
            for (targets, 0..) |tgt, idx| {
                try self.emitIndent();
                try self.emit("const _tmp_{d}_{d} = _tup_{d}.getItem({d});\n", .{ lid, idx, lid, idx });
                try self.emitIndent();
                try emitTargetAssign(self, tgt, lid, idx, declared_vars);
            }
        }
    }
}

fn emitTargetAssign(self: *Transpiler, tgt: *ast.Node, lid: usize, idx: usize, declared_vars: *std.StringHashMap(bool)) anyerror!void {
    switch (tgt.*) {
        .starred => |s| {
            try emitTargetAssign(self, s.value, lid, idx, declared_vars);
        },
        .identifier => |id| {
            if (self.scoped_aliases.get(id.name)) |alias| {
                try self.emit("{s} = _tmp_{d}_{d};\n", .{ alias, lid, idx });
                return;
            }
            const name = try self.escapeKeyword(id.name);
            defer self.allocator.free(name);
            const already_declared = declared_vars.contains(id.name);
            if (!already_declared) {
                try declared_vars.put(id.name, true);
                try self.emit("var {s} = _tmp_{d}_{d};\n", .{ name, lid, idx });
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{name});
            } else {
                try self.emit("{s} = _tmp_{d}_{d};\n", .{ name, lid, idx });
            }
        },
        .getattr => |g| {
            try self.transpileExpr(g.target);
            try self.emit(".{s} = _tmp_{d}_{d};\n", .{ g.attr, lid, idx });
        },
        .subscript => |s| {
            if (self.try_depth == 0) {
                try self.emit("try ", .{});
            }
            try self.transpileExpr(s.target);
            try self.emit(".setDynamicItem(", .{});
            try self.transpileExpr(s.index);
            try self.emit(", _tmp_{d}_{d});\n", .{ lid, idx });
        },
        else => {
            try self.emit("// Unhandled tuple assign target\n", .{});
        },
    }
}

pub fn transpileAnnDecl(self: *Transpiler, ad: anytype, declared_vars: *std.StringHashMap(bool)) !void {
    const already_decl = declared_vars.contains(ad.target);
    if (!already_decl) {
        try declared_vars.put(ad.target, true);
        if (self.is_strict) {
            if (ad.type_ann) |t| {
                try self.emit("var {s}: {s} = undefined;\n", .{ ad.target, mapType(t) });
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{ad.target});
            }
        } else {
            try self.emit("var {s} = Dynamic.initNone();\n", .{ad.target});
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{ad.target});
        }
    }
}

pub fn transpileAssign(self: *Transpiler, a: anytype, declared_vars: *std.StringHashMap(bool)) !void {
    const already_declared = declared_vars.contains(a.target);
    if (!already_declared) {
        try declared_vars.put(a.target, true);
        if (self.is_strict) {
            if (a.type_ann) |t| {
                try self.emit("var {s}: {s} = ", .{ a.target, mapType(t) });
                if (std.mem.eql(u8, t, "Dynamic") or std.mem.eql(u8, t, "...")) {
                    try self.emit("Dynamic.fromAny(", .{});
                    try self.transpileExprStrict(a.value);
                    try self.emit(")", .{});
                } else {
                    try self.transpileExprStrict(a.value);
                }
            } else {
                std.debug.print("Strict Mode Error: Variable '{s}' requires explicit static type annotation upon initialization.\n", .{a.target});
                return error.MissingTypeAnnotation;
            }
        } else {
            if (a.type_ann) |t| {
                try self.emit("var {s}: {s} = ", .{ a.target, mapType(t) });
                if (std.mem.eql(u8, t, "Dynamic") or std.mem.eql(u8, t, "...")) {
                    try self.emit("Dynamic.fromAny(", .{});
                    try self.transpileExprStrict(a.value);
                    try self.emit(")", .{});
                } else {
                    self.is_strict_expr = true;
                    defer self.is_strict_expr = false;
                    try self.transpileExprStrict(a.value);
                }
            } else {
                // Use escape analysis to avoid Dynamic if possible!
                if (self.escape_analyzer.variables.get(a.target)) |v_info| {
                    if (v_info.class == .stack and v_info.is_primitive) {
                        // We can use Zig's type inference!
                        const t = self.escape_analyzer.primitiveTypeString(a.value);
                        try self.emit("var {s}: {s} = ", .{ a.target, t });
                        self.is_strict_expr = true;
                        defer self.is_strict_expr = false;
                        try self.transpileExprStrict(a.value);
                        try self.emit(";\n", .{});
                        if (!already_declared) {
                            try self.emitIndent();
                            try self.emit("_ = &{s};\n", .{a.target});
                        }
                        return;
                    }
                }
                
                try self.emit("var {s} = ", .{ a.target });
                try self.transpileExpr(a.value);
            }
        }
    } else {
        const target_ident = self.scoped_aliases.get(a.target) orelse a.target;
        try self.emit("{s} = ", .{ target_ident });
        if (a.type_ann != null or self.is_strict) {
            if (a.type_ann) |t| {
                if (std.mem.eql(u8, t, "Dynamic") or std.mem.eql(u8, t, "...")) {
                    try self.emit("Dynamic.fromAny(", .{});
                    try self.transpileExprStrict(a.value);
                    try self.emit(")", .{});
                } else {
                    self.is_strict_expr = true;
                    defer self.is_strict_expr = false;
                    try self.transpileExprStrict(a.value);
                }
            } else {
                try self.transpileExprStrict(a.value);
            }
        } else {
            var is_stack_primitive = false;
            if (self.scoped_aliases.get(a.target) == null) {
                if (self.escape_analyzer.variables.get(a.target)) |v_info| {
                    if (v_info.class == .stack and v_info.is_primitive) {
                        is_stack_primitive = true;
                    }
                }
            }
            if (is_stack_primitive) {
                self.is_strict_expr = true;
                defer self.is_strict_expr = false;
                try self.transpileExprStrict(a.value);
            } else {
                try self.transpileExpr(a.value);
            }
        }
    }
    
    try self.emit(";\n", .{});
    
    if (!already_declared) {
        try self.emitIndent();
        const target_ident = self.scoped_aliases.get(a.target) orelse a.target;
        try self.emit("_ = &{s};\n", .{target_ident});
    }
}

pub fn transpileConstAssign(self: *Transpiler, a: anytype, declared_vars: *std.StringHashMap(bool)) !void {
    try declared_vars.put(a.target, true);
    if (a.type_ann) |t| {
        try self.emit("const {s}: {s} = ", .{ a.target, mapType(t) });
        try self.transpileExprStrict(a.value);
    } else {
        if (self.is_strict) {
            std.debug.print("Strict Mode Error: Constant '{s}' requires explicit static type annotation.\n", .{a.target});
            return error.MissingTypeAnnotation;
        } else {
            try self.emit("const {s} = ", .{ a.target });
            try self.transpileExpr(a.value);
        }
    }
    try self.emit(";\n", .{});
    
    try self.emitIndent();
    try self.emit("_ = &{s};\n", .{a.target});
}

pub fn transpileSubscriptAssign(self: *Transpiler, s: anytype) !void {
    if (self.try_depth == 0) {
        try self.emit("try ", .{});
    }
    try self.transpileExpr(s.target);
    try self.emit(".setDynamicItem(", .{});
    try self.transpileExpr(s.index);
    try self.emit(", ", .{});
    try self.transpileExpr(s.value);
    try self.emit(");\n", .{});
}
