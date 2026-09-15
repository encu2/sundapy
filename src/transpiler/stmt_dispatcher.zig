const std = @import("std");
const ast = @import("../core/ast.zig");
const Transpiler = @import("transpiler.zig").Transpiler;

pub fn transpileStmt(self: *Transpiler, stmt: *ast.Node, declared_vars: *std.StringHashMap(bool), strict_funcs: *std.StringHashMap(bool)) anyerror!void {
    self.current_declared_vars = declared_vars;
    self.strict_funcs = strict_funcs;
    try self.emitIndent();
    switch (stmt.*) {
        .pass_stmt => try self.emit("// pass\n", .{}),
        .directive_strict => try self.emit("// #strict mode enabled\n", .{}),
        .assign => |a| try @import("stmt/stmt_assign.zig").transpileAssign(self, a, declared_vars),
        .const_assign => |a| try @import("stmt/stmt_assign.zig").transpileConstAssign(self, a, declared_vars),
        .subscript_assign => |s| try @import("stmt/stmt_assign.zig").transpileSubscriptAssign(self, s),
        .setattr => |s| {
            try self.transpileExpr(s.target);
            try self.emit(".{s} = ", .{s.attr});
            try self.transpileExpr(s.value);
            try self.emit(";\n", .{});
        },
        .call => |c| try @import("stmt/stmt_misc.zig").transpileCall(self, c, stmt),
        .method_call => try @import("stmt/stmt_misc.zig").transpileMethodCall(self, stmt),
        .global_decl => |g| {
            try self.emit("// global {s}\n", .{g.name});
        },
        .del_stmt => |d| {
            _ = d;
            try self.emit("// del\n", .{});
        },
        .nonlocal_decl => |n| {
            try self.emit("// nonlocal {s}\n", .{n.name});
        },
        .def_stmt => {
            // def_stmt already emitted at module scope
        },
        .return_stmt => |r| try @import("stmt/stmt_misc.zig").transpileReturn(self, r),
        .if_stmt => |ifs| try @import("stmt/stmt_control.zig").transpileIfStmt(self, ifs, declared_vars, strict_funcs),
        .while_stmt => |w| try @import("stmt/stmt_control.zig").transpileWhileStmt(self, w, declared_vars, strict_funcs),
        .for_stmt => |f| try @import("stmt/stmt_control.zig").transpileForStmt(self, f, declared_vars, strict_funcs),
        .try_stmt => |t| try @import("stmt/stmt_control.zig").transpileTryStmt(self, t, declared_vars, strict_funcs),
        .match_stmt => |m| try @import("stmt/stmt_match.zig").transpileMatchStmt(self, m, declared_vars, strict_funcs),
        .continue_stmt => {
            try self.emit("continue;\n", .{});
        },
        .break_stmt => {
            try self.emit("break;\n", .{});
        },
        .raise_stmt => |r| try @import("stmt/stmt_misc.zig").transpileRaise(self, r),
        .import_stmt => |i| {
            const base_target_name = if (i.alias) |a| a else i.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const mod_slash = try self.getModSlash(i.name);
            defer self.allocator.free(mod_slash);
            const mod_ident = try self.allocator.dupe(u8, mod_slash);
            defer self.allocator.free(mod_ident);
            for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-') { c_.* = '_'; } }
            try self.emit("const {s} = @import(\"{s}.zig\");\n", .{target_name, mod_slash});
        },
        .from_import => |f| {
            const base_target_name = if (f.alias) |a| a else f.name;
            const target_name = try self.escapeKeyword(base_target_name);
            defer self.allocator.free(target_name);
            const mod_slash_raw = if (std.mem.eql(u8, f.module, ".")) try self.getModSlash(f.name) else try self.getModSlash(f.module);
            defer self.allocator.free(mod_slash_raw);
            const mod_slash = if (mod_slash_raw.len > 0 and mod_slash_raw[0] == '/') mod_slash_raw[1..] else mod_slash_raw;
            // Skip if mod_slash is empty or dummy
            if (mod_slash.len == 0 or std.mem.eql(u8, mod_slash, "__dummy___")) return;
            const mod_ident = try self.allocator.dupe(u8, mod_slash);
            defer self.allocator.free(mod_ident);
            for (mod_ident) |*c_| { if (c_.* == '/' or c_.* == '(' or c_.* == ')' or c_.* == '-' or c_.* == '.') { c_.* = '_'; } }
            
            try self.emit("const {s}_mod = @import(\"{s}.zig\");\n", .{mod_ident, mod_slash});
            try self.emit("comptime const _sundapy_is_abi_{s} = @hasDecl({s}_mod, \"_is_abi\");\n", .{mod_ident, mod_ident});
            if (!std.mem.startsWith(u8, target_name, "_star_")) {
                try self.emit("const {s} = if (!_sundapy_is_abi_{s}) {s}_mod.{s} else void;\n", .{target_name, mod_ident, mod_ident, target_name});
                try self.emit("var {s}_dyn: @import(\"datatype/dynamic.zig\").Dynamic = undefined;\n", .{target_name});
            }
        },
        .await_expr => |aw| {
            try self.emit("_ = (", .{});
            try self.transpileExpr(aw.value);
            try self.emit(")", .{});
            try self.emit(".awaitResult();\n", .{});
        },
        .yield_stmt => |y| try @import("stmt/stmt_misc.zig").transpileYield(self, y),
        .with_stmt => |w| try @import("stmt/stmt_control.zig").transpileWithStmt(self, w, declared_vars, strict_funcs),
        else => {
            try self.emit("// Unhandled stmt type: {any}\n", .{stmt.*});
        },
    }
}
