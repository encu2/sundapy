const std = @import("std");
const ast = @import("../core/ast.zig");
const Transpiler = @import("transpiler.zig").Transpiler;

fn isModOrAlias(self: *Transpiler, name: []const u8) bool {
    if (self.module_aliases.get(name) != null) return true;
    for (self.imported_modules.items) |mod| { if (std.mem.eql(u8, name, mod)) return true; }
    return false;
}

fn isFromImport(program: std.ArrayList(*ast.Node), name: []const u8) bool {
    for (program.items) |stmt| {
        if (stmt.* == .from_import and std.mem.eql(u8, if (stmt.from_import.alias) |a| a else stmt.from_import.name, name)) return true;
    }
    return false;
}

fn resolveStructTypeName(self: *Transpiler, program: std.ArrayList(*ast.Node), node: *ast.Node) ?[]const u8 {
    return switch (node.*) {
        .identifier => |i| if (isModOrAlias(self, i.name) or ((self.classes.contains(i.name) or isFromImport(program, i.name)) and (i.name.len > 0 and i.name[0] >= 'A' and i.name[0] <= 'Z'))) i.name else null,
        .getattr => |g| blk: {
            const parent = resolveStructTypeName(self, program, g.target) orelse break :blk null;
            break :blk std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, g.attr }) catch null;
        },
        else => null,
    };
}

