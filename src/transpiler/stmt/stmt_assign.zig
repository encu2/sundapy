const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const mapType = @import("../transpiler.zig").Transpiler.mapType;

pub fn transpileAssign(self: *Transpiler, a: anytype, declared_vars: *std.StringHashMap(bool)) !void {
    const already_declared = declared_vars.contains(a.target);
    if (!already_declared) {
        try declared_vars.put(a.target, true);
        if (self.is_strict) {
            if (a.type_ann) |t| {
                try self.emit("var {s}: {s} = ", .{ a.target, mapType(t) });
                try self.transpileExprStrict(a.value);
            } else {
                std.debug.print("Strict Mode Error: Variable '{s}' requires explicit static type annotation upon initialization.\n", .{a.target});
                return error.MissingTypeAnnotation;
            }
        } else {
            if (a.type_ann) |t| {
                try self.emit("var {s}: {s} = ", .{ a.target, mapType(t) });
                try self.transpileExprStrict(a.value);
            } else {
                // Use escape analysis to avoid Dynamic if possible!
                if (self.escape_analyzer.variables.get(a.target)) |v_info| {
                    if (v_info.class == .stack and v_info.is_primitive) {
                        // We can use Zig's type inference!
                        const t = self.escape_analyzer.primitiveTypeString(a.value);
                        try self.emit("var {s}: {s} = ", .{ a.target, t });
                        try self.transpileExprStrict(a.value);
                        try self.emit(";\n", .{});
                        if (!already_declared) {
                            try self.emitIndent();
                            try self.emit("_ = &{s};\n", .{a.target});
                        }
                        return;
                    }
                }
                
                try self.emit("var {s} = ", .{ a.target });
                try self.transpileExpr(a.value);
            }
        }
    } else {
        try self.emit("{s} = ", .{ a.target });
        if (a.type_ann != null or self.is_strict) {
            try self.transpileExprStrict(a.value);
        } else {
            var is_stack_primitive = false;
            if (self.escape_analyzer.variables.get(a.target)) |v_info| {
                if (v_info.class == .stack and v_info.is_primitive) {
                    is_stack_primitive = true;
                }
            }
            if (is_stack_primitive) {
                try self.transpileExprStrict(a.value);
            } else {
                try self.transpileExpr(a.value);
            }
        }
    }
    
    try self.emit(";\n", .{});
    
    if (!already_declared) {
        try self.emitIndent();
        try self.emit("_ = &{s};\n", .{a.target});
    }
}

pub fn transpileConstAssign(self: *Transpiler, a: anytype, declared_vars: *std.StringHashMap(bool)) !void {
    try declared_vars.put(a.target, true);
    if (a.type_ann) |t| {
        try self.emit("const {s}: {s} = ", .{ a.target, mapType(t) });
        try self.transpileExprStrict(a.value);
    } else {
        if (self.is_strict) {
            std.debug.print("Strict Mode Error: Constant '{s}' requires explicit static type annotation.\n", .{a.target});
            return error.MissingTypeAnnotation;
        } else {
            try self.emit("const {s} = ", .{ a.target });
            try self.transpileExpr(a.value);
        }
    }
    try self.emit(";\n", .{});
    
    try self.emitIndent();
    try self.emit("_ = &{s};\n", .{a.target});
}

pub fn transpileSubscriptAssign(self: *Transpiler, s: anytype) !void {
    if (self.try_depth == 0) {
        try self.emit("try ", .{});
    }
    try self.transpileExpr(s.target);
    try self.emit(".setDynamicItem(", .{});
    try self.transpileExpr(s.index);
    try self.emit(", ", .{});
    try self.transpileExpr(s.value);
    try self.emit(");\n", .{});
}
