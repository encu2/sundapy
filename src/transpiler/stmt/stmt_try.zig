const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileTryStmt(self: *Transpiler, t: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
    try self.emit("{{\n", .{});
    self.indent_level += 1;
    
    if (t.finally_branch) |fb| {
        try self.emitIndent();
        try self.emit("defer {{\n", .{});
        self.indent_level += 1;
        for (fb.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
    }
    
    self.try_depth += 1;
    const current_depth = self.try_depth;
    
    try self.emitIndent();
    try self.emit("const _result_try_{d}: anyerror!void = try_blk_{d}: {{\n", .{current_depth, current_depth});
    self.indent_level += 1;
    
    try self.emitIndent();
    try self.emit("var _force_err_{d} = false; _ = &_force_err_{d};\n", .{current_depth, current_depth});
    try self.emitIndent();
    try self.emit("if (_force_err_{d}) break :try_blk_{d} error.Exception;\n", .{current_depth, current_depth});
    
    for (t.body.items) |stmt| {
        try self.transpileStmt(stmt, declared_vars, strict_funcs);
    }
    if (t.body.items.len > 0) {
        if (t.body.items[t.body.items.len - 1].* != .return_stmt) {
            try self.emitIndent();
            try self.emit("break :try_blk_{d} {{}};\n", .{current_depth});
        }
    } else {
        try self.emitIndent();
        try self.emit("break :try_blk_{d} {{}};\n", .{current_depth});
    }

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}};\n", .{});
    
    self.try_depth -= 1;

    try self.emitIndent();
    try self.emit("if (_result_try_{d}) |_| {{\n", .{current_depth});
    self.indent_level += 1;
    if (t.else_branch) |elb| {
        for (elb.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
    }
    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}} else |_err_{d}| {{\n", .{current_depth});
    self.indent_level += 1;
    try self.emitIndent();
    try self.emit("_ = @errorName(_err_{d});\n", .{current_depth});

    if (t.except_clauses.items.len > 0) {
        var has_bare = false;
        for (t.except_clauses.items, 0..) |c, c_idx| {
            try self.emitIndent();
            if (c.except_type) |raw_et| {
                const et = std.mem.trim(u8, raw_et, " \t\r\n");
                if (c_idx > 0) try self.emit("else ", .{});
                if (et.len == 0 or std.mem.eql(u8, et, "Exception") or std.mem.eql(u8, et, "BaseException")) {
                    has_bare = true;
                    try self.emit("if (true) {{\n", .{});
                } else {
                    try self.emit("if (", .{});
                    var it_t = std.mem.splitScalar(u8, et, ',');
                    var first_t = true;
                    while (it_t.next()) |raw_t| {
                        const t_name = std.mem.trim(u8, raw_t, " ()\t\r\n");
                        if (t_name.len == 0) continue;
                        if (!first_t) try self.emit(" or ", .{});
                        first_t = false;
                        if (std.mem.eql(u8, t_name, "Exception") or std.mem.eql(u8, t_name, "BaseException")) {
                            has_bare = true;
                            try self.emit("true", .{});
                        } else {
                            try self.emit("std.mem.eql(u8, @errorName(_err_{d}), \"{s}\")", .{ current_depth, t_name });
                        }
                    }
                    if (first_t) try self.emit("true", .{});
                    try self.emit(") {{\n", .{});
                }
            } else {
                has_bare = true;
                if (c_idx > 0) {
                    try self.emit("else {{\n", .{});
                } else {
                    try self.emit("if (true) {{\n", .{});
                }
            }
            self.indent_level += 1;
            if (c.except_as) |as_name| {
                try self.emitIndent();
                const is_outer = declared_vars.contains(as_name);
                if (is_outer) {
                    if (self.is_strict) {
                        try self.emit("{s} = @errorName(_err_{d});\n", .{ as_name, current_depth });
                    } else {
                        try self.emit("{s} = Dynamic.initStr(@errorName(_err_{d}));\n", .{ as_name, current_depth });
                    }
                } else {
                    if (self.is_strict) {
                        try self.emit("var {s}: []const u8 = @errorName(_err_{d}); _ = &{s};\n", .{ as_name, current_depth, as_name });
                    } else {
                        try self.emit("var {s} = Dynamic.initStr(@errorName(_err_{d})); _ = &{s};\n", .{ as_name, current_depth, as_name });
                    }
                }
            }
            for (c.body.items) |stmt| {
                try self.transpileStmt(stmt, declared_vars, strict_funcs);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}\n", .{});
            if (has_bare) break;
        }
        if (!has_bare and t.except_clauses.items.len > 0) {
            try self.emitIndent();
            if (self.try_depth > 0) {
                try self.emit("else break :try_blk_{d} _err_{d};\n", .{ self.try_depth, current_depth });
            } else {
                try self.emit("else return _err_{d};\n", .{current_depth});
            }
        }
    } else {
        if (t.except_as) |as_name| {
            try self.emitIndent();
            const is_outer = declared_vars.contains(as_name);
            if (is_outer) {
                if (self.is_strict) {
                    try self.emit("{s} = @errorName(_err_{d});\n", .{ as_name, current_depth });
                } else {
                    try self.emit("{s} = Dynamic.initStr(@errorName(_err_{d}));\n", .{ as_name, current_depth });
                }
            } else {
                if (self.is_strict) {
                    try self.emit("var {s}: []const u8 = @errorName(_err_{d}); _ = &{s};\n", .{ as_name, current_depth, as_name });
                } else {
                    try self.emit("var {s} = Dynamic.initStr(@errorName(_err_{d})); _ = &{s};\n", .{ as_name, current_depth, as_name });
                }
                try declared_vars.put(as_name, true);
            }
        }

        if (t.except_branch) |eb| {
            for (eb.items) |stmt| {
                try self.transpileStmt(stmt, declared_vars, strict_funcs);
            }
        }
    }
    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});
    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});
}
