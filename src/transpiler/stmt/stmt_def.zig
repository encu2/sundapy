const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
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
        try self.emit("_ = _args;\n", .{});
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
            try self.emit("return Dynamic{{ .value = .none_type }};\n", .{});
        } else {
            try self.emitIndent();
            try self.emit("return;\n", .{});
        }
    }
    
    self.indent_level -= 1;
    try self.emit("}}\n\n", .{});
    self.is_strict = orig_strict;
}
