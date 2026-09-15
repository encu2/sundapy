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
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| try collectVars(stmt, vars);
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| try collectVars(stmt, vars);
            }
        },
        .list_expr => |l| {
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
            try self.emit("{s}: Dynamic", .{p.name});
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
            try self.emit("try _args.append(alloc, {s});\n", .{p.name});
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
            try self.emit("var {s} = _args[{d}];\n", .{p.name, idx});
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{p.name});
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
            try self.emit("{s}: {s}", .{p.name, p_type});
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
        if (self.is_strict) {
            std.debug.print("Emitting setRuntimeSafety for {s}\n", .{d.name});
            try self.emitIndent();
            try self.emit("@setRuntimeSafety(true);\n", .{});
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
            // In non-strict mode, skip vars that escape analysis identifies as stack primitives.
            // Those will be declared inline at their first assignment site with the correct primitive type.
            if (self.escape_analyzer.variables.get(v)) |v_info| {
                if (v_info.class == .stack and v_info.is_primitive) continue;
            }
            try declared_vars.put(v, true);
            try self.emitIndent();
            try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{v});
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{v});
        }
    }

    try self.emitIndent();
    try self.emit("var _yield_list = dynamic.Dynamic.initList(std.ArrayList(Dynamic).empty);\n", .{});
    try self.emitIndent();
    try self.emit("_ = &_yield_list;\n", .{});
    try self.emitIndent();
    try self.emit("var _has_yielded = false;\n", .{});
    try self.emitIndent();
    try self.emit("_ = &_has_yielded;\n", .{});
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
            try self.emitIndent();
            try self.emit("if (_has_yielded) return _yield_list else return Dynamic{{ .value = .none_type }};\n", .{});
        } else {
            try self.emitIndent();
            try self.emit("return;\n", .{});
        }
    }
    
    self.indent_level -= 1;
    try self.emit("}}\n\n", .{});
    self.is_strict = orig_strict;
}
