const std = @import("std");
const ast = @import("../../core/ast.zig");


pub fn isRecursive(node: *ast.Node, func_name: []const u8) bool {
    switch (node.*) {
        .number, .integer, .float, .string, .fstring, .await_expr, .assign_expr, .global_decl, .del_stmt, .nonlocal_decl, .continue_stmt, .break_stmt, .pass_stmt, .directive_strict, .none => return false,
        .ellipsis => return false,
        .dummy_expr => return false,
        .identifier => |i| return std.mem.eql(u8, i.name, func_name),
        .unary => |u| return isRecursive(u.right, func_name),
        .binary => |b| return isRecursive(b.left, func_name) or isRecursive(b.right, func_name),
        .assign => |a| return isRecursive(a.value, func_name),
        .const_assign => |c| return isRecursive(c.value, func_name),
        .return_stmt => |r| {
            if (r.value) |v| return isRecursive(v, func_name);
            return false;
        },
        .if_stmt, .while_stmt, .for_stmt, .match_stmt, .with_stmt => return false,
        .call => |c| {
            if (isRecursive(c.callee, func_name)) return true;
            for (c.args.items) |arg| {
                if (isRecursive(arg, func_name)) return true;
            }
            return false;
        },
        .method_call => |m| {
            if (isRecursive(m.target, func_name)) return true;
            for (m.args.items) |arg| {
                if (isRecursive(arg, func_name)) return true;
            }
            return false;
        },
        .getattr => |g| return isRecursive(g.target, func_name),
        .setattr => |s| return isRecursive(s.target, func_name) or isRecursive(s.value, func_name),
        .yield_expr => |y| if (y.value) |v| return isRecursive(v, func_name) else return false,
        .subscript => |s| return isRecursive(s.target, func_name) or isRecursive(s.index, func_name),
        .subscript_assign => |s| return isRecursive(s.target, func_name) or isRecursive(s.index, func_name) or isRecursive(s.value, func_name),
        .tuple_assign => |t| {
            if (isRecursive(t.value, func_name)) return true;
            for (t.targets.items) |tgt| {
                if (isRecursive(tgt, func_name)) return true;
            }
            return false;
        },
        .slice => |s| return isRecursive(s.target, func_name) or (if (s.start) |n| isRecursive(n, func_name) else false) or (if (s.stop) |n| isRecursive(n, func_name) else false) or (if (s.step) |n| isRecursive(n, func_name) else false),
        .slice_assign => |s| return isRecursive(s.target, func_name) or isRecursive(s.value, func_name) or (if (s.start) |n| isRecursive(n, func_name) else false) or (if (s.stop) |n| isRecursive(n, func_name) else false) or (if (s.step) |n| isRecursive(n, func_name) else false),
        .yield_stmt => |y| {
            if (y.value) |v| return isRecursive(v, func_name);
            return false;
        },
        .assert_stmt => |a| {
            if (isRecursive(a.condition, func_name)) return true;
            if (a.message) |m| if (isRecursive(m, func_name)) return true;
            return false;
        },
        .list_expr => |l| {
            for (l.items.items) |item| {
                if (isRecursive(item, func_name)) return true;
            }
            return false;
        },
        .list_comp => |l| {
            if (isRecursive(l.expression, func_name)) return true;
            if (isRecursive(l.iterable, func_name)) return true;
            if (l.condition) |cond| {
                if (isRecursive(cond, func_name)) return true;
            }
            return false;
        },
        .dict_expr => |d| {
            for (d.keys.items) |key| {
                if (isRecursive(key, func_name)) return true;
            }
            for (d.values.items) |val| {
                if (isRecursive(val, func_name)) return true;
            }
            return false;
        },
        .import_stmt, .from_import => return false,
        .try_stmt => |t| {
            for (t.body.items) |stmt| {
                if (isRecursive(stmt, func_name)) return true;
            }
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| {
                    if (isRecursive(stmt, func_name)) return true;
                }
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| {
                    if (isRecursive(stmt, func_name)) return true;
                }
            }
            return false;
        },
        .raise_stmt => |r| {
            if (r.value) |v| if (isRecursive(v, func_name)) return true;
            if (r.from_exc) |f| if (isRecursive(f, func_name)) return true;
            return false;
        },
        .def_stmt => |d| {
            for (d.body.items) |stmt| {
                if (isRecursive(stmt, func_name)) return true;
            }
            return false;
        },
        .class_stmt => |c| {
            for (c.methods.items) |stmt| {
                if (isRecursive(stmt, func_name)) return true;
            }
            return false;
        },
        .ternary_expr => |t| return isRecursive(t.condition, func_name) or isRecursive(t.true_expr, func_name) or isRecursive(t.false_expr, func_name),
    }
}

