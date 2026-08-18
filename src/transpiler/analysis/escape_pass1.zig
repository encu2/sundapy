const std = @import("std");
const ast = @import("../../core/ast.zig");
const EscapeAnalyzer = @import("escape.zig").EscapeAnalyzer;

pub fn analyzeFirstPass(self: *EscapeAnalyzer, node: *ast.Node) anyerror!void {
    switch (node.*) {
        .assign => |a| {
            const is_prim = self.isPrimitive(a.value);
            const prim_type = if (is_prim) self.primitiveTypeString(a.value) else "i64";
            if (self.variables.getPtr(a.target)) |v| {
                if (!is_prim) {
                    v.is_primitive = false;
                } else if (!std.mem.eql(u8, v.primitive_type, prim_type)) {
                    // If assigned a different primitive type (e.g. f64 to i64),
                    // we must fall back to non-primitive to avoid Zig strict typing errors.
                    v.is_primitive = false;
                }
            } else {
                try self.variables.put(a.target, .{
                    .name = a.target,
                    .class = .stack,
                    .is_primitive = is_prim,
                    .primitive_type = prim_type,
                });
            }
            try analyzeFirstPass(self, a.value);
        },
        .const_assign => |c| {
            const is_prim = self.isPrimitive(c.value);
            const prim_type = if (is_prim) self.primitiveTypeString(c.value) else "i64";
            try self.variables.put(c.target, .{
                .name = c.target,
                .class = .stack,
                .is_primitive = is_prim,
                .primitive_type = prim_type,
            });
            try analyzeFirstPass(self, c.value);
        },
        .def_stmt => |d| {
            for (d.body.items) |stmt| {
                try analyzeFirstPass(self, stmt);
            }
        },
        .if_stmt => |ifs| {
            try analyzeFirstPass(self, ifs.condition);
            for (ifs.then_branch.items) |stmt| try analyzeFirstPass(self, stmt);
            for (ifs.elifs.items) |elif| {
                try analyzeFirstPass(self, elif.condition);
                for (elif.then_branch.items) |stmt| try analyzeFirstPass(self, stmt);
            }
            if (ifs.else_branch) |eb| {
                for (eb.items) |stmt| try analyzeFirstPass(self, stmt);
            }
        },
        .while_stmt => |w| {
            try analyzeFirstPass(self, w.condition);
            for (w.body.items) |stmt| try analyzeFirstPass(self, stmt);
        },
        .for_stmt => |f| {
            try self.variables.put(f.iterator, .{
                .name = f.iterator,
                .class = .stack, // loop vars are stack by default
                .is_primitive = false, // unknown iterator yield type
            });
            try analyzeFirstPass(self, f.iterable);
            for (f.body.items) |stmt| try analyzeFirstPass(self, stmt);
        },
        .list_expr => |l| {
            for (l.items.items) |item| try analyzeFirstPass(self, item);
        },
        .dict_expr => |d| {
            for (d.keys.items) |key| try analyzeFirstPass(self, key);
            for (d.values.items) |val| try analyzeFirstPass(self, val);
        },
        .binary => |b| {
            try analyzeFirstPass(self, b.left);
            try analyzeFirstPass(self, b.right);
        },
        .unary => |u| {
            try analyzeFirstPass(self, u.right);
        },
        .call => |c| {
            try analyzeFirstPass(self, c.callee);
            for (c.args.items) |arg| try analyzeFirstPass(self, arg);
        },
        .method_call => |m| {
            try analyzeFirstPass(self, m.target);
            for (m.args.items) |arg| try analyzeFirstPass(self, arg);
        },
        .return_stmt => |r| {
            if (r.value) |v| try analyzeFirstPass(self, v);
        },
        .try_stmt => |t| {
            for (t.body.items) |stmt| try analyzeFirstPass(self, stmt);
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| try analyzeFirstPass(self, stmt);
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| try analyzeFirstPass(self, stmt);
            }
        },
        else => {},
    }
}
