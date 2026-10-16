const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

fn getRootId(node: *ast.Node) ?[]const u8 {
    return switch (node.*) {
        .identifier => |i| i.name,
        .getattr => |g| getRootId(g.target),
        else => null,
    };
}

fn emitDirectTarget(self: *Transpiler, node: *ast.Node) anyerror!void {
    switch (node.*) {
        .identifier => |i| {
            const esc = try self.escapeKeyword(i.name);
            defer self.allocator.free(esc);
            try self.emit("{s}", .{esc});
        },
        .getattr => |g| {
            try emitDirectTarget(self, g.target);
            try self.emit(".{s}", .{g.attr});
        },
        else => try self.transpileExpr(node),
    }
}

pub fn transpileStrictMethodCall(self: *Transpiler, m: anytype) anyerror!void {
    if (try @import("expr_idiom_bit.zig").tryLowerBitMethodCall(self, m)) return;
    if (try @import("expr_math_intrinsics.zig").tryLowerMathIntrinsic(self, m)) return;
    const is_class = (m.method.len > 0 and m.method[0] >= 'A' and m.method[0] <= 'Z');
    if (is_class) {
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("(blk_{d}: {{\n", .{lid});
        try self.emitIndent();
        try self.emit("    const _target_{d} = ", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emitIndent();
        try self.emit("    const T_target_{d} = @TypeOf(_target_{d});\n", .{lid, lid});
        try self.emitIndent();
        try self.emit("    if (comptime T_target_{d} == dynamic.Dynamic or (T_target_{d} == type and @hasDecl(_target_{d}, \"builtin_getattr\"))) {{\n", .{ lid, lid, lid });
        try self.emitIndent();
        try self.emit("        var _args_arr = [_]dynamic.Dynamic{{", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.emit("dynamic.Dynamic.fromAny(", .{}); try self.transpileExprStrict(arg); try self.emit(")", .{});
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit("}};\n", .{});
        if (m.kwargs.items.len > 0) {
            try self.emitIndent();
            try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
            for (m.kwargs.items) |kw| {
                try self.emitIndent();
                try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
                if (self.is_strict) {
                    try self.emit("dynamic.Dynamic.fromAny(", .{}); try self.transpileExprStrict(kw.value); try self.emit(")", .{});
                } else {
                    try self.transpileExpr(kw.value);
                }
                try self.emit(") catch {{}};\n", .{});
            }
            try self.emitIndent();
            try self.emit("        break :blk_{d} try _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, lid, m.method});
        } else {
            try self.emitIndent();
            try self.emit("        break :blk_{d} try _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null);\n", .{lid, lid, m.method});
        }
        try self.emitIndent();
        try self.emit("    }} else {{\n", .{});
        try self.emitIndent();
        try self.emit("        var obj = _target_{d}.{s}{{}};\n", .{lid, m.method});
        try self.emitIndent();
        try self.emit("        if (@hasDecl(@TypeOf(obj), \"__init__\")) {{\n", .{});
        try self.emitIndent();
        try self.emit("            _ = try obj.__init__(", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        try self.emitIndent();
        try self.emit("        }}\n", .{});
        try self.emitIndent();
        try self.emit("        break :blk_{d} obj;\n", .{lid});
        try self.emitIndent();
        try self.emit("    }}\n", .{});
        try self.emit("}})", .{});
        return;
    }
    const is_string_method = std.mem.eql(u8, m.method, "split") or std.mem.eql(u8, m.method, "replace") or (std.mem.eql(u8, m.method, "join") and m.args.items.len > 0) or std.mem.eql(u8, m.method, "upper") or std.mem.eql(u8, m.method, "lower") or std.mem.eql(u8, m.method, "startswith") or std.mem.eql(u8, m.method, "endswith") or std.mem.eql(u8, m.method, "find") or std.mem.eql(u8, m.method, "strip") or std.mem.eql(u8, m.method, "lstrip") or std.mem.eql(u8, m.method, "rstrip");
    const is_list_method = std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "pop") or std.mem.eql(u8, m.method, "sort") or std.mem.eql(u8, m.method, "insert") or std.mem.eql(u8, m.method, "remove") or std.mem.eql(u8, m.method, "reverse") or std.mem.eql(u8, m.method, "count") or std.mem.eql(u8, m.method, "index") or std.mem.eql(u8, m.method, "clear") or std.mem.eql(u8, m.method, "copy") or std.mem.eql(u8, m.method, "extend");
    const is_general_method = !(is_string_method or is_list_method);
    
    var target_is_module = false;
    if (getRootId(m.target)) |root_id| {
        for (self.imported_modules.items) |mod| {
            if (std.mem.eql(u8, root_id, mod)) {
                target_is_module = true;
                break;
            }
        }
        if (!target_is_module and self.module_aliases.get(root_id) != null) {
            target_is_module = true;
        }
        if (!target_is_module and (self.classes.contains(root_id) or (root_id.len > 0 and root_id[0] >= 'A' and root_id[0] <= 'Z'))) {
            target_is_module = true;
        }
    }
    
    if (target_is_module) {
        var is_c_import = false;
        if (getRootId(m.target)) |root_name| {
            if (self.c_imported_modules.contains(root_name)) {
                is_c_import = true;
            } else if (self.module_aliases.get(root_name)) |orig| {
                if (std.mem.endsWith(u8, orig, ".h") or std.mem.endsWith(u8, orig, ".c")) {
                    is_c_import = true;
                }
            }
        }

        if (is_c_import) {
            self.label_counter += 1;
            const lid = self.label_counter;
            try self.emit("((blk_{d}: {{\n", .{lid});
            try self.emit("    const _c_fn = ", .{});
            try emitDirectTarget(self, m.target);
            try self.emit(".{s};\n", .{m.method});
            if (m.args.items.len > 0) {
                try self.emit("    const _c_fn_info = @typeInfo(@TypeOf(_c_fn)).@\"fn\";\n", .{});
            }
            try self.emit("    const _c_ret = _c_fn(", .{});
            for (m.args.items, 0..) |arg, idx| {
                try self.emit("_sundapy_cast_param(_sundapy_param_type(_c_fn_info, {d}), ", .{idx});
                if (self.is_strict) {
                    try self.transpileExprStrict(arg);
                } else {
                    try self.transpileExpr(arg);
                }
                try self.emit(")", .{});
                if (idx < m.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(");\n", .{});
            if (self.is_strict) {
                try self.emit("    break :blk_{d} _c_ret;\n", .{lid});
            } else {
                try self.emit("    break :blk_{d} Dynamic.fromAny(_c_ret);\n", .{lid});
            }
            try self.emit("}}))", .{});
            return;
        }

        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("((blk_{d}: {{\n", .{lid});
        try self.emit("    const _target_{d} = ", .{lid});
        try emitDirectTarget(self, m.target);
        try self.emit(";\n", .{});
        try self.emit("    const _T_target_{d} = if (comptime @TypeOf(_target_{d}) == type) _target_{d} else @TypeOf(_target_{d});\n", .{ lid, lid, lid, lid });
        try self.emit("    const _T_info_{d} = @typeInfo(_T_target_{d});\n", .{ lid, lid });
        try self.emit("    if (comptime (_T_info_{d} == .@\"struct\" or _T_info_{d} == .@\"union\" or _T_info_{d} == .@\"enum\" or _T_info_{d} == .@\"opaque\") and @hasDecl(_T_target_{d}, \"{s}\")) {{\n", .{ lid, lid, lid, lid, lid, m.method });
        try self.emit("        if (comptime @TypeOf(_target_{d}) == type and @TypeOf(_target_{d}.{s}) == type) {{\n", .{ lid, lid, m.method });
        try self.emit("            const _T_{d} = _target_{d}.{s};\n", .{lid, lid, m.method});
        try self.emit("            if (comptime @hasDecl(_T_{d}, \"init\")) {{\n", .{lid});
        try self.emit("                const _ifn_{d} = _T_{d}.init;\n", .{lid, lid});
        if (m.args.items.len > 0) {
            try self.emit("                const _iinfo_{d} = @typeInfo(@TypeOf(_ifn_{d})).@\"fn\";\n", .{lid, lid});
        }
        try self.emit("                const _raw_ir_{d} = _ifn_{d}(", .{lid, lid});
        for (m.args.items, 0..) |arg, idx| {
            try self.emit("_sundapy_cast_param(_sundapy_param_type(_iinfo_{d}, {d}), ", .{lid, idx});
            if (self.is_strict) { try self.transpileExprStrict(arg); } else { try self.transpileExpr(arg); }
            try self.emit(")", .{});
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        if (self.try_depth > 0) {
            try self.emit("                const _ir_{d} = if (@typeInfo(@TypeOf(_raw_ir_{d})) == .error_union) (_raw_ir_{d} catch |err_{d}| break :try_blk_{d} err_{d}) else _raw_ir_{d};\n", .{ lid, lid, lid, lid, self.try_depth, lid, lid });
        } else {
            try self.emit("                const _ir_{d} = if (@typeInfo(@TypeOf(_raw_ir_{d})) == .error_union) try _raw_ir_{d} else _raw_ir_{d};\n", .{ lid, lid, lid, lid });
        }
        try self.emit("                break :blk_{d} _ir_{d};\n", .{lid, lid});
        try self.emit("            }} else {{\n", .{});
        try self.emit("                var _obj_{d} = _T_{d}{{}};\n", .{lid, lid});
        try self.emit("                if (@hasDecl(_T_{d}, \"__init__\")) {{\n", .{lid});
        try self.emit("                    _ = try _obj_{d}.__init__(", .{lid});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) { try self.transpileExprStrict(arg); } else { try self.transpileExpr(arg); }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n                }}\n", .{});
        try self.emit("                break :blk_{d} _obj_{d};\n", .{lid, lid});
        try self.emit("            }}\n", .{});
        try self.emit("        }} else {{\n", .{});
        try self.emit("            const _fn_{d} = _target_{d}.{s};\n", .{lid, lid, m.method});
        if (m.args.items.len > 0) {
            try self.emit("            const _fn_info_{d} = @typeInfo(@TypeOf(_fn_{d})).@\"fn\";\n", .{lid, lid});
        }
        try self.emit("            const _raw_{d} = _fn_{d}(", .{lid, lid});
        for (m.args.items, 0..) |arg, idx| {
            try self.emit("_sundapy_cast_param(_sundapy_param_type(_fn_info_{d}, {d}), ", .{lid, idx});
            if (self.is_strict) { try self.transpileExprStrict(arg); } else { try self.transpileExpr(arg); }
            try self.emit(")", .{});
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        if (self.try_depth > 0) {
            try self.emit("            const _call_res_{d} = if (@typeInfo(@TypeOf(_raw_{d})) == .error_union) (_raw_{d} catch |err_{d}| break :try_blk_{d} err_{d}) else _raw_{d};\n", .{ lid, lid, lid, lid, self.try_depth, lid, lid });
        } else {
            try self.emit("            const _call_res_{d} = if (@typeInfo(@TypeOf(_raw_{d})) == .error_union) try _raw_{d} else _raw_{d};\n", .{ lid, lid, lid, lid });
        }
        try self.emit("            if (comptime @typeInfo(@TypeOf(_call_res_{d})) == .@\"struct\" and @TypeOf(_call_res_{d}) != dynamic.Dynamic) {{\n", .{lid, lid});
        try self.emit("                break :blk_{d} _call_res_{d};\n", .{lid, lid});
        try self.emit("            }} else {{\n", .{});
        if (self.is_strict) { try self.emit("                break :blk_{d} _call_res_{d};\n", .{lid, lid}); } else { try self.emit("                break :blk_{d} Dynamic.fromAny(_call_res_{d});\n", .{lid, lid}); }
        try self.emit("            }}\n", .{});
        try self.emit("        }}\n", .{});
        try self.emit("    }} else if (comptime (_T_info_{d} == .@\"struct\" or _T_info_{d} == .@\"union\" or _T_info_{d} == .@\"enum\" or _T_info_{d} == .@\"opaque\") and @hasDecl(_T_target_{d}, \"builtin_getattr\")) {{\n", .{ lid, lid, lid, lid, lid });
        try self.emit("        var _args_arr = [_]Dynamic{{", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{}); try self.transpileExprStrict(arg); try self.emit(")", .{});
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit("}};\n", .{});
        if (m.kwargs.items.len > 0) {
            try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
            for (m.kwargs.items) |kw| {
                try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
                if (self.is_strict) {
                    try self.emit("Dynamic.fromAny(", .{}); try self.transpileExprStrict(kw.value); try self.emit(")", .{});
                } else {
                    try self.transpileExpr(kw.value);
                }
                try self.emit(") catch {{}};\n", .{});
            }
            try self.emit("        const _fn_{d} = if (@typeInfo(@TypeOf(_target_{d}.builtin_getattr(\"{s}\"))) == .error_union) try _target_{d}.builtin_getattr(\"{s}\") else _target_{d}.builtin_getattr(\"{s}\");\n", .{lid, lid, m.method, lid, m.method, lid, m.method});
            try self.emit("        break :blk_{d} try _fn_{d}.builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, lid});
        } else {
            try self.emit("        const _fn_{d} = if (@typeInfo(@TypeOf(_target_{d}.builtin_getattr(\"{s}\"))) == .error_union) try _target_{d}.builtin_getattr(\"{s}\") else _target_{d}.builtin_getattr(\"{s}\");\n", .{lid, lid, m.method, lid, m.method, lid, m.method});
            try self.emit("        break :blk_{d} try _fn_{d}.builtin_call(alloc, &_args_arr, null);\n", .{lid, lid});
        }
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});
        return;
    }

    if (is_general_method) {
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("((blk_{d}: {{\n", .{lid});
        try self.emit("    var _target_{d} = ", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emit("    const T_target_{d} = @TypeOf(_target_{d});\n", .{ lid, lid });
        try self.emit("    if (T_target_{d} == dynamic.Dynamic) {{\n", .{lid});
        try self.emit("        var _args_arr = [_]Dynamic{{", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{}); try self.transpileExprStrict(arg); try self.emit(")", .{});
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit("}};\n", .{});
        if (m.kwargs.items.len > 0) {
            try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
            for (m.kwargs.items) |kw| {
                try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
                if (self.is_strict) {
                    try self.emit("Dynamic.fromAny(", .{}); try self.transpileExprStrict(kw.value); try self.emit(")", .{});
                } else {
                    try self.transpileExpr(kw.value);
                }
                try self.emit(") catch {{}};\n", .{});
            }
            if (self.try_depth > 0) {
                try self.emit("        const _call_res_{d} = _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict) catch |err_{d}| break :try_blk_{d} err_{d};\n", .{ lid, lid, m.method, self.label_counter, self.try_depth, self.label_counter });
            } else {
                try self.emit("        const _call_res_{d} = try _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{ lid, lid, m.method });
            }
            try self.emit("        break :blk_{d} _call_res_{d};\n", .{ lid, lid });
        } else {
            if (self.try_depth > 0) {
                try self.emit("        const _call_res_{d} = _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null) catch |err_{d}| break :try_blk_{d} err_{d};\n", .{ lid, lid, m.method, self.label_counter, self.try_depth, self.label_counter });
            } else {
                try self.emit("        const _call_res_{d} = try _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null);\n", .{ lid, lid, m.method });
            }
            try self.emit("        break :blk_{d} _call_res_{d};\n", .{ lid, lid });
        }
        try self.emit("    }} else {{\n", .{});
        try self.emit("        const _raw_{d} = _target_{d}.{s}(", .{ lid, lid, m.method });
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        if (self.try_depth > 0) {
            try self.emit("        const _res_{d} = if (@typeInfo(@TypeOf(_raw_{d})) == .error_union) (_raw_{d} catch |err_{d}| break :try_blk_{d} err_{d}) else _raw_{d};\n", .{ lid, lid, lid, self.label_counter, self.try_depth, self.label_counter, lid });
        } else {
            try self.emit("        const _res_{d} = if (@typeInfo(@TypeOf(_raw_{d})) == .error_union) try _raw_{d} else _raw_{d};\n", .{ lid, lid, lid, lid });
        }
        if (m.target.* == .identifier) {
            const escaped = try self.escapeKeyword(m.target.identifier.name);
            defer self.allocator.free(escaped);
            try self.emit("        if (comptime @typeInfo(@TypeOf({s})) != .pointer) {{\n", .{escaped});
            try self.emit("            {s} = _target_{d};\n", .{ escaped, lid });
            try self.emit("        }}\n", .{});
        }
        if (self.is_strict) {
            try self.emit("        break :blk_{d} _res_{d};\n", .{ lid, lid });
        } else {
            try self.emit("        break :blk_{d} Dynamic.fromAny(_res_{d});\n", .{ lid, lid });
        }
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});
        return;
    }

    if (self.try_depth == 0) {
        try self.emit("try ", .{});
    } else if (self.try_depth > 0) {
        try self.emit("(", .{});
    }
    try self.transpileExpr(m.target);
                             
    if (is_string_method) {
        if (std.mem.eql(u8, m.method, "split") and m.args.items.len == 0) {
            try self.emit(".str_split(alloc, null", .{});
        } else if ((std.mem.eql(u8, m.method, "strip") or std.mem.eql(u8, m.method, "lstrip") or std.mem.eql(u8, m.method, "rstrip")) and m.args.items.len == 0) {
            try self.emit(".str_{s}(alloc, null", .{m.method});
        } else {
            try self.emit(".str_{s}(alloc", .{m.method});
        }
    } else if (is_list_method) {
        if (std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "insert") or std.mem.eql(u8, m.method, "extend") or std.mem.eql(u8, m.method, "copy")) {
            try self.emit(".list_{s}(alloc", .{m.method});
        } else if (std.mem.eql(u8, m.method, "pop") and m.args.items.len > 0) {
            try self.emit(".list_pop_at(", .{});
        } else {
            try self.emit(".list_{s}(", .{m.method});
        }
    }
    
    if (m.args.items.len > 0) {
        if (is_string_method or (is_list_method and (std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "insert") or std.mem.eql(u8, m.method, "extend") or std.mem.eql(u8, m.method, "copy")))) {
            try self.emit(", ", .{});
        }
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
    }
    
    try self.emit(")", .{});
    if (self.try_depth > 0) {
        self.label_counter += 1;
        try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
    }
}

