const std = @import("std");
const ast = @import("../core/ast.zig");

pub const Transpiler = struct {
    allocator: std.mem.Allocator,
    out: std.ArrayList(u8),
    indent_level: usize = 0,
    is_strict: bool = false,
    is_strict_expr: bool = false,
    needs_dynamic: bool = false,
    strict_funcs: ?*std.StringHashMap(bool) = null,
    safe_funcs: ?*std.StringHashMap(bool) = null,
    current_declared_vars: ?*std.StringHashMap(bool) = null,
    try_depth: usize = 0,
    label_counter: usize = 0,
    classes: std.StringHashMap(bool),
    class_asts: std.StringHashMap(*ast.Node),
    imported_modules: std.ArrayList([]const u8),
    module_aliases: std.StringHashMap([]const u8),
    scoped_aliases: std.StringHashMap([]const u8),
    c_imported_modules: std.StringHashMap(bool),
    is_root: bool,
    escape_analyzer: *@import("analysis/escape.zig").EscapeAnalyzer,
    current_func_has_yield: bool = false,
    has_async_def: bool = false,
    
    depth: usize = 0,
    mod_name: []const u8 = "",
    is_package: bool = false,
    pub fn init(allocator: std.mem.Allocator, is_root: bool, mod_name: []const u8, is_package: bool) Transpiler {
        const ea = allocator.create(@import("analysis/escape.zig").EscapeAnalyzer) catch unreachable;
        ea.* = @import("analysis/escape.zig").EscapeAnalyzer.init(allocator);

        var d_cnt: usize = 0;
        if (!is_root and mod_name.len > 0) {
            for (mod_name) |c| {
                if (c == '.') d_cnt += 1;
            }
        }
        return Transpiler{
            .allocator = allocator,
            .out = .empty,
            .classes = std.StringHashMap(bool).init(allocator),
            .class_asts = std.StringHashMap(*ast.Node).init(allocator),
            .imported_modules = .empty,
            .module_aliases = std.StringHashMap([]const u8).init(allocator),
            .scoped_aliases = std.StringHashMap([]const u8).init(allocator),
            .c_imported_modules = std.StringHashMap(bool).init(allocator),
            .is_root = is_root,
            .escape_analyzer = ea,
            .depth = d_cnt,
            .mod_name = mod_name,
            .is_package = is_package,
        };
    }
    
    pub fn isStrict(self: *const Transpiler) bool {
        return self.is_strict or self.is_strict_expr;
    }
    
    pub fn deinit(self: *Transpiler) void {
        self.out.deinit(self.allocator);
        self.classes.deinit();
        self.class_asts.deinit();
        self.imported_modules.deinit(self.allocator);
        self.module_aliases.deinit();
        self.scoped_aliases.deinit();
        self.c_imported_modules.deinit();
        self.escape_analyzer.deinit();
        self.allocator.destroy(self.escape_analyzer);
    }
    
    pub fn emit(self: *Transpiler, comptime fmt: []const u8, args: anytype) !void {
        const str = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(str);
        try self.out.appendSlice(self.allocator, str);
    }
    
    pub fn emitIndent(self: *Transpiler) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.out.appendSlice(self.allocator, "    ");
        }
    }
    
    pub fn escapeKeyword(self: *Transpiler, name: []const u8) ![]const u8 {
        if (std.mem.eql(u8, name, "*")) { self.label_counter += 1; return std.fmt.allocPrint(self.allocator, "_star_{d}", .{self.label_counter}); }
        const keywords = [_][]const u8{ "_", "error", "async", "await", "var", "const", "fn", "test", "pub", "inline", "comptime", "switch", "return", "try", "catch", "break", "continue", "if", "else", "while", "for", "and", "or", "struct", "enum", "union", "defer", "errdefer" };
        for (keywords) |kw| {
            if (std.mem.eql(u8, name, kw)) {
                return std.fmt.allocPrint(self.allocator, "@\"{s}\"", .{name});
            }
        }
        const duped = try self.allocator.dupe(u8, name);
        for (duped) |*ch| {
            if (ch.* == '(' or ch.* == ')' or ch.* == '*' or ch.* == '-' or ch.* == '/') ch.* = '_';
        }
        return duped;
    }
    
    pub fn getModSlash(self: *Transpiler, mod_name: []const u8) ![]const u8 {
        var start_idx: usize = 0;
        while (start_idx < mod_name.len and mod_name[start_idx] == '.') {
            start_idx += 1;
        }
        var raw = mod_name[start_idx..];
        while (raw.len > 0 and raw[0] == '/') {
            raw = raw[1..];
        }
        if (std.mem.endsWith(u8, raw, ".zig")) {
            raw = raw[0 .. raw.len - 4];
        }
        const clean_sub = try self.allocator.dupe(u8, raw);
        defer self.allocator.free(clean_sub);
        for (clean_sub) |*c| {
            if (c.* == '.') c.* = '/';
        }

        var canon_mod: []const u8 = clean_sub;
        var free_canon = false;
        defer if (free_canon) self.allocator.free(canon_mod);

        if (start_idx > 0) {
            if (self.mod_name.len == 0) {
                std.debug.print("ImportError: attempted relative import with no known parent package\n", .{});
                return error.RelativeImportNoParentPackage;
            }
            var base_pkg = self.mod_name;
            if (!self.is_package) {
                if (std.mem.lastIndexOfScalar(u8, base_pkg, '.')) |idx| {
                    base_pkg = base_pkg[0..idx];
                } else {
                    base_pkg = "";
                }
            }
            var up_dots = start_idx - 1;
            while (up_dots > 0 and base_pkg.len > 0) : (up_dots -= 1) {
                if (std.mem.lastIndexOfScalar(u8, base_pkg, '.')) |idx| {
                    base_pkg = base_pkg[0..idx];
                } else {
                    base_pkg = "";
                }
            }
            if (up_dots > 0 or base_pkg.len == 0) {
                std.debug.print("ValueError: attempted relative import beyond top-level package\n", .{});
                return error.RelativeImportBeyondTopLevel;
            }
            const base_slash = try std.mem.replaceOwned(u8, self.allocator, base_pkg, ".", "/");
            defer self.allocator.free(base_slash);
            if (clean_sub.len > 0) {
                canon_mod = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ base_slash, clean_sub });
            } else {
                canon_mod = try self.allocator.dupe(u8, base_slash);
            }
            free_canon = true;
        }

        const up = self.depth;
        const prefix_len = up * 3;
        var buf = try self.allocator.alloc(u8, prefix_len + canon_mod.len);
        var i: usize = 0;
        while (i < up) : (i += 1) {
            @memcpy(buf[i * 3 .. i * 3 + 3], "../");
        }
        @memcpy(buf[prefix_len..], canon_mod);
        return buf;
    }
    
    pub fn collectImports(self: *Transpiler, stmt: *ast.Node) !void {
        switch (stmt.*) {
            .import_stmt => |i| {
                try self.imported_modules.append(self.allocator, i.name);
                const base_name = if (i.alias) |a| a else (if (std.mem.endsWith(u8, i.name, ".zig") or std.mem.endsWith(u8, i.name, ".h") or std.mem.endsWith(u8, i.name, ".c")) std.fs.path.stem(i.name) else i.name);
                try self.module_aliases.put(base_name, i.name);
                if (std.mem.endsWith(u8, i.name, ".h") or std.mem.endsWith(u8, i.name, ".c")) {
                    try self.c_imported_modules.put(base_name, true);
                }
            },
            .from_import => |f| {
                var is_all_dots = true;
                for (f.module) |c| {
                    if (c != '.') { is_all_dots = false; break; }
                }
                const full_mod = if (is_all_dots and !std.mem.eql(u8, f.name, "*"))
                    try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ f.module, f.name })
                else
                    f.module;
                try self.imported_modules.append(self.allocator, full_mod);
                if (f.alias) |a| try self.module_aliases.put(a, full_mod);
                const base_mod = if (std.mem.endsWith(u8, full_mod, ".zig") or std.mem.endsWith(u8, full_mod, ".h") or std.mem.endsWith(u8, full_mod, ".c")) std.fs.path.stem(full_mod) else (if (is_all_dots) f.name else full_mod);
                try self.module_aliases.put(base_mod, full_mod);
                if (std.mem.endsWith(u8, full_mod, ".h") or std.mem.endsWith(u8, full_mod, ".c")) {
                    try self.c_imported_modules.put(base_mod, true);
                }
            },
            .def_stmt => |d| {
                if (d.is_async) {
                    self.has_async_def = true;
                }
                for (d.body.items) |s| try self.collectImports(s);
            },
            .if_stmt => |ifs| {
                for (ifs.then_branch.items) |s| try self.collectImports(s);
                for (ifs.elifs.items) |e| {
                    for (e.then_branch.items) |s| try self.collectImports(s);
                }
                if (ifs.else_branch) |eb| {
                    for (eb.items) |s| try self.collectImports(s);
                }
            },
            .while_stmt => |w| {
                for (w.body.items) |s| try self.collectImports(s);
                if (w.else_body) |eb| {
                    for (eb.items) |s| try self.collectImports(s);
                }
            },
            .for_stmt => |f| {
                for (f.body.items) |s| try self.collectImports(s);
                if (f.else_body) |eb| {
                    for (eb.items) |s| try self.collectImports(s);
                }
            },
            .with_stmt => |w| {
                for (w.body.items) |s| try self.collectImports(s);
            },
            .try_stmt => |t| {
                for (t.body.items) |s| try self.collectImports(s);
                for (t.except_clauses.items) |ec| {
                    for (ec.body.items) |s| try self.collectImports(s);
                }
                if (t.except_branch) |e| {
                    for (e.items) |s| try self.collectImports(s);
                }
                if (t.else_branch) |eb| {
                    for (eb.items) |s| try self.collectImports(s);
                }
                if (t.finally_branch) |fb| {
                    for (fb.items) |s| try self.collectImports(s);
                }
            },
            .match_stmt => |m| {
                for (m.cases.items) |c| {
                    for (c.body.items) |s| try self.collectImports(s);
                }
            },
            .class_stmt => |c| {
                for (c.methods.items) |s| try self.collectImports(s);
            },
            .compound_stmt => |cs| {
                for (cs.items.items) |s| try self.collectImports(s);
            },
            else => {},
        }
    }
    
    pub const transpile = @import("driver.zig").transpile;
    pub const transpileStmt = @import("stmt_dispatcher.zig").transpileStmt;

    pub const transpileExpr = @import("expr/expr.zig").transpileExpr;
    pub const transpileExprStrict = @import("expr/expr_strict.zig").transpileExprStrict;
    pub const mapOpToMethod = @import("expr/expr.zig").mapOpToMethod;

    pub fn mapType(python_type: []const u8) []const u8 {
        if (std.mem.eql(u8, python_type, "str")) return "[]const u8";
        if (std.mem.eql(u8, python_type, "int")) return "i64";
        if (std.mem.eql(u8, python_type, "float")) return "f64";
        if (std.mem.eql(u8, python_type, "bool")) return "bool";
        if (std.mem.eql(u8, python_type, "list")) return "Dynamic";
        if (std.mem.eql(u8, python_type, "dict")) return "Dynamic";
        if (std.mem.eql(u8, python_type, "None")) return "void";
        if (std.mem.eql(u8, python_type, "...")) return "Dynamic";
        return python_type;
    }

    pub const isSafeNode = @import("analysis/analysis.zig").isSafeNode;
    pub const isRecursive = @import("analysis/analysis.zig").isRecursive;
};
