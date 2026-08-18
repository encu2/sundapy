const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileStrictMethodCall(self: *Transpiler, m: anytype) anyerror!void {
    const is_class = (m.method.len > 0 and m.method[0] >= 'A' and m.method[0] <= 'Z');
    if (is_class) {
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("(blk_{d}: {{\n", .{lid});
        try self.emitIndent();
        try self.emit("    var obj = ", .{});
        try self.transpileExpr(m.target);
        try self.emit(".{s}{{}};\n", .{m.method});
        try self.emitIndent();
        try self.emit("    _ = try obj.__init__(", .{});
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
        try self.emit("    break :blk_{d} obj;\n", .{lid});
        try self.emit("}})", .{});
        return;
    }
    const is_string_method = std.mem.eql(u8, m.method, "split") or 
                             std.mem.eql(u8, m.method, "replace") or 
                             std.mem.eql(u8, m.method, "join") or 
                             std.mem.eql(u8, m.method, "upper") or 
                             std.mem.eql(u8, m.method, "lower");
                             
    const is_list_method = std.mem.eql(u8, m.method, "append") or 
                           std.mem.eql(u8, m.method, "pop") or 
                           std.mem.eql(u8, m.method, "sort") or
                           std.mem.eql(u8, m.method, "insert") or
                           std.mem.eql(u8, m.method, "remove") or
                           std.mem.eql(u8, m.method, "reverse") or
                           std.mem.eql(u8, m.method, "count") or
                           std.mem.eql(u8, m.method, "index");
                           
    var is_general_method = true;
    if (is_string_method or is_list_method) {
        is_general_method = false;
    }
    
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
        if (self.try_depth == 0) {
            try self.emit("try ", .{});
        } else if (self.try_depth > 0) {
            try self.emit("(", .{});
        }
        
        self.label_counter += 1;
        const lid = self.label_counter;
        try self.emit("((blk_{d}: {{\n", .{lid});
        try self.emit("    const _target = ", .{});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emit("    if (@hasDecl(_target, \"{s}\")) {{\n", .{m.method});
        try self.emit("        break :blk_{d} _target.{s}(", .{lid, m.method});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        try self.emit("    }} else {{\n", .{});
        try self.emit("        var _args_arr = [_]Dynamic{{", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
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
                    try self.transpileExprStrict(kw.value);
                } else {
                    try self.transpileExpr(kw.value);
                }
                try self.emit(") catch {{}};\n", .{});
            }
            try self.emit("        break :blk_{d} _target.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, m.method});
        } else {
            try self.emit("        break :blk_{d} _target.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null);\n", .{lid, m.method});
        }
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});
        
        if (self.try_depth > 0) {
            self.label_counter += 1;
            try self.emit(" catch |err_{d}| break :blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
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
        try self.emit("    var _target = ", .{});
        try self.transpileExpr(m.target);
        try self.emit(";\n", .{});
        try self.emit("    const T_target = @TypeOf(_target);\n", .{});
        try self.emit("    if (T_target == @import(\"dynamic\").Dynamic) {{\n", .{});
        try self.emit("        var _args_arr = [_]Dynamic{{", .{});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
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
                    try self.transpileExprStrict(kw.value);
                } else {
                    try self.transpileExpr(kw.value);
                }
                try self.emit(") catch {{}};\n", .{});
            }
            try self.emit("        break :blk_{d} _target.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, m.method});
        } else {
            try self.emit("        break :blk_{d} _target.builtin_getattr(\"{s}\").builtin_call(alloc, &_args_arr, null);\n", .{lid, m.method});
        }
        try self.emit("    }} else {{\n", .{});
        try self.emit("        break :blk_{d} _target.{s}(", .{lid, m.method});
        for (m.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.transpileExprStrict(arg);
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < m.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit(");\n", .{});
        try self.emit("    }}\n", .{});
        try self.emit("}}))", .{});
        
        if (self.try_depth > 0) {
            self.label_counter += 1;
            try self.emit(" catch |err_{d}| break :blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
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
        try self.emit(".str_{s}(alloc", .{m.method});
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
        try self.emit(" catch |err_{d}| break :blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
    }
}
