const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

fn isClassInstantiation(node: *ast.Node) bool {
    switch (node.*) {
        .call => |c| {
            if (c.callee.* == .identifier) {
                const name = c.callee.identifier.name;
                return name.len > 0 and name[0] >= 'A' and name[0] <= 'Z';
            }
            return false;
        },
        else => return false,
    }
}

fn collectTargetVars(target: *ast.Node, vars: *std.StringHashMap(bool)) anyerror!void {
    switch (target.*) {
        .identifier => |id| try vars.put(id.name, true),
        .starred => |s| try collectTargetVars(s.value, vars),
        .list_expr, .tuple_expr => |lt| {
            for (lt.items.items) |item| try collectTargetVars(item, vars);
        },
        else => {},
    }
}

fn collectVars(node: *ast.Node, vars: *std.StringHashMap(bool)) anyerror!void {
    switch (node.*) {
        .assign => |a| {
            // Don't pre-declare variables assigned from class instantiations —
            // let the type be inferred from the class struct at assignment site.
            if (!isClassInstantiation(a.value)) {
                try vars.put(a.target, true);
            }
            try collectVars(a.value, vars);
        },
        .tuple_assign => |ta| {
            for (ta.targets.items) |tgt| try collectTargetVars(tgt, vars);
            try collectVars(ta.value, vars);
        },
        .chained_assign => |ca| {
            for (ca.targets.items) |tgt| try collectTargetVars(tgt, vars);
            try collectVars(ca.value, vars);
        },
        .compound_stmt => |cs| {
            for (cs.items.items) |stmt| try collectVars(stmt, vars);
        },
        .ann_decl => |ad| {
            try vars.put(ad.target, true);
        },
        .for_stmt => |f| {
            // iterator variables should also be collected
            const iter_str_raw = std.mem.trim(u8, f.iterator, " ");
            var has_comma = false;
            for (iter_str_raw) |c| {
                if (c == ',') { has_comma = true; break; }
            }
            if (has_comma) {
                var it_decl = std.mem.splitSequence(u8, iter_str_raw, ",");
                while (it_decl.next()) |item_raw| {
                    const item = std.mem.trim(u8, item_raw, " ");
                    if (item.len > 0) try vars.put(item, true);
                }
            } else {
                try vars.put(iter_str_raw, true);
            }
            try collectVars(f.iterable, vars);
            for (f.body.items) |stmt| try collectVars(stmt, vars);
        },
        .with_stmt => |w| {
            if (w.as_name) |n| try vars.put(n, true);
            try collectVars(w.context_expr, vars);
            for (w.body.items) |stmt| try collectVars(stmt, vars);
        },
        .if_stmt => |ifs| {
            try collectVars(ifs.condition, vars);
            for (ifs.then_branch.items) |stmt| try collectVars(stmt, vars);
            for (ifs.elifs.items) |elif| {
                try collectVars(elif.condition, vars);
                for (elif.then_branch.items) |stmt| try collectVars(stmt, vars);
            }
            if (ifs.else_branch) |eb| {
                for (eb.items) |stmt| try collectVars(stmt, vars);
            }
        },
        .while_stmt => |w| {
            try collectVars(w.condition, vars);
            for (w.body.items) |stmt| try collectVars(stmt, vars);
        },
        .try_stmt => |t| {
            for (t.body.items) |stmt| try collectVars(stmt, vars);
            for (t.except_clauses.items) |c| {
                for (c.body.items) |stmt| try collectVars(stmt, vars);
            }
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| try collectVars(stmt, vars);
            }
            if (t.else_branch) |elb| {
                for (elb.items) |stmt| try collectVars(stmt, vars);
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| try collectVars(stmt, vars);
            }
        },
        .list_expr, .tuple_expr => |l| {
            for (l.items.items) |item| try collectVars(item, vars);
        },
        .dict_expr => |d| {
            for (d.keys.items) |key| try collectVars(key, vars);
            for (d.values.items) |val| try collectVars(val, vars);
        },
        .binary => |b| {
            try collectVars(b.left, vars);
            try collectVars(b.right, vars);
        },
        .unary => |u| {
            try collectVars(u.right, vars);
        },
        .call => |c| {
            try collectVars(c.callee, vars);
            for (c.args.items) |arg| try collectVars(arg, vars);
        },
        .method_call => |m| {
            try collectVars(m.target, vars);
            for (m.args.items) |arg| try collectVars(arg, vars);
        },
        .return_stmt => |r| {
            if (r.value) |v| try collectVars(v, vars);
        },
        else => {}
    }
}

const mapType = @import("../transpiler.zig").Transpiler.mapType;
const isRecursive = @import("../analysis/analysis.zig").isRecursive;

