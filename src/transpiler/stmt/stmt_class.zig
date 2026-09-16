const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;
const mapType = @import("../transpiler.zig").Transpiler.mapType;
const isRecursive = @import("../analysis/analysis.zig").isRecursive;

pub fn transpileClassStmt(self: *Transpiler, c: anytype, strict_funcs: *std.StringHashMap(bool)) !void {
    try self.emit("pub const {s} = struct {{\n", .{c.name});
    self.indent_level += 1;
    
    var fields = std.StringHashMap(bool).init(self.allocator);
    defer fields.deinit();
    
    var all_methods: std.ArrayList(*ast.Node) = .empty;
    defer all_methods.deinit(self.allocator);
    
    if (c.base_class) |bc| {
        if (self.class_asts.get(bc)) |parent_node| {
            for (parent_node.class_stmt.methods.items) |pm| {
                var overridden = false;
                for (c.methods.items) |cm| {
                    if (pm.* == .def_stmt and cm.* == .def_stmt) {
                        if (std.mem.eql(u8, pm.def_stmt.name, cm.def_stmt.name)) {
                            overridden = true;
                        }
                    }
                }
                if (!overridden) {
                    try all_methods.append(self.allocator, pm);
                }
            }
        }
    }
    for (c.methods.items) |cm| {
        try all_methods.append(self.allocator, cm);
    }
    
    for (all_methods.items) |method_node| {
        try @import("../analysis/analysis.zig").collectClassFields(self.allocator, method_node, &fields);
    }
    
    var it_fields = fields.iterator();
    while (it_fields.next()) |entry| {
        try self.emitIndent();
        try self.emit("{s}: Dynamic = undefined,\n", .{entry.key_ptr.*});
    }
    
    var has_init = false;
    for (all_methods.items) |method_node| {
        if (method_node.* == .def_stmt) {
            const d = method_node.def_stmt;
            if (std.mem.eql(u8, d.name, "__init__")) has_init = true;
            
            const orig_strict = self.is_strict;
            if (d.is_strict) self.is_strict = true;
            
            var is_rec = false;
            for (d.body.items) |body_node| {
                if (isRecursive(body_node, d.name)) is_rec = true;
            }
            const can_inline = !is_rec and d.body.items.len <= 2;

            try self.emitIndent();
            if (can_inline) {
                try self.emit("pub inline fn {s}(", .{d.name});
            } else {
                try self.emit("pub fn {s}(", .{d.name});
            }
            
            for (d.params.items, 0..) |p, idx| {
                var p_type: []const u8 = undefined;
                if (std.mem.eql(u8, p.name, "self")) {
                    p_type = try std.fmt.allocPrint(self.allocator, "*{s}", .{c.name});
                } else {
                    p_type = if (p.type_ann) |t| mapType(t) else if (!self.is_strict) "Dynamic" else {
                        std.debug.print("Strict Mode Error: Parameter '{s}' requires explicit static type annotation.\n", .{p.name});
                        return error.MissingTypeAnnotation;
                    };
                }
                try self.emit("{s}: {s}", .{p.name, p_type});
                if (idx < d.params.items.len - 1) try self.emit(", ", .{});
            }
            
            try self.emit(") anyerror!", .{});
            
            if (d.return_type) |rt| {
                try self.emit("{s} {{\n", .{mapType(rt)});
            } else if (!self.is_strict) {
                try self.emit("Dynamic {{\n", .{});
            } else {
                std.debug.print("Strict Mode Error: Method '{s}' requires explicit return type annotation (use -> void if none).\n", .{d.name});
                return error.MissingTypeAnnotation;
            }
            self.indent_level += 1;
            
            var declared_vars = std.StringHashMap(bool).init(self.allocator);
            defer declared_vars.deinit();
            
            for (d.params.items) |p| {
                try declared_vars.put(p.name, true);
                try self.emitIndent();
                if (std.mem.eql(u8, p.name, "self")) {
                    try self.emit("_ = if (true) self else {{}};\n", .{});
                } else {
                    try self.emit("_ = if (true) {s} else {{}};\n", .{p.name});
                }
            }
            
            if (!self.is_strict) {
                try self.emitIndent();
                try self.emit("var _yield_list = dynamic.Dynamic.initList(std.ArrayList(Dynamic).empty);\n", .{});
                try self.emitIndent();
                try self.emit("_ = &_yield_list;\n", .{});
                try self.emitIndent();
                try self.emit("var _has_yielded = false;\n", .{});
                try self.emitIndent();
                try self.emit("_ = &_has_yielded;\n", .{});
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
                    try self.emit("if (_has_yielded) return _yield_list else return Dynamic{{ .value = .none_type }};\n", .{});
                } else {
                    try self.emitIndent();
                    try self.emit("return;\n", .{});
                }
            }
            
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit("}}\n", .{});
            self.is_strict = orig_strict;
        }
    }
    
    if (!has_init) {
        try self.emitIndent();
        try self.emit("pub inline fn __init__(self: *{s}) anyerror!Dynamic {{\n", .{c.name});
        try self.emitIndent();
        try self.emit("    _ = &self;\n", .{});
        try self.emitIndent();
        try self.emit("    return Dynamic{{ .value = .none_type }};\n", .{});
        try self.emitIndent();
        try self.emit("}}\n", .{});
    }
    
    self.indent_level -= 1;
    try self.emit("}};\n\n", .{});
}
