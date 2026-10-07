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
        try self.transpileExprStrict(c.callee);
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

    try self.emit("    }} else if (T_callee == type) {{\n", .{});
    try self.emit("        var _obj = _callee{{}};\n", .{});
    try self.emit("        if (@hasDecl(_callee, \"__init__\")) {{\n", .{});
    try self.emit("            _ = try _obj.__init__(", .{});
    for (c.args.items, 0..) |arg, idx| {
        if (is_strict_func or self.is_strict) {
            try self.transpileExprStrict(arg);
        } else {
            try self.transpileExpr(arg);
        }
        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit(");\n        }}\n", .{});
    try self.emit("        break :blk_{d} _obj;\n", .{lid});
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
    } else {
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} _callee(", .{lid});
        for (c.args.items, 0..) |arg, idx| {
            if (is_strict_func or self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < c.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        try self.emit("    }}\n", .{});
    }
    try self.emit("}})", .{});

    if (self.try_depth > 0) {
        self.label_counter += 1;
        try self.emit(" catch |err_{d}| break :try_blk_{d} err_{d})", .{ self.label_counter, self.try_depth, self.label_counter });
    }
}