pub fn transpileDefStmt(self: *Transpiler, d: anytype, global_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) !void {
    const orig_strict = self.is_strict;
    if (d.is_strict) self.is_strict = true;
    
    var is_rec = false;
    for (d.body.items) |body_stmt| {
        if (isRecursive(body_stmt, d.name)) is_rec = true;
    }
    
    if (self.is_strict) try strict_funcs.put(d.name, true);
    const can_inline = !is_rec and d.body.items.len <= 2 and self.is_strict;

    if (d.is_async) {
        try self.emit("pub fn {s}(", .{d.name});
        for (d.params.items, 0..) |p, idx| {
            const p_name = if (global_vars.contains(p.name))
                try std.fmt.allocPrint(self.allocator, "__sundapy_p_{s}", .{p.name})
            else
                try self.allocator.dupe(u8, p.name);
            defer self.allocator.free(p_name);
            try self.emit("{s}: Dynamic", .{p_name});
            if (idx < d.params.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(") anyerror!Dynamic {{\n", .{});
        self.indent_level += 1;
        try self.emitIndent();
        try self.emit("var _args = std.ArrayList(Dynamic).empty;\n", .{});
        try self.emitIndent();
        try self.emit("_ = &_args;\n", .{});
        for (d.params.items) |p| {
            try self.emitIndent();
            const p_name = if (global_vars.contains(p.name))
                try std.fmt.allocPrint(self.allocator, "__sundapy_p_{s}", .{p.name})
            else
                try self.allocator.dupe(u8, p.name);
            defer self.allocator.free(p_name);
            try self.emit("try _args.append(alloc, {s});\n", .{p_name});
        }
        try self.emitIndent();
        try self.emit("return try @import(\"asyncio.zig\").createTask({s}_async_impl, _args.items);\n", .{d.name});
        self.indent_level -= 1;
        try self.emit("}}\n", .{});
        
        try self.emit("pub fn {s}_async_impl(_args: []const Dynamic) anyerror!Dynamic {{\n", .{d.name});
        self.indent_level += 1;
        try self.emitIndent();
        if (d.params.items.len == 0) try self.emit("_ = _args;\n", .{});
        for (d.params.items, 0..) |p, idx| {
            try self.emitIndent();
            if (global_vars.contains(p.name)) {
                const v_ident = try std.fmt.allocPrint(self.allocator, "__sundapy_v_{s}", .{p.name});
                defer self.allocator.free(v_ident);
                try self.emit("var {s} = _args[{d}];\n", .{ v_ident, idx });
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{v_ident});
                try self.scoped_aliases.put(p.name, try self.allocator.dupe(u8, v_ident));
            } else {
                try self.emit("var {s} = _args[{d}];\n", .{ p.name, idx });
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{p.name});
            }
        }
    } else {
        if (can_inline) {
            try self.emit("pub inline fn {s}(", .{d.name});
        } else {
            try self.emit("pub fn {s}(", .{d.name});
        }
        
        for (d.params.items, 0..) |p, idx| {
            const p_type = if (!self.is_strict) "Dynamic" else if (p.type_ann) |t| mapType(t) else {
                std.debug.print("Strict Mode Error: Parameter '{s}' requires explicit static type annotation.\n", .{p.name});
                return error.MissingTypeAnnotation;
            };
            const p_name = if (global_vars.contains(p.name))
                try std.fmt.allocPrint(self.allocator, "__sundapy_p_{s}", .{p.name})
            else
                try self.allocator.dupe(u8, p.name);
            defer self.allocator.free(p_name);
            try self.emit("{s}: {s}", .{ p_name, p_type });
            if (idx < d.params.items.len - 1) try self.emit(", ", .{});
        }
        
        try self.emit(") anyerror!", .{});
        
        if (!self.is_strict) {
            try self.emit("Dynamic {{\n", .{});
        } else if (d.return_type) |rt| {
            try self.emit("{s} {{\n", .{mapType(rt)});
        } else {
            std.debug.print("Strict Mode Error: Function '{s}' requires explicit return type annotation (use -> void if none).\n", .{d.name});
            return error.MissingTypeAnnotation;
        }
        self.indent_level += 1;
        const compiler = @import("../../core/compiler.zig");
        if (compiler.is_release_fast) {
            try self.emitIndent();
            try self.emit("@setRuntimeSafety(false);\n", .{});
        } else if (self.is_strict) {
            std.debug.print("Emitting setRuntimeSafety for {s}\n", .{d.name});
            try self.emitIndent();
            try self.emit("@setRuntimeSafety(true);\n", .{});
        }
    }
    
    for (d.params.items) |p| {
        try self.emitIndent();
        if (global_vars.contains(p.name)) {
            const p_ident = try std.fmt.allocPrint(self.allocator, "__sundapy_p_{s}", .{p.name});
            defer self.allocator.free(p_ident);
            const v_ident = try std.fmt.allocPrint(self.allocator, "__sundapy_v_{s}", .{p.name});
            defer self.allocator.free(v_ident);
            try self.emit("_ = if (true) {s} else {{}};\n", .{p_ident});
            try self.emitIndent();
            try self.emit("var {s} = {s};\n", .{ v_ident, p_ident });
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{v_ident});
            try self.scoped_aliases.put(p.name, try self.allocator.dupe(u8, v_ident));
        } else {
            const esc_p = try self.escapeKeyword(p.name);
            defer self.allocator.free(esc_p);
            try self.emit("_ = if (true) {s} else {{}};\n", .{esc_p});
        }
    }

    var declared_vars = std.StringHashMap(bool).init(self.allocator);
    var all_vars = std.StringHashMap(bool).init(self.allocator);
    defer all_vars.deinit();
    for (d.body.items) |stmt| {
        try collectVars(stmt, &all_vars);
    }
    for (d.params.items) |p| {
        _ = all_vars.remove(p.name);
    }
    
    var top_level_assigned = std.StringHashMap(bool).init(self.allocator);
    defer top_level_assigned.deinit();
    for (d.body.items) |stmt| {
        if (stmt.* == .assign) {
            try top_level_assigned.put(stmt.assign.target, true);
        } else if (stmt.* == .tuple_assign or stmt.* == .chained_assign) {
            const targets = if (stmt.* == .tuple_assign) stmt.tuple_assign.targets.items else stmt.chained_assign.targets.items;
            for (targets) |tgt| {
                try collectTargetVars(tgt, &top_level_assigned);
            }
        }
    }
    
    var var_it = all_vars.keyIterator();
    while (var_it.next()) |v_ptr| {
        const v = v_ptr.*;
        if (!declared_vars.contains(v)) {
            // In strict mode, variables are declared at assignment site with explicit static type annotations
            if (self.is_strict) continue;
            // Skip global vars (would shadow the global declaration)
            if (global_vars.contains(v)) continue;
            // Skip vars assigned at top level of function body; they will be declared with proper type inference at assignment site!
            if (top_level_assigned.contains(v)) continue;
            if (self.escape_analyzer.variables.get(v)) |v_info| {
                if (v_info.class == .stack and v_info.is_primitive) {
                    try declared_vars.put(v, true);
                    try self.emitIndent();
                    const init_val: []const u8 = if (std.mem.eql(u8, v_info.primitive_type, "bool"))
                        "false"
                    else if (std.mem.startsWith(u8, v_info.primitive_type, "f"))
                        "0.0"
                    else
                        "0";
                    try self.emit("var {s}: {s} = {s};\n", .{ v, v_info.primitive_type, init_val });
                    try self.emitIndent();
                    try self.emit("_ = &{s};\n", .{v});
                    continue;
                }
            }
            if (self.escape_analyzer.variables.getPtr(v)) |v_info| {
                v_info.is_primitive = false;
            }
            try declared_vars.put(v, true);
            try self.emitIndent();
            try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{v});
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{v});
        }
    }

    var contains_yield = false;
    for (d.body.items) |body_stmt| {
        if (@import("../analysis/analysis.zig").hasYield(body_stmt)) {
            contains_yield = true;
            break;
        }
    }
    const orig_has_yield = self.current_func_has_yield;
    self.current_func_has_yield = contains_yield;
    defer self.current_func_has_yield = orig_has_yield;

    if (!self.is_strict and contains_yield) {
        try self.emitIndent();
        try self.emit("var _yield_list = dynamic.Dynamic.initList(std.ArrayList(Dynamic).empty);\n", .{});
        try self.emitIndent();
        try self.emit("var _has_yielded = false;\n", .{});
        try self.emitIndent();
        try self.emit("_ = &_yield_list; _ = &_has_yielded;\n", .{});
    }
    defer declared_vars.deinit();
    
    var it = global_vars.iterator();
    while (it.next()) |entry| {
        try declared_vars.put(entry.key_ptr.*, true);
    }
    for (d.params.items) |p| {
        try declared_vars.put(p.name, true);
    }
    
    for (d.body.items) |body_stmt| {
        try self.transpileStmt(body_stmt, &declared_vars, strict_funcs);
    }
    
    var last_is_return = false;
    if (d.body.items.len > 0) {
        if (d.body.items[d.body.items.len - 1].* == .return_stmt) {
            last_is_return = true;
        }
    }
    
    if (d.return_type == null and !last_is_return) {
        if (!self.is_strict) {
            if (contains_yield) {
                try self.emitIndent();
                try self.emit("if (_has_yielded) return _yield_list else return Dynamic{{ .value = .none_type }};\n", .{});
            } else {
                try self.emitIndent();
                try self.emit("return Dynamic{{ .value = .none_type }};\n", .{});
            }
        } else {
            try self.emitIndent();
            try self.emit("return;\n", .{});
        }
    }
    
    for (d.params.items) |p| {
        if (global_vars.contains(p.name)) {
            if (self.scoped_aliases.fetchRemove(p.name)) |entry| {
                self.allocator.free(entry.value);
            }
        }
    }

    self.indent_level -= 1;
    try self.emit("}}\n\n", .{});
    self.is_strict = orig_strict;
}
