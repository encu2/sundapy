const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

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
        try self.emit("    if (comptime T_target_{d} == dynamic.Dynamic) {{\n", .{lid});
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
        try self.emit("    }} else if (comptime T_target_{d} == type and @hasDecl(_target_{d}, \"builtin_getattr\")) {{\n", .{lid, lid});
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
    const is_string_method = std.mem.eql(u8, m.method, "split") or std.mem.eql(u8, m.method, "replace") or (std.mem.eql(u8, m.method, "join") and m.args.items.len > 0) or std.mem.eql(u8, m.method, "upper") or std.mem.eql(u8, m.method, "lower");
    const is_list_method = std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "pop") or std.mem.eql(u8, m.method, "sort") or std.mem.eql(u8, m.method, "insert") or std.mem.eql(u8, m.method, "remove") or std.mem.eql(u8, m.method, "reverse") or std.mem.eql(u8, m.method, "count") or std.mem.eql(u8, m.method, "index");
    const is_general_method = !(is_string_method or is_list_method);
    
    var target_is_module = false;
    if (m.target.* == .identifier) {
        for (self.imported_modules.items) |mod| {
            if (std.mem.eql(u8, m.target.identifier.name, mod)) {
                target_is_module = true;
                break;
            }
        }
        if (!target_is_module) {
            if (self.module_aliases.get(m.target.identifier.name) != null) {
                target_is_module = true;
            }
        }
    }
    
    if (target_is_module) {
        var is_c_import = false;
        if (m.target.* == .identifier) {
            if (self.c_imported_modules.contains(m.target.identifier.name)) {
                is_c_import = true;
            } else if (self.module_aliases.get(m.target.identifier.name)) |orig| {
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
            try self.transpileExpr(m.target);
            try self.emit(".{s};\n", .{m.method});
            try self.emit("    const _c_fn_info = @typeInfo(@TypeOf(_c_fn)).@\"fn\";\n", .{});
            try self.emit("    const _c_ret = _c_fn(", .{});
            for (m.args.items, 0..) |arg, idx| {
                try self.emit("_sundapy_to_c_arg(_c_fn_info.params[{d}].type.?, ", .{idx});
                if (self.is_strict) {
                    try self.transpileExprStrict(arg);
                } else {
                    try self.transpileExpr(arg);
                }
                try self.emit(")", .{});
                if (idx < m.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(");\n", .{});
            try self.emit("    break :blk_{d} Dynamic.fromAny(_c_ret);\n", .{lid});
            try self.emit("}}))", .{});
            return;
        }

        if (self.is_strict and m.kwargs.items.len == 0) {
            if (self.try_depth == 0) {
                try self.emit("try ", .{});
            } else if (self.try_depth > 0) {
                try self.emit("(", .{});
            }
            try self.transpileExprStrict(m.target);
            try self.emit(".{s}(", .{m.method});
            for (m.args.items, 0..) |arg, idx| {
                try self.transpileExprStrict(arg);
                if (idx < m.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(")", .{});
            if (self.try_depth > 0) {
                self.label_counter += 1;
                try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{ self.label_counter, self.try_depth, self.label_counter });
            }
            return;
        }

        if (self.try_depth == 0) {
            try self.emit("try ", .{});
        } else if (self.try_depth > 0) {
            try self.emit("(", .{});
        }
        
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("((blk_{d}: {{\n", .{lid});
        try self.emit("    const _target_{d} = ", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emit("    if (@hasDecl(_target_{d}, \"{s}\")) {{\n", .{lid, m.method});
        try self.emit("        if (@TypeOf(_target_{d}.{s}) == type) {{\n", .{lid, m.method});
        try self.emit("            var _obj_{d} = _target_{d}.{s}{{}};\n", .{lid, lid, m.method});
        try self.emit("            if (@hasDecl(_target_{d}.{s}, \"__init__\")) {{\n", .{lid, m.method});
        try self.emit("                _ = try _obj_{d}.__init__(", .{lid});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n            }}\n", .{});
        try self.emit("            break :blk_{d} _obj_{d};\n", .{lid, lid});
        try self.emit("        }} else {{\n", .{});
        try self.emit("            break :blk_{d} _target_{d}.{s}(", .{lid, lid, m.method});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n        }}\n", .{});
        try self.emit("    }} else if (@hasDecl(_target_{d}, \"builtin_getattr\")) {{\n", .{lid});
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
            try self.emit("        break :blk_{d} _fn_{d}.builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, lid});
        } else {
            try self.emit("        const _fn_{d} = if (@typeInfo(@TypeOf(_target_{d}.builtin_getattr(\"{s}\"))) == .error_union) try _target_{d}.builtin_getattr(\"{s}\") else _target_{d}.builtin_getattr(\"{s}\");\n", .{lid, lid, m.method, lid, m.method, lid, m.method});
            try self.emit("        break :blk_{d} _fn_{d}.builtin_call(alloc, &_args_arr, null);\n", .{lid, lid});
        }
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});

        
        if (self.try_depth > 0) {
            self.label_counter += 1;
            try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
        }

        return;
    }

    if (is_general_method) {
        if (self.try_depth == 0) {
            try self.emit("try ", .{});
        } else if (self.try_depth > 0) {
            try self.emit("(", .{});
        }
        
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("((blk_{d}: {{\n", .{lid});
        try self.emit("    var _target_{d} = ", .{lid});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emit("    const T_target_{d} = @TypeOf(_target_{d});\n", .{lid, lid});
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
            try self.emit("        break :blk_{d} _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, lid, m.method});
        } else {
            try self.emit("        break :blk_{d} _target_{d}.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null);\n", .{lid, lid, m.method});
        }
        try self.emit("    }} else {{\n", .{});
        if (m.target.* == .identifier) {
            const escaped = try self.escapeKeyword(m.target.identifier.name);
            defer self.allocator.free(escaped);
            try self.emit("        const _res_{d} = _target_{d}.{s}(", .{lid, lid, m.method});
            for (m.args.items, 0..) |arg, idx| {
                if (self.is_strict) {
                    try self.transpileExprStrict(arg);
                } else {
                    try self.transpileExpr(arg);
                }
                if (idx < m.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(");\n", .{});
            try self.emit("        if (comptime @typeInfo(@TypeOf({s})) != .pointer) {{\n", .{escaped});
            try self.emit("            {s} = _target_{d};\n", .{escaped, lid});
            try self.emit("        }}\n", .{});
            try self.emit("        break :blk_{d} _res_{d};\n", .{lid, lid});
        } else {
            try self.emit("        break :blk_{d} _target_{d}.{s}(", .{lid, lid, m.method});
            for (m.args.items, 0..) |arg, idx| {
                if (self.is_strict) {
                    try self.transpileExprStrict(arg);
                } else {
                    try self.transpileExpr(arg);
                }
                if (idx < m.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(");\n", .{});
        }
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});
        
        if (self.try_depth > 0) {
            self.label_counter += 1;
            try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
        }
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
        } else {
            try self.emit(".str_{s}(alloc", .{m.method});
        }
    } else if (is_list_method) {
        if (std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "insert")) {
            try self.emit(".list_{s}(alloc", .{m.method});
        } else {
            try self.emit(".list_{s}(", .{m.method});
        }
    }
    
    if (m.args.items.len > 0) {
        if (is_string_method or (is_list_method and (std.mem.eql(u8, m.method, "append") or std.mem.eql(u8, m.method, "insert")))) {
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

