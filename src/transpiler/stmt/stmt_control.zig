const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileIfStmt(self: *Transpiler, ifs: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
        try self.emit("if (", .{});
        if (self.is_strict or self.escape_analyzer.isPrimitive(ifs.condition)) {
            try self.transpileExprStrict(ifs.condition);
            try self.emit(") {{\n", .{});
        } else {
            try self.emit("(", .{});
            try self.transpileExpr(ifs.condition);
            try self.emit(").toBool()) {{\n", .{});
        }
        
        self.indent_level += 1;
        for (ifs.then_branch.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}", .{});
        
        for (ifs.elifs.items) |elif_branch| {
            try self.emit(" else if (", .{});
            if (self.is_strict or self.escape_analyzer.isPrimitive(elif_branch.condition)) {
                try self.transpileExprStrict(elif_branch.condition);
                try self.emit(") {{\n", .{});
            } else {
                try self.emit("(", .{});
                try self.transpileExpr(elif_branch.condition);
                try self.emit(").toBool()) {{\n", .{});
            }
            self.indent_level += 1;
            for (elif_branch.then_branch.items) |stmt| {
                try self.transpileStmt(stmt, declared_vars, strict_funcs);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}", .{});
        }
        
        if (ifs.else_branch) |eb| {
            try self.emit(" else {{\n", .{});
            self.indent_level += 1;
            for (eb.items) |stmt| {
                try self.transpileStmt(stmt, declared_vars, strict_funcs);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}", .{});
        }
        try self.emit("\n", .{});
    }

pub const transpileTryStmt = @import("stmt_try.zig").transpileTryStmt;