fn emitGlobalTupleTarget(self: *Transpiler, tgt: *ast.Node, global_vars: *std.StringHashMap(bool)) anyerror!void {
    switch (tgt.*) {
        .identifier => |id| {
            if (!global_vars.contains(id.name)) {
                try global_vars.put(id.name, true);
                try self.emit("pub var {s}: Dynamic = undefined;\n", .{id.name});
            }
        },
        .starred => |s| try emitGlobalTupleTarget(self, s.value, global_vars),
        .list_expr, .tuple_expr => |lt| {
            for (lt.items.items) |item| try emitGlobalTupleTarget(self, item, global_vars);
        },
        else => {},
    }
}

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
    try self.emit("const std = @import(\"std\");\n\n/// IMPORTS_PLACEHOLDER\n\n", .{});
    var emitted_from_mods = std.StringHashMap(void).init(self.allocator);
    defer {
        var it_em = emitted_from_mods.keyIterator();
        while (it_em.next()) |k| self.allocator.free(k.*);
        emitted_from_mods.deinit();
    }
    
    for (program.items) |stmt| {
        if (stmt.* == .import_stmt) {
            const i = stmt.import_stmt;
            if (std.mem.endsWith(u8, i.name, ".h") or std.mem.endsWith(u8, i.name, ".c")) {
                const base_name = if (i.alias) |a| a else std.fs.path.stem(i.name);
                const target_name = try self.escapeKeyword(base_name);
                defer self.allocator.free(target_name);
                if (!emitted_from_mods.contains(target_name)) {
                    try emitted_from_mods.put(try self.allocator.dupe(u8, target_name), {});
                    try self.emit("pub const {s} = @cImport({{\n    @cInclude(\"{s}\");\n}});\n", .{ target_name, i.name });
                }
            } else {
                const base_target_name = if (i.alias) |a| a else (if (std.mem.endsWith(u8, i.name, ".zig")) std.fs.path.stem(i.name) else i.name);
                const target_name = try self.escapeKeyword(base_target_name);
                defer self.allocator.free(target_name);
                if (!emitted_from_mods.contains(target_name)) {
                    try emitted_from_mods.put(try self.allocator.dupe(u8, target_name), {});
                    const mod_slash = try self.getModSlash(i.name);
                    defer self.allocator.free(mod_slash);
                    try self.emit("pub const {s} = @import(\"{s}.zig\");\n", .{ target_name, mod_slash });
                }
            }
        } else if (stmt.* == .from_import) {
            const f = stmt.from_import;
            const base_target_name = if (f.alias) |a| a else f.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            if (std.mem.endsWith(u8, f.module, ".h") or std.mem.endsWith(u8, f.module, ".c")) {
                const c_mod_stem = std.fs.path.stem(f.module);
                const c_mod_name = try self.escapeKeyword(c_mod_stem);
                defer self.allocator.free(c_mod_name);
                const c_ident = try std.fmt.allocPrint(self.allocator, "{s}_c", .{c_mod_name});
                defer self.allocator.free(c_ident);
                if (!emitted_from_mods.contains(c_ident)) {
                    try emitted_from_mods.put(try self.allocator.dupe(u8, c_ident), {});
                    try self.emit("pub const {s}_c = @cImport({{\n    @cInclude(\"{s}\");\n}});\n", .{ c_mod_name, f.module });
                }
                try self.emit("pub const {s} = @field({s}_c, \"{s}\");\n", .{ target_name, c_mod_name, f.name });
            } else {
                const is_all_dots = (std.mem.indexOfNone(u8, f.module, ".") == null);
                if (is_all_dots and !std.mem.eql(u8, f.name, "*")) {
                    const full_mod = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ f.module, f.name });
                    defer self.allocator.free(full_mod);
                    const mod_slash = try self.getModSlash(full_mod);
                    defer self.allocator.free(mod_slash);
                    if (!emitted_from_mods.contains(target_name)) {
                        try emitted_from_mods.put(try self.allocator.dupe(u8, target_name), {});
                        try self.emit("pub const {s} = @import(\"{s}.zig\");\n", .{ target_name, mod_slash });
                    }
                } else {
                    const mod_slash = try self.getModSlash(f.module);
                    defer self.allocator.free(mod_slash);
                    const mod_ident = try self.allocator.dupe(u8, mod_slash);
                    defer self.allocator.free(mod_ident);
                    for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-' or c_.* == '.') { c_.* = '_'; } }

                    const mod_var_ident = try std.fmt.allocPrint(self.allocator, "{s}_mod", .{mod_ident});
                    defer self.allocator.free(mod_var_ident);
                    if (!emitted_from_mods.contains(mod_var_ident)) {
                        try emitted_from_mods.put(try self.allocator.dupe(u8, mod_var_ident), {});
                        try self.emit("pub const {s}_mod = @import(\"{s}.zig\");\n", .{mod_ident, mod_slash});
                    }
                    try self.emit("pub const _sundapy_has_decl_{s} = @hasDecl({s}_mod, \"{s}\");\n", .{target_name, mod_ident, f.name});
                    try self.emit("pub const _sundapy_is_abi_{s} = !_sundapy_has_decl_{s};\n", .{target_name, target_name});
                    try self.emit("pub const {s} = if (_sundapy_has_decl_{s}) @field({s}_mod, \"{s}\") else void;\n", .{target_name, target_name, mod_ident, f.name});
                    try self.emit("pub var {s}_dyn: @import(\"{s}datatype/dynamic.zig\").Dynamic = undefined;\n", .{target_name, prefix});
                }
            }
        }
    }
    
    try self.out.appendSlice(self.allocator,
        \\pub inline fn _sundapy_to_f64(__sundapy_v: anytype) f64 {
        \\    const __sundapy_T = @TypeOf(__sundapy_v);
        \\    if (__sundapy_T == comptime_int or @typeInfo(__sundapy_T) == .int) return @as(f64, @floatFromInt(__sundapy_v));
        \\    if (__sundapy_T == comptime_float or @typeInfo(__sundapy_T) == .float) return @as(f64, @floatCast(__sundapy_v));
        \\    return 0.0;
        \\}
        \\pub inline fn _sundapy_pow(__sundapy_pa: anytype, __sundapy_pb: anytype) if (@TypeOf(__sundapy_pa) == comptime_float or @typeInfo(@TypeOf(__sundapy_pa)) == .float or @TypeOf(__sundapy_pb) == comptime_float or @typeInfo(@TypeOf(__sundapy_pb)) == .float) f64 else i64 {
        \\    if (comptime (@TypeOf(__sundapy_pa) == comptime_float or @typeInfo(@TypeOf(__sundapy_pa)) == .float or @TypeOf(__sundapy_pb) == comptime_float or @typeInfo(@TypeOf(__sundapy_pb)) == .float)) return std.math.pow(f64, _sundapy_to_f64(__sundapy_pa), _sundapy_to_f64(__sundapy_pb));
        \\    const __sundapy_bi: i64 = @intCast(__sundapy_pb);
        \\    return if (__sundapy_bi < 0) 0 else std.math.pow(i64, @as(i64, @intCast(__sundapy_pa)), @as(usize, @intCast(__sundapy_bi)));
        \\}
        \\pub inline fn _sundapy_to_c_arg(comptime TargetT: type, __sundapy_c_in: anytype) TargetT {
        \\    const ValT = @TypeOf(__sundapy_c_in);
        \\    if (ValT == TargetT) return __sundapy_c_in;
        \\    if (ValT == Dynamic) {
        \\        if (@typeInfo(TargetT) == .int) return @intCast(__sundapy_c_in.asInt());
        \\        if (@typeInfo(TargetT) == .float) return @floatCast(__sundapy_c_in.asFloat());
        \\        if (TargetT == bool) return __sundapy_c_in.toBool();
        \\        if (TargetT == []const u8 or TargetT == [:0]const u8) return __sundapy_c_in.value.str_type;
        \\        if (TargetT == [*c]const u8 or TargetT == [*:0]const u8) return @ptrCast(__sundapy_c_in.value.str_type.ptr);
        \\        if (TargetT == ?*anyopaque or TargetT == *anyopaque) return @ptrFromInt(@as(usize, @bitCast(__sundapy_c_in.asInt())));
        \\    }
        \\    if (@typeInfo(TargetT) == .int and @typeInfo(ValT) == .int) return @intCast(__sundapy_c_in);
        \\    if (@typeInfo(TargetT) == .float and @typeInfo(ValT) == .int) return @floatFromInt(__sundapy_c_in);
        \\    if (@typeInfo(TargetT) == .float and @typeInfo(ValT) == .float) return @floatCast(__sundapy_c_in);
        \\    return __sundapy_c_in;
        \\}
        \\pub inline fn _sundapy_param_type(comptime fn_info: anytype, comptime idx: usize) ?type {
        \\    return if (idx < fn_info.params.len) fn_info.params[idx].type else null;
        \\}
        \\pub inline fn _sundapy_cast_param(comptime OptT: ?type, __sundapy_c_in: anytype) if (OptT) |T| T else @TypeOf(__sundapy_c_in) {
        \\    return if (comptime OptT) |T| _sundapy_to_c_arg(T, __sundapy_c_in) else __sundapy_c_in;
        \\}
        \\pub var alloc: std.mem.Allocator = undefined;
        \\
    );
    const name_str = if (self.is_root) "__main__" else "module";
    const sundapy_header = try std.fmt.allocPrint(self.allocator,
        \\pub const __name__: []const u8 = "{s}";
        \\pub inline fn _sundapy_is_str(comptime __sundapy_T: type) bool {{
        \\    if (__sundapy_T == []const u8 or __sundapy_T == [:0]const u8 or __sundapy_T == []u8 or __sundapy_T == [:0]u8) return true;
        \\    const __sundapy_info = @typeInfo(__sundapy_T);
        \\    if (__sundapy_info == .pointer) {{
        \\        if (__sundapy_info.pointer.size == .slice and __sundapy_info.pointer.child == u8) return true;
        \\        if (__sundapy_info.pointer.size == .one and @typeInfo(__sundapy_info.pointer.child) == .array and @typeInfo(__sundapy_info.pointer.child).array.child == u8) return true;
        \\    }}
        \\    return false;
        \\}}
        \\pub inline fn _sundapy_eq(__sundapy_a: anytype, __sundapy_b: anytype) bool {{
        \\    const __sundapy_TA = @TypeOf(__sundapy_a);
        \\    const __sundapy_TB = @TypeOf(__sundapy_b);
        \\    const __sundapy_is_str_a = _sundapy_is_str(__sundapy_TA);
        \\    const __sundapy_is_str_b = _sundapy_is_str(__sundapy_TB);
        \\    if (comptime __sundapy_is_str_a and __sundapy_is_str_b) {{
        \\        return std.mem.eql(u8, __sundapy_a, __sundapy_b);
        \\    }} else if (comptime @typeInfo(__sundapy_TA) == .optional) {{
        \\        if (__sundapy_a) |__sundapy_val_a| return _sundapy_eq(__sundapy_val_a, __sundapy_b) else return __sundapy_b == null;
        \\    }} else if (comptime @typeInfo(__sundapy_TB) == .optional) {{
        \\        if (__sundapy_b) |__sundapy_val_b| return _sundapy_eq(__sundapy_a, __sundapy_val_b) else return __sundapy_a == null;
        \\    }} else if (comptime __sundapy_is_str_a != __sundapy_is_str_b) {{
        \\        return false;
        \\    }} else if (comptime (@typeInfo(__sundapy_TA) == .int or __sundapy_TA == comptime_int) and (@typeInfo(__sundapy_TB) == .int or __sundapy_TB == comptime_int)) {{
        \\        return if (comptime __sundapy_TA == __sundapy_TB) __sundapy_a == __sundapy_b else @as(i128, __sundapy_a) == @as(i128, __sundapy_b);
        \\    }} else if (comptime (@typeInfo(__sundapy_TA) == .float or __sundapy_TA == comptime_float) and (@typeInfo(__sundapy_TB) == .int or __sundapy_TB == comptime_int)) {{
        \\        return __sundapy_a == @as(f64, @floatFromInt(__sundapy_b));
        \\    }} else if (comptime (@typeInfo(__sundapy_TA) == .int or __sundapy_TA == comptime_int) and (@typeInfo(__sundapy_TB) == .float or __sundapy_TB == comptime_float)) {{
        \\        return @as(f64, @floatFromInt(__sundapy_a)) == __sundapy_b;
        \\    }} else {{
        \\        return __sundapy_a == __sundapy_b;
        \\    }}
        \\}}
        \\pub inline fn _sundapy_ne(__sundapy_a: anytype, __sundapy_b: anytype) bool {{
        \\    return !_sundapy_eq(__sundapy_a, __sundapy_b);
        \\}}
    , .{name_str});
    defer self.allocator.free(sundapy_header);
    try self.out.appendSlice(self.allocator, sundapy_header);
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
        if (stmt.* == .assign or stmt.* == .ann_decl) {
            const target = if (stmt.* == .assign) stmt.assign.target else stmt.ann_decl.target;
            const type_ann = if (stmt.* == .assign) stmt.assign.type_ann else stmt.ann_decl.type_ann;
            if (!global_vars.contains(target)) {
                try global_vars.put(target, true);
                if (self.is_strict) {
                    if (type_ann) |t| {
                        try self.emit("pub var {s}: {s} = undefined;\n", .{ target, Transpiler.mapType(t) });
                    } else {
                        std.debug.print("Strict Mode Error: Variable '{s}' requires explicit static type annotation upon initialization.\n", .{target});
                        return error.MissingTypeAnnotation;
                    }
                } else if (stmt.* == .ann_decl) {
                    try self.emit("pub var {s}: Dynamic = undefined;\n", .{target});
                } else {
                    const a = stmt.assign;
                    if (type_ann) |t| {
                        try self.emit("pub var {s}: {s} = undefined;\n", .{ target, Transpiler.mapType(t) });
                    } else {
                        var struct_type_name: ?[]const u8 = null;
                        if (a.value.* == .method_call and std.mem.eql(u8, a.value.method_call.method, "init")) {
                            struct_type_name = resolveStructTypeName(self, program, a.value.method_call.target);
                        } else if (a.value.* == .call) {
                            struct_type_name = resolveStructTypeName(self, program, a.value.call.callee);
                        }
                        if (struct_type_name) |stn| {
                            try self.emit("pub var {s}: {s} = undefined;\n", .{ target, stn });
                            continue;
                        }

                        if (self.escape_analyzer.variables.get(target)) |v_info| {
                            if (v_info.class == .stack and v_info.is_primitive) {
                                const t = self.escape_analyzer.primitiveTypeString(a.value);
                                try self.emit("pub var {s}: {s} = undefined;\n", .{ target, t });
                                continue;
                            }
                        }
                        try self.emit("pub var {s}: Dynamic = undefined;\n", .{target});
                    }
                }
            }
        } else if (stmt.* == .tuple_assign or stmt.* == .chained_assign) {
            const targets = if (stmt.* == .tuple_assign) stmt.tuple_assign.targets.items else stmt.chained_assign.targets.items;
            for (targets) |tgt| try emitGlobalTupleTarget(self, tgt, &global_vars);
        } else if (stmt.* == .compound_stmt) {
            for (stmt.compound_stmt.items.items) |cs| {
                if (cs.* == .tuple_assign or cs.* == .chained_assign) {
                    const targets = if (cs.* == .tuple_assign) cs.tuple_assign.targets.items else cs.chained_assign.targets.items;
                    for (targets) |tgt| try emitGlobalTupleTarget(self, tgt, &global_vars);
                }
            }
        } else if (stmt.* == .def_stmt) {
            if (stmt.def_stmt.is_strict or self.is_strict) try strict_funcs.put(stmt.def_stmt.name, true);
        }
    }

    
    // Output all top-level defs or classes
    for (program.items) |stmt| {
        if (stmt.* == .def_stmt) {
            const d = stmt.def_stmt;
            try @import("stmt/stmt_def.zig").transpileDefStmt(self, d, &global_vars, &strict_funcs);
        } else if (stmt.* == .class_stmt) {
            try @import("stmt/stmt_class.zig").transpileClassStmt(self, stmt.class_stmt, &global_vars, &strict_funcs);
        }
    }
    
    // For python-like scripts, top level statements must be in __sundapy_module_init
    try self.emit("var _module_initialized: bool = false;\npub fn __sundapy_module_init() anyerror!void {{\n    if (_module_initialized) return;\n    _module_initialized = true;\n", .{});
    self.indent_level += 1;
    const compiler = @import("../core/compiler.zig");
    if (compiler.is_release_fast) {
        try self.emitIndent();
        try self.emit("@setRuntimeSafety(false);\n", .{});
    } else if (self.is_strict) {
        try self.emitIndent();
        try self.emit("@setRuntimeSafety(true);\n", .{});
    }
    try self.emitIndent();
    try self.emit("alloc = std.heap.c_allocator;\n", .{});

    // Emit init calls for all imported modules (ABI wrappers need __sundapy_module_init)
    for (program.items) |stmt| {
        if (stmt.* == .import_stmt) {
            const i = stmt.import_stmt;
            if (std.mem.endsWith(u8, i.name, ".h") or std.mem.endsWith(u8, i.name, ".c")) continue;
            const base_target_name = if (i.alias) |a| a else (if (std.mem.endsWith(u8, i.name, ".zig")) std.fs.path.stem(i.name) else i.name);
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            try self.emitIndent();
            try self.emit("if (@hasDecl({s}, \"__sundapy_module_init\")) try {s}.__sundapy_module_init();\n", .{target_name, target_name});
        } else if (stmt.* == .from_import) {
            const f = stmt.from_import;
            if (std.mem.endsWith(u8, f.module, ".h") or std.mem.endsWith(u8, f.module, ".c")) continue;
            const base_target_name = if (f.alias) |a| a else f.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const is_all_dots = (std.mem.indexOfNone(u8, f.module, ".") == null);
            if (is_all_dots and !std.mem.eql(u8, f.name, "*")) {
                try self.emitIndent();
                try self.emit("if (@hasDecl({s}, \"__sundapy_module_init\")) try {s}.__sundapy_module_init();\n", .{target_name, target_name});
            } else {
                const mod_slash = try self.getModSlash(f.module);
                defer self.allocator.free(mod_slash);
                const mod_ident = try self.allocator.dupe(u8, mod_slash);
                defer self.allocator.free(mod_ident);
                for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-' or c_.* == '.') { c_.* = '_'; } }
                try self.emitIndent();
                try self.emit("if (@hasDecl({s}_mod, \"__sundapy_module_init\")) try {s}_mod.__sundapy_module_init();\n", .{mod_ident, mod_ident});
                try self.emitIndent();
                try self.emit("if (comptime @hasDecl({s}_mod, \"builtin_getattr\")) {s}_dyn = if (comptime @typeInfo(@TypeOf({s}_mod.builtin_getattr(\"{s}\"))) == .error_union) ({s}_mod.builtin_getattr(\"{s}\") catch Dynamic.initNone()) else {s}_mod.builtin_getattr(\"{s}\");\n", .{ mod_ident, target_name, mod_ident, f.name, mod_ident, f.name, mod_ident, f.name });
            }
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
    
    if (std.mem.indexOf(u8, self.out.items, "dynamic.") != null or std.mem.indexOf(u8, self.out.items, " Dynamic") != null or std.mem.indexOf(u8, self.out.items, "(Dynamic") != null or std.mem.indexOf(u8, self.out.items, "Dynamic.") != null) {
        @import("../core/compiler.zig").global_uses_dynamic = true;
    }
    
    const out_str = self.out.items;
    
    const dyn_import_str = if (@import("../core/compiler.zig").global_uses_dynamic)
        try std.fmt.allocPrint(self.allocator, "const dynamic = @import(\"{s}datatype/dynamic.zig\");\nconst Dynamic = dynamic.Dynamic;\nconst int = Dynamic.initStr(\"int\");\nconst @\"float\" = Dynamic.initStr(\"float\");\nconst str = Dynamic.initStr(\"str\");\nconst list = Dynamic.initStr(\"list\");\nconst dict = Dynamic.initStr(\"dict\");\nconst @\"bool\" = Dynamic.initStr(\"bool\");\nconst Ellipsis = dynamic.Ellipsis;\n\n", .{prefix})
    else
        try std.fmt.allocPrint(self.allocator, "// Pure static mode\nconst Dynamic = void;\nconst Ellipsis = void;\n", .{});
    defer self.allocator.free(dyn_import_str);
        
    const final_out = try std.mem.replaceOwned(u8, self.allocator, out_str, "/// IMPORTS_PLACEHOLDER\n\n", dyn_import_str);
    self.out.deinit(self.allocator);
    var new_out = std.ArrayListUnmanaged(u8).empty;
    try new_out.appendSlice(self.allocator, final_out);
    self.allocator.free(final_out);
    self.out = new_out;

    return self.out.items;
}
