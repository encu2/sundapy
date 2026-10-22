const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const builtin_call = @import("expr_strict_call_builtin.zig");
const class_call = @import("expr_strict_call_class.zig");

pub fn transpileStrictCall(self: *Transpiler, c: anytype) anyerror!void {
    if (c.callee.* == .identifier) {
        if (try @import("expr_idiom_call.zig").tryLowerCallIdiom(self, c)) {
            return;
        }

        const name = c.callee.identifier.name;

        if (try builtin_call.transpileStrictBuiltinCall(self, c, name)) {
            return;
        }

        if (try class_call.transpileStrictClassCall(self, c, name)) {
            return;
        }
    }

    var is_strict_func = false;
    if (c.callee.* == .identifier) {
        if (self.strict_funcs) |sf| {
            if (sf.contains(c.callee.identifier.name)) {
                is_strict_func = true;
            }
        }
    }

    if (c.callee.* == .identifier and is_strict_func and c.kwargs.items.len == 0) {
        if (self.try_depth == 0) {
            try self.emit("try ", .{});
        } else if (self.try_depth > 0) {
            try self.emit("(", .{});
        }
        const escaped = try self.escapeKeyword(c.callee.identifier.name);
        defer self.allocator.free(escaped);
        try self.emit("{s}(", .{escaped});
        for (c.args.items, 0..) |arg, idx| {
            try self.transpileExprStrict(arg);
            if (idx < c.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(")", .{});
        if (self.try_depth > 0) {
            self.label_counter += 1;
            try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{ self.label_counter, self.try_depth, self.label_counter });
        }
        return;
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    if (self.try_depth == 0) {
        try self.emit("try ", .{});
    } else if (self.try_depth > 0) {
        try self.emit("(", .{});
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _callee = ", .{});
    if (c.callee.* == .identifier) {
        const callee_name = c.callee.identifier.name;
        try self.emit("(if (comptime @hasDecl(@This(), \"_sundapy_is_abi_{s}\") and @field(@This(), \"_sundapy_is_abi_{s}\")) @field(@This(), \"{s}_dyn\") else ", .{ callee_name, callee_name, callee_name });
        try self.transpileExprStrict(c.callee);
        try self.emit(")", .{});
    } else if (c.callee.* == .getattr and c.callee.getattr.target.* == .identifier) {
        const root = c.callee.getattr.target.identifier.name;
        var is_mod = self.module_aliases.get(root) != null;
        if (!is_mod) {
            for (self.imported_modules.items) |mod| {
                if (std.mem.eql(u8, root, mod)) { is_mod = true; break; }
            }
        }
        if (is_mod) {
            const root_esc = try self.escapeKeyword(root);
            defer self.allocator.free(root_esc);
            try self.emit("{s}.{s}", .{ root_esc, c.callee.getattr.attr });
        } else {
            try self.transpileExpr(c.callee);
        }
    } else {
        try self.transpileExpr(c.callee);
    }
    try self.emit(";\n", .{});
    try self.emit("    const T_callee = @TypeOf(_callee);\n", .{});
    try self.emit("    if (T_callee == dynamic.Dynamic) {{\n", .{});
    try self.emit("        var _args_arr = [_]Dynamic{{", .{});
    for (c.args.items, 0..) |arg, idx| {
        if (self.is_strict) {
            try self.emit("Dynamic.fromAny(", .{});
            try self.transpileExprStrict(arg);
            try self.emit(")", .{});
        } else {
            try self.transpileExpr(arg);
        }
        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit("}};\n", .{});

    if (c.kwargs.items.len > 0) {
        try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
        for (c.kwargs.items) |kw| {
            try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(kw.value);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(kw.value);
            }
            try self.emit(") catch {{}};\n", .{});
        }
        try self.emit("        break :blk_{d} _callee.builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid});
    } else {
        try self.emit("        break :blk_{d} _callee.builtin_call(alloc, &_args_arr, null);\n", .{lid});
    }

    try self.emit("    }} else if (T_callee == type and comptime (@typeInfo(_callee) == .@\"struct\" or @typeInfo(_callee) == .@\"union\" or @typeInfo(_callee) == .@\"enum\" or @typeInfo(_callee) == .@\"opaque\")) {{\n", .{});
    try self.emit("        if (comptime @hasDecl(_callee, \"init\")) {{\n", .{});
    try self.emit("            const _ifn_{d} = _callee.init;\n", .{lid});
    if (c.args.items.len > 0) {
        try self.emit("            const _iinfo_{d} = @typeInfo(@TypeOf(_ifn_{d})).@\"fn\";\n", .{ lid, lid });
    }
    try self.emit("            const _ir_{d} = _ifn_{d}(", .{lid, lid});
    for (c.args.items, 0..) |arg, idx| {
        try self.emit("_sundapy_cast_param(_sundapy_param_type(_iinfo_{d}, {d}), ", .{ lid, idx });
        if (is_strict_func or self.is_strict) {
            try self.transpileExprStrict(arg);
        } else {
            try self.transpileExpr(arg);
        }
        try self.emit(")", .{});
        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit(");\n", .{});
    if (is_strict_func or self.is_strict) {
        try self.emit("            break :blk_{d} @as(anyerror!@TypeOf(_ir_{d}), _ir_{d});\n", .{ lid, lid, lid });
    } else {
        try self.emit("            break :blk_{d} @as(anyerror!Dynamic, Dynamic.fromAny(_ir_{d}));\n", .{ lid, lid });
    }
    try self.emit("        }} else {{\n", .{});
    try self.emit("            var _obj_{d} = _callee{{}};\n", .{lid});
    try self.emit("            if (@hasDecl(_callee, \"__init__\")) {{\n", .{});
    try self.emit("                _ = try _obj_{d}.__init__(", .{lid});
    for (c.args.items, 0..) |arg, idx| {
        if (is_strict_func or self.is_strict) {
            try self.transpileExprStrict(arg);
        } else {
            try self.transpileExpr(arg);
        }
        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit(");\n            }}\n", .{});
    if (is_strict_func or self.is_strict) {
        try self.emit("            break :blk_{d} @as(anyerror!@TypeOf(_obj_{d}), _obj_{d});\n", .{ lid, lid, lid });
    } else {
        try self.emit("            break :blk_{d} @as(anyerror!Dynamic, Dynamic.fromAny(_obj_{d}));\n", .{ lid, lid });
    }
    try self.emit("        }}\n", .{});
    if (c.kwargs.items.len > 0) {
        try self.emit("    }} else if (comptime (@typeInfo(T_callee) == .@\"fn\" or (@typeInfo(T_callee) == .pointer and @typeInfo(@typeInfo(T_callee).pointer.child) == .@\"fn\"))) {{\n", .{});
        try self.emit("        var _args_arr = [_]Dynamic{{", .{});
        for (c.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(arg);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < c.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit("}};\n", .{});
        try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
        for (c.kwargs.items) |kw| {
            try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(kw.value);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(kw.value);
            }
            try self.emit(") catch {{}};\n", .{});
        }
        try self.emit("        break :blk_{d} dynamic.toDynamicFunc(_callee).builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid});
        try self.emit("    }}\n", .{});
    } else {
        try self.emit("    }} else {{\n", .{});
        if (c.args.items.len > 0) {
            try self.emit("        const _callee_info_{d} = if (@typeInfo(T_callee) == .@\"fn\") @typeInfo(T_callee).@\"fn\" else @typeInfo(@typeInfo(T_callee).pointer.child).@\"fn\";\n", .{lid});
        }
        try self.emit("        const _raw_call_{d} = _callee(", .{lid});
        for (c.args.items, 0..) |arg, idx| {
            try self.emit("_sundapy_cast_param(_sundapy_param_type(_callee_info_{d}, {d}), ", .{ lid, idx });
            if (is_strict_func or self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            try self.emit(")", .{});
            if (idx < c.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        try self.emit("        const _res_call_{d} = if (@typeInfo(@TypeOf(_raw_call_{d})) == .error_union) try _raw_call_{d} else _raw_call_{d};\n", .{ lid, lid, lid, lid });
        if (is_strict_func or self.is_strict) {
            try self.emit("        break :blk_{d} @as(anyerror!@TypeOf(_res_call_{d}), _res_call_{d});\n", .{ lid, lid, lid });
        } else {
            try self.emit("        break :blk_{d} @as(anyerror!Dynamic, Dynamic.fromAny(_res_call_{d}));\n", .{ lid, lid });
        }
        try self.emit("    }}\n", .{});
    }
    try self.emit("}})", .{});

    if (self.try_depth > 0) {
        self.label_counter += 1;
        try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{ self.label_counter, self.try_depth, self.label_counter });
    }
}