pub fn transpileWhileStmt(self: *Transpiler, w: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
        try self.emit("while (", .{});
        if (self.is_strict or self.escape_analyzer.isPrimitive(w.condition)) {
            try self.transpileExprStrict(w.condition);
            try self.emit(") {{\n", .{});
        } else {
            try self.emit("(", .{});
            try self.transpileExpr(w.condition);
            try self.emit(").toBool()) {{\n", .{});
        }
        self.indent_level += 1;
        for (w.body.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
    }

pub fn transpileForStmt(self: *Transpiler, f: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
    if (try @import("stmt_for_idiom.zig").tryLowerForStmt(self, f, declared_vars, strict_funcs)) {
        return;
    }
    try self.emit("{{\n", .{});
        self.indent_level += 1;
        
        try self.emitIndent();
        try self.emit("var iter_obj_{d} = ", .{self.indent_level});
        try self.transpileExpr(f.iterable);
        try self.emit(";\n", .{});
        
        try self.emitIndent();
        try self.emit("var iter_idx_{d}: usize = 0;\n", .{self.indent_level});
        
        try self.emitIndent();
                const pre_iter_str_raw = std.mem.trim(u8, f.iterator, " ");
        var pre_has_comma = false;
        for (pre_iter_str_raw) |c| {
            if (c == ',') {
                pre_has_comma = true;
                break;
            }
        }
        if (pre_has_comma) {
            var it_decl = std.mem.splitSequence(u8, pre_iter_str_raw, ",");
            while (it_decl.next()) |item_raw| {
                var item = std.mem.trim(u8, item_raw, " ");
                while (item.len > 0 and (item[0] == '*' or item[0] == ' ')) item = item[1..];
                if (item.len == 0) continue;
                if (!declared_vars.contains(item)) {
                    // try declared_vars.put(item, true);
                    try self.emitIndent();
                    if (self.is_strict) {
                        try self.emit("var {s}: i64 = 0;\n", .{item});
                    } else {
                        try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{item});
                    }
                    try self.emitIndent();
                    try self.emit("_ = &{s};\n", .{item});
                }
            }
        } else {
            if (!declared_vars.contains(pre_iter_str_raw)) {
                // try declared_vars.put(pre_iter_str_raw, true);
                try self.emitIndent();
                if (self.is_strict) {
                    try self.emit("var {s}: i64 = 0;\n", .{pre_iter_str_raw});
                } else {
                    try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{pre_iter_str_raw});
                }
                try self.emitIndent();
                try self.emit("_ = &{s};\n", .{pre_iter_str_raw});
            }
        }
        try self.emit("while (iter_idx_{d} < iter_obj_{d}.len()) : (iter_idx_{d} += 1) {{\n", .{self.indent_level, self.indent_level, self.indent_level});
        self.indent_level += 1;
        
        try self.emitIndent();
        const iter_str_raw = std.mem.trim(u8, f.iterator, " ");
        var has_comma = false;
        for (iter_str_raw) |c| {
            if (c == ',') {
                has_comma = true;
                break;
            }
        }
        
        if (has_comma) {
            const unpack_var = try std.fmt.allocPrint(self.allocator, "_unpack_{d}", .{self.indent_level});
            defer self.allocator.free(unpack_var);
            
            try self.emit("var {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{unpack_var, self.indent_level - 1, self.indent_level - 1});
            
            var it_count = std.mem.splitSequence(u8, iter_str_raw, ",");
            var total_targets: usize = 0;
            var star_idx: ?usize = null;
            while (it_count.next()) |part_raw| {
                const part = std.mem.trim(u8, part_raw, " ");
                if (part.len == 0) continue;
                if (std.mem.startsWith(u8, part, "*")) star_idx = total_targets;
                total_targets += 1;
            }

            var it_decl = std.mem.splitSequence(u8, iter_str_raw, ",");
            var item_idx: usize = 0;
            if (star_idx) |s_idx| {
                const suffix_count = total_targets - 1 - s_idx;
                while (it_decl.next()) |item_raw| {
                    const item = std.mem.trim(u8, item_raw, " ");
                    if (item.len == 0) continue;
                    try self.emitIndent();
                    if (item_idx < s_idx) {
                        try self.emit("{s} = {s}.getItem({d});\n", .{ item, unpack_var, item_idx });
                    } else if (item_idx == s_idx) {
                        const star_name = std.mem.trimStart(u8, item, "* ");
                        const lid = self.indent_level;
                        try self.emit("var _star_list_{d} = Dynamic.initList(.empty);\n", .{lid});
                        try self.emitIndent();
                        try self.emit("const _star_end_{d} = if ({s}.len() >= {d}) {s}.len() - {d} else {d};\n", .{ lid, unpack_var, suffix_count, unpack_var, suffix_count, s_idx });
                        try self.emitIndent();
                        try self.emit("var _star_i_{d}: usize = {d};\n", .{ lid, s_idx });
                        try self.emitIndent();
                        try self.emit("while (_star_i_{d} < _star_end_{d}) : (_star_i_{d} += 1) {{\n", .{ lid, lid, lid });
                        try self.emitIndent();
                        try self.emit("    _star_list_{d}.value.list_type.items.append(alloc, {s}.getItem(_star_i_{d})) catch unreachable;\n", .{ lid, unpack_var, lid });
                        try self.emitIndent();
                        try self.emit("}}\n", .{});
                        try self.emitIndent();
                        try self.emit("{s} = _star_list_{d};\n", .{ star_name, lid });
                    } else {
                        const from_end = total_targets - item_idx;
                        try self.emit("{s} = {s}.getItem({s}.len() - {d});\n", .{ item, unpack_var, unpack_var, from_end });
                    }
                    item_idx += 1;
                }
            } else {
                while (it_decl.next()) |item_raw| {
                    const item = std.mem.trim(u8, item_raw, " ");
                    if (item.len == 0) continue;
                    try self.emitIndent();
                    try self.emit("{s} = try {s}.getDynamicItem(dynamic.Dynamic{{ .value = .{{ .i64_type = {d} }} }});\n", .{item, unpack_var, item_idx});
                    item_idx += 1;
                }
            }
        } else {
            if (self.is_strict) {
                try self.emit("{s} = iter_obj_{d}.getItem(iter_idx_{d}).value.i64_type;\n", .{iter_str_raw, self.indent_level - 1, self.indent_level - 1});
            } else {
                try self.emit("{s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{iter_str_raw, self.indent_level - 1, self.indent_level - 1});
            }
        }
        
        for (f.body.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
        
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
        
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
    }


pub fn transpileWithStmt(self: *Transpiler, w: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
    // Basic dynamic transpile for with_stmt
    const ctx_var = try std.fmt.allocPrint(self.allocator, "__with_ctx_{d}", .{self.indent_level});
    self.indent_level += 1;
    try self.emit("var {s} = ", .{ctx_var});
    try self.transpileExpr(w.context_expr);
    try self.emit(";\n", .{});
    
    // Call __enter__
    const enter_res = try std.fmt.allocPrint(self.allocator, "__with_res_{d}", .{self.indent_level});
    self.indent_level += 1;
    if (w.is_async) {
        try self.emit("const {s} = (blk_{d}: {{\n", .{enter_res, self.indent_level});
        try self.emit("    const T_target = @TypeOf({s});\n", .{ctx_var});
        try self.emit("    if (comptime T_target == dynamic.Dynamic) {{\n", .{});
        try self.emit("        var _args_arr = [_]dynamic.Dynamic{{}};\n", .{});
        try self.emit("        break :blk_{d} {s}.builtin_getattr(\"__aenter__\").builtin_call(alloc, &_args_arr, null);\n", .{self.indent_level, ctx_var});
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} {s}.__aenter__();\n", .{self.indent_level, ctx_var});
        try self.emit("    }}\n", .{});
        try self.emit("}} catch unreachable);\n", .{});
    } else {
        try self.emit("const {s} = (blk_{d}: {{\n", .{enter_res, self.indent_level});
        try self.emit("    const T_target = @TypeOf({s});\n", .{ctx_var});
        try self.emit("    if (comptime T_target == dynamic.Dynamic) {{\n", .{});
        try self.emit("        var _args_arr = [_]dynamic.Dynamic{{}};\n", .{});
        try self.emit("        break :blk_{d} {s}.builtin_getattr(\"__enter__\").builtin_call(alloc, &_args_arr, null);\n", .{self.indent_level, ctx_var});
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} {s}.__enter__();\n", .{self.indent_level, ctx_var});
        try self.emit("    }}\n", .{});
        try self.emit("}} catch unreachable);\n", .{});
    }
    
    if (w.as_name) |name| {
        if (!declared_vars.contains(name)) {
            try declared_vars.put(name, true);
            try self.emit("var {s} = {s};\n", .{name, enter_res});
            try self.emit("_ = &{s};\n", .{name});
        } else {
            try self.emit("{s} = {s};\n", .{name, enter_res});
        }
    } else {
        try self.emit("_ = &{s};\n", .{enter_res});
    }
    
    // Body
    for (w.body.items) |stmt| {
        try self.transpileStmt(stmt, declared_vars, strict_funcs);
    }
    
    // Call __exit__
    if (w.is_async) {
        try self.emit("    _ = (blk_{d}: {{\n", .{self.indent_level});
        try self.emit("        const T_target = @TypeOf({s});\n", .{ctx_var});
        try self.emit("        if (comptime T_target == dynamic.Dynamic) {{\n", .{});
        try self.emit("            var _args_arr = [_]dynamic.Dynamic{{dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone()}};\n", .{});
        try self.emit("            break :blk_{d} {s}.builtin_getattr(\"__aexit__\").builtin_call(alloc, &_args_arr, null) catch dynamic.None;\n", .{self.indent_level, ctx_var});
        try self.emit("        }} else if (comptime (@typeInfo(T_target) == .@\"struct\" or @typeInfo(T_target) == .@\"union\") and @hasDecl(T_target, \"__aexit__\")) {{\n", .{});
        try self.emit("            break :blk_{d} {s}.__aexit__(dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone()) catch dynamic.None;\n", .{self.indent_level, ctx_var});
        try self.emit("        }} else {{\n", .{});
        try self.emit("            break :blk_{d} dynamic.None;\n", .{self.indent_level});
        try self.emit("        }}\n", .{});
        try self.emit("    }});\n", .{});
    } else {
        try self.emit("    _ = (blk_{d}: {{\n", .{self.indent_level});
        try self.emit("        const T_target = @TypeOf({s});\n", .{ctx_var});
        try self.emit("        if (comptime T_target == dynamic.Dynamic) {{\n", .{});
        try self.emit("            var _args_arr = [_]dynamic.Dynamic{{dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone()}};\n", .{});
        try self.emit("            break :blk_{d} {s}.builtin_getattr(\"__exit__\").builtin_call(alloc, &_args_arr, null) catch dynamic.None;\n", .{self.indent_level, ctx_var});
        try self.emit("        }} else if (comptime (@typeInfo(T_target) == .@\"struct\" or @typeInfo(T_target) == .@\"union\") and @hasDecl(T_target, \"__exit__\")) {{\n", .{});
        try self.emit("            break :blk_{d} {s}.__exit__(dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone(), dynamic.Dynamic.initNone()) catch dynamic.None;\n", .{self.indent_level, ctx_var});
        try self.emit("        }} else {{\n", .{});
        try self.emit("            break :blk_{d} dynamic.None;\n", .{self.indent_level});
        try self.emit("        }}\n", .{});
        try self.emit("    }});\n", .{});
    }
}

pub fn transpileYieldStmt(self: *Transpiler, y: anytype) anyerror!void {
    try self.emit("_ = ", .{});
    if (y.value) |v| {
        try self.transpileExpr(v);
    } else {
        try self.emit("dynamic.None", .{});
    }
    try self.emit("; // NOTE: yield not fully supported natively\n", .{});
}
