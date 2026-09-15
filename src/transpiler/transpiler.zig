const std = @import("std");
const ast = @import("../core/ast.zig");

pub const Transpiler = struct {
    allocator: std.mem.Allocator,
    out: std.ArrayList(u8),
    indent_level: usize = 0,
    is_strict: bool = false,
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
    is_root: bool,
    escape_analyzer: *@import("analysis/escape.zig").EscapeAnalyzer,
    
    depth: usize = 0,
    pub fn init(allocator: std.mem.Allocator, is_root: bool, mod_name: []const u8) Transpiler {
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
            .is_root = is_root,
            .escape_analyzer = ea,
            .depth = d_cnt,
        };
    }
    
    pub fn deinit(self: *Transpiler) void {
        self.out.deinit(self.allocator);
        self.classes.deinit();
        self.class_asts.deinit();
        self.imported_modules.deinit(self.allocator);
        self.module_aliases.deinit();
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
        const keywords = [_][]const u8{ "error", "async", "await", "var", "const", "fn", "test", "pub", "inline", "comptime", "switch", "return", "try", "catch", "break", "continue", "if", "else", "while", "for", "and", "or", "struct", "enum", "union", "defer", "errdefer" };
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
        if (start_idx == mod_name.len) {
            return try self.allocator.dupe(u8, "___dummy___");
        }
        const mod_slash = try self.allocator.dupe(u8, mod_name[start_idx..]);
        for (mod_slash) |*c| {
            if (c.* == '.') c.* = '/';
        }
        return mod_slash;
    }
    
    pub fn collectImports(self: *Transpiler, stmt: *ast.Node) !void {
        switch (stmt.*) {
            .import_stmt => |i| {
                try self.imported_modules.append(self.allocator, i.name);
                if (i.alias) |a| try self.module_aliases.put(a, i.name);
            },
            .from_import => |f| {
                try self.imported_modules.append(self.allocator, f.module);
                if (f.alias) |a| try self.module_aliases.put(a, f.module);
            },
            .def_stmt => |d| {
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
            },
            .for_stmt => |f| {
                for (f.body.items) |s| try self.collectImports(s);
            },
            .try_stmt => |t| {
                for (t.body.items) |s| try self.collectImports(s);
                if (t.except_branch) |e| {
                    for (e.items) |s| try self.collectImports(s);
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
        return python_type;
    }

    pub const isSafeNode = @import("analysis/analysis.zig").isSafeNode;
    pub const isRecursive = @import("analysis/analysis.zig").isRecursive;
};