pub fn collectClassFields(allocator: std.mem.Allocator, node: *ast.Node, fields: *std.StringHashMap(bool)) !void {
    switch (node.*) {
        .setattr => |s| {
            if (s.target.* == .identifier and std.mem.eql(u8, s.target.identifier.name, "self")) {
                try fields.put(s.attr, true);
            }
            try collectClassFields(allocator, s.target, fields);
            try collectClassFields(allocator, s.value, fields);
        },
        .def_stmt => |d| {
            for (d.body.items) |stmt| {
                try collectClassFields(allocator, stmt, fields);
            }
        },
        .class_stmt => |c| {
            for (c.methods.items) |stmt| {
                try collectClassFields(allocator, stmt, fields);
            }
        },
        .if_stmt => |ifs| {
            try collectClassFields(allocator, ifs.condition, fields);
            for (ifs.then_branch.items) |stmt| try collectClassFields(allocator, stmt, fields);
            for (ifs.elifs.items) |elif| {
                try collectClassFields(allocator, elif.condition, fields);
                for (elif.then_branch.items) |stmt| try collectClassFields(allocator, stmt, fields);
            }
            if (ifs.else_branch) |eb| {
                for (eb.items) |stmt| try collectClassFields(allocator, stmt, fields);
            }
        },
        .while_stmt => |w| {
            try collectClassFields(allocator, w.condition, fields);
            for (w.body.items) |stmt| try collectClassFields(allocator, stmt, fields);
        },
        .match_stmt => |m| {
            try collectClassFields(allocator, m.subject, fields);
            for (m.cases.items) |case_branch| {
                try collectClassFields(allocator, case_branch.pattern, fields);
                for (case_branch.body.items) |stmt| try collectClassFields(allocator, stmt, fields);
            }
        },
        .with_stmt => |w| {
            try collectClassFields(allocator, w.context_expr, fields);
            for (w.body.items) |stmt| try collectClassFields(allocator, stmt, fields);
        },
        .for_stmt => |f| {
            try collectClassFields(allocator, f.iterable, fields);
            for (f.body.items) |stmt| try collectClassFields(allocator, stmt, fields);
        },
        .try_stmt => |t| {
            for (t.body.items) |stmt| try collectClassFields(allocator, stmt, fields);
            if (t.except_branch) |eb| {
                for (eb.items) |stmt| try collectClassFields(allocator, stmt, fields);
            }
            if (t.finally_branch) |fb| {
                for (fb.items) |stmt| try collectClassFields(allocator, stmt, fields);
            }
        },
        .call => |c| {
            try collectClassFields(allocator, c.callee, fields);
            for (c.args.items) |arg| try collectClassFields(allocator, arg, fields);
        },
        .method_call => |m| {
            try collectClassFields(allocator, m.target, fields);
            for (m.args.items) |arg| try collectClassFields(allocator, arg, fields);
        },
        .getattr => |g| try collectClassFields(allocator, g.target, fields),
        .subscript => |s| {
            try collectClassFields(allocator, s.target, fields);
            try collectClassFields(allocator, s.index, fields);
        },
        .subscript_assign => |s| {
            try collectClassFields(allocator, s.target, fields);
            try collectClassFields(allocator, s.index, fields);
            try collectClassFields(allocator, s.value, fields);
        },
        .slice => |s| {
            try collectClassFields(allocator, s.target, fields);
            if (s.start) |n| try collectClassFields(allocator, n, fields);
            if (s.stop) |n| try collectClassFields(allocator, n, fields);
            if (s.step) |n| try collectClassFields(allocator, n, fields);
        },
        .slice_assign => |s| {
            try collectClassFields(allocator, s.target, fields);
            if (s.start) |n| try collectClassFields(allocator, n, fields);
            if (s.stop) |n| try collectClassFields(allocator, n, fields);
            if (s.step) |n| try collectClassFields(allocator, n, fields);
            try collectClassFields(allocator, s.value, fields);
        },
        .assign => |a| try collectClassFields(allocator, a.value, fields),
        .const_assign => |c| try collectClassFields(allocator, c.value, fields),
        .return_stmt => |r| {
            if (r.value) |v| try collectClassFields(allocator, v, fields);
        },
        .raise_stmt => |r| {
            if (r.value) |v| try collectClassFields(allocator, v, fields);
        },
        .unary => |u| try collectClassFields(allocator, u.right, fields),
        .binary => |b| {
            try collectClassFields(allocator, b.left, fields);
            try collectClassFields(allocator, b.right, fields);
        },
        .ternary_expr => |t| {
            try collectClassFields(allocator, t.condition, fields);
            try collectClassFields(allocator, t.true_expr, fields);
            try collectClassFields(allocator, t.false_expr, fields);
        },
        .list_expr => |l| {
            for (l.items.items) |item| try collectClassFields(allocator, item, fields);
        },
        .list_comp => |l| {
            try collectClassFields(allocator, l.expression, fields);
            try collectClassFields(allocator, l.iterable, fields);
            if (l.condition) |cond| try collectClassFields(allocator, cond, fields);
        },
        .dict_expr => |d| {
            for (d.keys.items) |key| try collectClassFields(allocator, key, fields);
            for (d.values.items) |val| try collectClassFields(allocator, val, fields);
        },
        else => {},
    }
}
