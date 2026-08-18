const std = @import("std");
const ast = @import("../../core/ast.zig");
const EscapeAnalyzer = @import("escape.zig").EscapeAnalyzer;

pub fn analyzeSecondPass(self: *EscapeAnalyzer, node: *ast.Node) anyerror!void {
    // Second pass: find escapes!
    switch (node.*) {
        .return_stmt => |r| {
            if (r.value) |v| {
                if (v.* == .identifier) {
                    try self.markEscape(v.identifier.name);
                }
                try analyzeSecondPass(self, v);
            }
        },
        .call => |c| {
            // Passing to a function implies escape (conservative)
            for (c.args.items) |arg| {
                if (arg.* == .identifier) {
                    try self.markEscape(arg.identifier.name);
                }
                try analyzeSecondPass(self, arg);
            }
            try analyzeSecondPass(self, c.callee);
        },
        .method_call => |m| {
            // Passing to a method as arg implies escape
            for (m.args.items) |arg| {
                if (arg.* == .identifier) {
                    try self.markEscape(arg.identifier.name);
                }
                try analyzeSecondPass(self, arg);
            }
            try analyzeSecondPass(self, m.target);
        },
        .assign => |a| {
            try analyzeSecondPass(self, a.value);
        },
        // Recursive traversal for block nodes
        .def_stmt => |d| {
            for (d.body.items) |stmt| try analyzeSecondPass(self, stmt);
        },
        .if_stmt => |ifs| {
            try analyzeSecondPass(self, ifs.condition);
            for (ifs.then_branch.items) |stmt| try analyzeSecondPass(self, stmt);
            for (ifs.elifs.items) |elif| {
                try analyzeSecondPass(self, elif.condition);
                for (elif.then_branch.items) |stmt| try analyzeSecondPass(self, stmt);
            }
            if (ifs.else_branch) |eb| {
                for (eb.items) |stmt| try analyzeSecondPass(self, stmt);
            }
        },
        .while_stmt => |w| {
            try analyzeSecondPass(self, w.condition);
            for (w.body.items) |stmt| try analyzeSecondPass(self, stmt);
        },
        .for_stmt => |f| {
            try analyzeSecondPass(self, f.iterable);
            for (f.body.items) |stmt| try analyzeSecondPass(self, stmt);
        },
        .try_stmt => |t| {
            for (t.body.items) |stmt| try analyzeSecondPass(self, stmt);
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| try analyzeSecondPass(self, stmt);
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| try analyzeSecondPass(self, stmt);
            }
        },
        .list_expr => |l| {
            for (l.items.items) |item| {
                if (item.* == .identifier) try self.markEscape(item.identifier.name);
                try analyzeSecondPass(self, item);
            }
        },
        .dict_expr => |d| {
            for (d.keys.items) |key| {
                if (key.* == .identifier) try self.markEscape(key.identifier.name);
                try analyzeSecondPass(self, key);
            }
            for (d.values.items) |val| {
                if (val.* == .identifier) try self.markEscape(val.identifier.name);
                try analyzeSecondPass(self, val);
            }
        },
        .binary => |b| {
            try analyzeSecondPass(self, b.left);
            try analyzeSecondPass(self, b.right);
        },
        .unary => |u| {
            try analyzeSecondPass(self, u.right);
        },
        else => {},
    }
}
