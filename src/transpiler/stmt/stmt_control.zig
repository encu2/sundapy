const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileIfStmt(self: *Transpiler, ifs: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
        try self.emit("if (", .{});
        if (self.is_strict) {
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
            if (self.is_strict) {
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
        try self.emit("const _result_try_{d}: anyerror!void = blk_{d}: {{\n", .{current_depth, current_depth});
        self.indent_level += 1;
        
        try self.emitIndent();
        try self.emit("var _force_err_{d} = false; _ = &_force_err_{d};\n", .{current_depth, current_depth});
        try self.emitIndent();
        try self.emit("if (_force_err_{d}) break :blk_{d} error.Exception;\n", .{current_depth, current_depth});
        
        for (t.body.items) |stmt| {
            try self.transpileStmt(stmt, declared_vars, strict_funcs);
        }
        if (t.body.items.len > 0) {
            if (t.body.items[t.body.items.len - 1].* != .return_stmt) {
                try self.emitIndent();
                try self.emit("break :blk_{d} {{}};\n", .{current_depth});
            }
        } else {
            try self.emitIndent();
            try self.emit("break :blk_{d} {{}};\n", .{current_depth});
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}};\n", .{});
        
        try self.emitIndent();
        try self.emit("_result_try_{d} catch {{\n", .{current_depth});
        self.indent_level += 1;

        
        self.try_depth -= 1;
        
        if (t.except_branch) |eb| {
            for (eb.items) |stmt| {
                try self.transpileStmt(stmt, declared_vars, strict_funcs);
            }
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}};\n", .{});
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("}}\n", .{});
    }

pub fn transpileWhileStmt(self: *Transpiler, w: anytype, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
        try self.emit("while (", .{});
        if (self.is_strict) {
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
        try self.emit("{{\n", .{});
        self.indent_level += 1;
        
        try self.emitIndent();
        try self.emit("var iter_obj_{d} = ", .{self.indent_level});
        try self.transpileExpr(f.iterable);
        try self.emit(";\n", .{});
        
        try self.emitIndent();
        try self.emit("var iter_idx_{d}: usize = 0;\n", .{self.indent_level});
        
        try self.emitIndent();
        try self.emit("while (iter_idx_{d} < iter_obj_{d}.len()) : (iter_idx_{d} += 1) {{\n", .{self.indent_level, self.indent_level, self.indent_level});
        self.indent_level += 1;
        
        try self.emitIndent();
        const already_declared = declared_vars.contains(f.iterator);
        if (!already_declared) {
            try declared_vars.put(f.iterator, true);
            if (self.is_strict) {
                try self.emit("var {s}: i64 = iter_obj_{d}.getItem(iter_idx_{d}).value.i64_type;\n", .{f.iterator, self.indent_level - 1, self.indent_level - 1});
            } else {
                try self.emit("var {s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{f.iterator, self.indent_level - 1, self.indent_level - 1});
            }
            try self.emitIndent();
            try self.emit("_ = &{s};\n", .{f.iterator});
        } else {
            if (self.is_strict) {
                try self.emit("{s} = iter_obj_{d}.getItem(iter_idx_{d}).value.i64_type;\n", .{f.iterator, self.indent_level - 1, self.indent_level - 1});
            } else {
                try self.emit("{s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{f.iterator, self.indent_level - 1, self.indent_level - 1});
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


pub fn transpileWithStmt(self: *Transpiler, w: anytype) anyerror!void {
    // Basic dynamic transpile for with_stmt
    const ctx_var = try std.fmt.allocPrint(self.allocator, "__with_ctx_{d}", .{self.temp_counter});
    self.temp_counter += 1;
    try self.emit("var {s} = ", .{ctx_var});
    try self.transpileExpr(w.context_expr);
    try self.emit(";\n", .{});
    
    // Call __enter__
    const enter_res = try std.fmt.allocPrint(self.allocator, "__with_res_{d}", .{self.temp_counter});
    self.temp_counter += 1;
    if (w.is_async) {
        try self.emit("var {s} = try (try {s}.builtin_getattr(\"__aenter__\")).builtin_call(dynamic.None);\n", .{enter_res, ctx_var});
    } else {
        try self.emit("var {s} = try (try {s}.builtin_getattr(\"__enter__\")).builtin_call(dynamic.None);\n", .{enter_res, ctx_var});
    }
    
    if (w.as_name) |name| {
        try self.emit("var {s} = {s};\n", .{name, enter_res});
    }
    
    // Body
    for (w.body.items) |stmt| {
        try self.transpileStmt(stmt);
    }
    
    // Call __exit__
    if (w.is_async) {
        try self.emit("_ = try (try {s}.builtin_getattr(\"__aexit__\")).builtin_call(dynamic.None);\n", .{ctx_var});
    } else {
        try self.emit("_ = try (try {s}.builtin_getattr(\"__exit__\")).builtin_call(dynamic.None);\n", .{ctx_var});
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
