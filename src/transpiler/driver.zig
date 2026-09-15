const std = @import("std");
const ast = @import("../core/ast.zig");
const Transpiler = @import("transpiler.zig").Transpiler;

pub fn transpile(self: *Transpiler, program: std.ArrayList(*ast.Node)) ![]const u8 {
    var prefix_buf = try self.allocator.alloc(u8, self.depth * 3);
    defer self.allocator.free(prefix_buf);
    var _d: usize = 0;
    while (_d < self.depth) : (_d += 1) {
        @memcpy(prefix_buf[_d * 3 .. _d * 3 + 3], "../");
    }
    const prefix = prefix_buf;

// First pass: check for #strict and collect imports recursively
    var seen_code_before_strict = false;
    for (program.items) |stmt| {
        if (stmt.* == .directive_strict) {
            self.is_strict = true;
            if (seen_code_before_strict) {
                // User requirement: if there is Python code before #strict, dynamic cannot be dropped.
                @import("../core/compiler.zig").global_uses_dynamic = true;
            }
        } else if (stmt.* != .import_stmt and stmt.* != .from_import) {
            // Not an import, not a strict directive, this is actual code.
            seen_code_before_strict = true;
        }
        
        try self.collectImports(stmt);
        try self.escape_analyzer.analyzeFirstPass(stmt);
    }
    for (program.items) |stmt| {
        try self.escape_analyzer.analyzeSecondPass(stmt);
    }
    
    try self.emit("const std = @import(\"std\");\n\n", .{});
    try self.emit("/// IMPORTS_PLACEHOLDER\n\n", .{});
    
    for (program.items) |stmt| {
        if (stmt.* == .import_stmt) {
            const i = stmt.import_stmt;
            const base_target_name = if (i.alias) |a| a else i.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const mod_slash = try self.getModSlash(i.name);
            defer self.allocator.free(mod_slash);
            try self.emit("pub const {s} = @import(\"{s}.zig\");\n", .{target_name, mod_slash});
        } else if (stmt.* == .from_import) {
            const f = stmt.from_import;
            const base_target_name = if (f.alias) |a| a else f.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const mod_slash = try self.getModSlash(f.module);
            defer self.allocator.free(mod_slash);
            const mod_ident = try self.allocator.dupe(u8, mod_slash);
            defer self.allocator.free(mod_ident);
            for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-' or c_.* == '.') { c_.* = '_'; } }

            try self.emit("pub const {s}_mod = @import(\"{s}.zig\");\n", .{mod_ident, mod_slash});
            try self.emit("pub const _sundapy_has_decl_{s} = @hasDecl({s}_mod, \"{s}\");\n", .{target_name, mod_ident, f.name});
            try self.emit("pub const _sundapy_is_abi_{s} = !_sundapy_has_decl_{s};\n", .{target_name, target_name});
            try self.emit("pub var {s}: if (_sundapy_has_decl_{s}) @TypeOf(@field({s}_mod, \"{s}\")) else @import(\"{s}datatype/dynamic.zig\").Dynamic = if (_sundapy_has_decl_{s}) @field({s}_mod, \"{s}\") else undefined;\n", .{target_name, target_name, mod_ident, f.name, prefix, target_name, mod_ident, f.name});
            try self.emit("pub var {s}_dyn: @import(\"{s}datatype/dynamic.zig\").Dynamic = undefined;\n", .{target_name, prefix});
        }


    }
    
    try self.emit("\npub var alloc: std.mem.Allocator = undefined;\n\n", .{});
    
    // Output global variables for all top-level assignments
    var global_vars = std.StringHashMap(bool).init(self.allocator);
    defer global_vars.deinit();
    
    var strict_funcs = std.StringHashMap(bool).init(self.allocator);
    defer strict_funcs.deinit();
    
    
    for (program.items) |stmt| {
        if (stmt.* == .class_stmt) {
            const c = stmt.class_stmt;
            try self.classes.put(c.name, true);
            try self.class_asts.put(c.name, stmt);
        }
    }

    for (program.items) |stmt| {
        if (stmt.* == .assign) {
            const a = stmt.assign;
            if (!global_vars.contains(a.target)) {
                try global_vars.put(a.target, true);
                if (self.is_strict) {
                    if (a.type_ann) |t| {
                        try self.emit("var {s}: {s} = undefined;\n", .{a.target, Transpiler.mapType(t)});
                    } else {
                        std.debug.print("Strict Mode Error: Variable '{s}' requires explicit static type annotation upon initialization.\n", .{a.target});
                        return error.MissingTypeAnnotation;
                    }
                } else {
                    if (a.type_ann) |t| {
                        try self.emit("var {s}: {s} = undefined;\n", .{a.target, Transpiler.mapType(t)});
                    } else {
                        if (a.value.* == .call and a.value.call.callee.* == .identifier and self.classes.contains(a.value.call.callee.identifier.name)) {
                            try self.emit("var {s}: {s} = undefined;\n", .{ a.target, a.value.call.callee.identifier.name });
                            continue;
                        }

                        if (self.escape_analyzer.variables.get(a.target)) |v_info| {
                            if (v_info.class == .stack and v_info.is_primitive) {
                                // Use inferred primitive type for global
                                const t = self.escape_analyzer.primitiveTypeString(a.value);
                                try self.emit("var {s}: {s} = undefined;\n", .{a.target, t});
                                continue;
                            }
                        }
                        try self.emit("var {s}: Dynamic = undefined;\n", .{a.target});
                    }
                }
            }
        } else if (stmt.* == .const_assign) {
            // Actually const assignment needs a value, but we can just let it be in main()
            // unless functions need them. We will just put everything in main for const for now.
        } else if (stmt.* == .def_stmt) {
            const d = stmt.def_stmt;
            if (d.is_strict or self.is_strict) {
                try strict_funcs.put(d.name, true);
            }
        }
    }

    
    // Output all top-level defs or classes
    for (program.items) |stmt| {
        if (stmt.* == .def_stmt) {
            const d = stmt.def_stmt;
            try @import("stmt/stmt_def.zig").transpileDefStmt(self, d, &global_vars, &strict_funcs);
        } else if (stmt.* == .class_stmt) {
            try @import("stmt/stmt_class.zig").transpileClassStmt(self, stmt.class_stmt, &strict_funcs);
        }
    }
    
    // For python-like scripts, top level statements must be in __sundapy_module_init
    try self.emit("pub fn __sundapy_module_init() !void {{\n", .{});
    self.indent_level += 1;
    if (self.is_strict) {
        try self.emitIndent();
        try self.emit("@setRuntimeSafety(true);\n", .{});
    }
    try self.emitIndent();
    try self.emit("alloc = std.heap.c_allocator;\n", .{});

    // Emit init calls for all imported modules (ABI wrappers need __sundapy_module_init)
    for (program.items) |stmt| {
        if (stmt.* == .import_stmt) {
            const i = stmt.import_stmt;
            const base_target_name = if (i.alias) |a| a else i.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            try self.emitIndent();
            try self.emit("if (@hasDecl({s}, \"__sundapy_module_init\")) try {s}.__sundapy_module_init();\n", .{target_name, target_name});
        } else if (stmt.* == .from_import) {
            const f = stmt.from_import;
            const base_target_name = if (f.alias) |a| a else f.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const mod_slash = try self.getModSlash(f.module);
            defer self.allocator.free(mod_slash);
            
            const mod_ident = try self.allocator.dupe(u8, mod_slash);
            defer self.allocator.free(mod_ident);
            for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-' or c_.* == '.') { c_.* = '_'; } }

            try self.emitIndent();
            try self.emit("if (@hasDecl({s}_mod, \"__sundapy_module_init\")) try {s}_mod.__sundapy_module_init();\n", .{mod_ident, mod_ident});
            try self.emitIndent();
            try self.emit("if (comptime @hasDecl({s}_mod, \"builtin_getattr\")) {{\n", .{mod_ident});
            try self.emitIndent();
            try self.emit("    const _tmp_{s} = {s}_mod.builtin_getattr(\"{s}\");\n", .{target_name, mod_ident, f.name});
            try self.emitIndent();
            try self.emit("    {s}_dyn = _tmp_{s};\n", .{target_name, target_name});
            try self.emitIndent();
            try self.emit("    if (comptime _sundapy_is_abi_{s}) {s} = _tmp_{s};\n", .{target_name, target_name, target_name});
            try self.emitIndent();
            try self.emit("}}\n", .{});
        }

    }

    
    var declared_vars = std.StringHashMap(bool).init(self.allocator);
    defer declared_vars.deinit();

    var it = global_vars.iterator();
    while (it.next()) |entry| {
        try declared_vars.put(entry.key_ptr.*, true);
    }

    for (program.items) |stmt| {
        if (stmt.* == .import_stmt or stmt.* == .from_import) continue;
        try self.transpileStmt(stmt, &declared_vars, &strict_funcs);
    }
    
    self.indent_level -= 1;
    try self.emit("}}\n", .{});
    
    // Check if `dynamic.` or `Dynamic` is used in the output
    var needs_dynamic = false;
    if (std.mem.indexOf(u8, self.out.items, "dynamic.") != null) needs_dynamic = true;
    if (std.mem.indexOf(u8, self.out.items, " Dynamic") != null) needs_dynamic = true;
    if (std.mem.indexOf(u8, self.out.items, "(Dynamic") != null) needs_dynamic = true;
    if (std.mem.indexOf(u8, self.out.items, "Dynamic.") != null) needs_dynamic = true;
    
    if (needs_dynamic) {
        @import("../core/compiler.zig").global_uses_dynamic = true;
    }
    
    const out_str = self.out.items;
    
    const dyn_import_str = if (@import("../core/compiler.zig").global_uses_dynamic)
        try std.fmt.allocPrint(self.allocator, "const dynamic = @import(\"{s}datatype/dynamic.zig\");\nconst Dynamic = dynamic.Dynamic;\nconst int = Dynamic.initStr(\"int\");\nconst @\"float\" = Dynamic.initStr(\"float\");\nconst str = Dynamic.initStr(\"str\");\nconst list = Dynamic.initStr(\"list\");\nconst dict = Dynamic.initStr(\"dict\");\nconst @\"bool\" = Dynamic.initStr(\"bool\");\n\n", .{prefix})
    else
        try std.fmt.allocPrint(self.allocator, "// Pure static mode\nconst Dynamic = void;\n", .{});
    defer self.allocator.free(dyn_import_str);
        
    const final_out = try std.mem.replaceOwned(u8, self.allocator, out_str, "/// IMPORTS_PLACEHOLDER\n\n", dyn_import_str);
    self.out.deinit(self.allocator);
    var new_out = std.ArrayListUnmanaged(u8).empty;
    try new_out.appendSlice(self.allocator, final_out);
    self.allocator.free(final_out);
    self.out = new_out;

    return self.out.items;
}
