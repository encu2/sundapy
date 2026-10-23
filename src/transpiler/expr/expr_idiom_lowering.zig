const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub const MultidimInfo = struct {
    dims: std.ArrayList(*ast.Node),
    leaf: *ast.Node,
    is_distinct_rows: bool,
};

fn isZeroLiteral(node: *ast.Node) bool {
    switch (node.*) {
        .number => |n| return n == 0.0,
        .integer => |i| return std.mem.eql(u8, i, "0"),
        .float => |f| return std.mem.eql(u8, f, "0") or std.mem.eql(u8, f, "0.0"),
        else => return false,
    }
}

fn containsAnyTarget(node: *ast.Node, targets: []const []const u8) bool {
    switch (node.*) {
        .identifier => |id| {
            for (targets) |t| {
                if (std.mem.eql(u8, id.name, t)) return true;
            }
            return false;
        },
        .binary => |b| return containsAnyTarget(b.left, targets) or containsAnyTarget(b.right, targets),
        .unary => |u| return containsAnyTarget(u.right, targets),
        .call => |c| {
            if (containsAnyTarget(c.callee, targets)) return true;
            for (c.args.items) |arg| {
                if (containsAnyTarget(arg, targets)) return true;
            }
            for (c.kwargs.items) |kw| {
                if (containsAnyTarget(kw.value, targets)) return true;
            }
            return false;
        },
        .method_call => |m| {
            if (containsAnyTarget(m.target, targets)) return true;
            for (m.args.items) |arg| {
                if (containsAnyTarget(arg, targets)) return true;
            }
            for (m.kwargs.items) |kw| {
                if (containsAnyTarget(kw.value, targets)) return true;
            }
            return false;
        },
        .subscript => |s| return containsAnyTarget(s.target, targets) or containsAnyTarget(s.index, targets),
        .getattr => |g| return containsAnyTarget(g.target, targets),
        .list_expr, .tuple_expr => |l| {
            for (l.items.items) |item| {
                if (containsAnyTarget(item, targets)) return true;
            }
            return false;
        },
        .ternary_expr => |t| return containsAnyTarget(t.condition, targets) or containsAnyTarget(t.true_expr, targets) or containsAnyTarget(t.false_expr, targets),
        else => return false,
    }
}

pub fn extractMultidimPattern(allocator: std.mem.Allocator, node: *ast.Node) !?MultidimInfo {
    var dims: std.ArrayList(*ast.Node) = .empty;
    errdefer dims.deinit(allocator);

    var targets: std.ArrayList([]const u8) = .empty;
    defer targets.deinit(allocator);

    var curr = node;
    var is_distinct = false;

    while (true) {
        if (curr.* == .list_comp) {
            if (curr.list_comp.clauses.items.len != 1) {
                dims.deinit(allocator);
                return null;
            }
            const cl = curr.list_comp.clauses.items[0];
            if (cl.condition != null or cl.is_async) {
                dims.deinit(allocator);
                return null;
            }
            const iter = cl.iterable;
            if (iter.* == .call and iter.call.callee.* == .identifier and std.mem.eql(u8, iter.call.callee.identifier.name, "range")) {
                if (iter.call.args.items.len == 1) {
                    try dims.append(allocator, iter.call.args.items[0]);
                    try targets.append(allocator, cl.target);
                    is_distinct = true;
                    curr = curr.list_comp.expression;
                    continue;
                } else if (iter.call.args.items.len == 2) {
                    if (isZeroLiteral(iter.call.args.items[0])) {
                        try dims.append(allocator, iter.call.args.items[1]);
                        try targets.append(allocator, cl.target);
                        is_distinct = true;
                        curr = curr.list_comp.expression;
                        continue;
                    } else {
                        dims.deinit(allocator);
                        return null;
                    }
                } else {
                    dims.deinit(allocator);
                    return null;
                }
            } else {
                dims.deinit(allocator);
                return null;
            }
        } else if (curr.* == .binary and std.mem.eql(u8, curr.binary.op, "*")) {
            if (curr.binary.left.* == .list_expr and curr.binary.left.list_expr.items.items.len == 1) {
                try dims.append(allocator, curr.binary.right);
                curr = curr.binary.left.list_expr.items.items[0];
                continue;
            } else if (curr.binary.right.* == .list_expr and curr.binary.right.list_expr.items.items.len == 1) {
                try dims.append(allocator, curr.binary.left);
                curr = curr.binary.right.list_expr.items.items[0];
                continue;
            } else {
                break;
            }
        } else {
            break;
        }
    }

    if (dims.items.len == 0) {
        dims.deinit(allocator);
        return null;
    }

    if (containsAnyTarget(curr, targets.items)) {
        dims.deinit(allocator);
        return null;
    }

    return MultidimInfo{
        .dims = dims,
        .leaf = curr,
        .is_distinct_rows = is_distinct,
    };
}

fn emitSpaces(self: *Transpiler, count: usize) anyerror!void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        try self.emit(" ", .{});
    }
}

pub fn tryLowerMultidimList(self: *Transpiler, node: *ast.Node) anyerror!bool {
    var info = (try extractMultidimPattern(self.allocator, node)) orelse return false;
    defer info.dims.deinit(self.allocator);

    const k = info.dims.items.len;
    if (k == 0) return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("Dynamic{{ .value = .{{ .list_type = .{{ .items = blk_{d}: {{\n", .{lid});

    for (info.dims.items, 0..) |dim_node, idx| {
        try self.emit("    const _dim_{d}_{d}: usize = blk_dim_{d}_{d}: {{\n", .{ idx, lid, idx, lid });
        try self.emit("        const _d = dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(dim_node);
        try self.emit(");\n", .{});
        try self.emit("        break :blk_dim_{d}_{d} if (_d.value == .i64_type) @as(usize, @intCast(@max(0, _d.value.i64_type))) else 0;\n", .{ idx, lid });
        try self.emit("    }};\n", .{});
    }

    try self.emit("    const _leaf_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(info.leaf);
    try self.emit(");\n", .{});

    if (k == 1) {
        try self.emit("    const _row_{d} = alloc.alloc(Dynamic, _dim_0_{d}) catch unreachable;\n", .{ lid, lid });
        try self.emit("    @memset(_row_{d}, _leaf_{d});\n", .{ lid, lid });
        try self.emit("    break :blk_{d} std.ArrayList(Dynamic).fromOwnedSlice(_row_{d});\n", .{ lid, lid });
        try self.emit("}} }} }} }}", .{});
        return true;
    }

    try self.emit("    var _l_0_{d}: std.ArrayList(Dynamic) = .empty;\n", .{lid});
    try self.emit("    _l_0_{d}.ensureTotalCapacity(alloc, _dim_0_{d}) catch unreachable;\n", .{ lid, lid });
    try self.emit("    var _i_0_{d}: usize = 0;\n", .{lid});
    try self.emit("    while (_i_0_{d} < _dim_0_{d}) : (_i_0_{d} += 1) {{\n", .{ lid, lid, lid });

    var p: usize = 1;
    while (p < k - 1) : (p += 1) {
        try emitSpaces(self, (p + 1) * 4);
        try self.emit("var _l_{d}_{d}: std.ArrayList(Dynamic) = .empty;\n", .{ p, lid });
        try emitSpaces(self, (p + 1) * 4);
        try self.emit("_l_{d}_{d}.ensureTotalCapacity(alloc, _dim_{d}_{d}) catch unreachable;\n", .{ p, lid, p, lid });
        try emitSpaces(self, (p + 1) * 4);
        try self.emit("var _i_{d}_{d}: usize = 0;\n", .{ p, lid });
        try emitSpaces(self, (p + 1) * 4);
        try self.emit("while (_i_{d}_{d} < _dim_{d}_{d}) : (_i_{d}_{d} += 1) {{\n", .{ p, lid, p, lid, p, lid });
    }

    try emitSpaces(self, k * 4);
    try self.emit("const _row_{d} = alloc.alloc(Dynamic, _dim_{d}_{d}) catch unreachable;\n", .{ lid, k - 1, lid });
    try emitSpaces(self, k * 4);
    try self.emit("@memset(_row_{d}, _leaf_{d});\n", .{ lid, lid });
    try emitSpaces(self, k * 4);
    try self.emit("_l_{d}_{d}.appendAssumeCapacity(Dynamic{{ .value = .{{ .list_type = .{{ .items = std.ArrayList(Dynamic).fromOwnedSlice(_row_{d}) }} }} }});\n", .{ k - 2, lid, lid });

    var down_p: usize = k - 2;
    while (down_p >= 1) : (down_p -= 1) {
        try emitSpaces(self, (down_p + 1) * 4);
        try self.emit("}}\n", .{});
        try emitSpaces(self, (down_p + 1) * 4);
        try self.emit("_l_{d}_{d}.appendAssumeCapacity(Dynamic{{ .value = .{{ .list_type = .{{ .items = _l_{d}_{d} }} }} }});\n", .{ down_p - 1, lid, down_p, lid });
    }

    try self.emit("    }}\n", .{});
    try self.emit("    break :blk_{d} _l_0_{d};\n", .{ lid, lid });
    try self.emit("}} }} }} }}", .{});

    return true;
}

pub fn tryLowerMultidimListStrict(self: *Transpiler, node: *ast.Node) anyerror!bool {
    var info = (try extractMultidimPattern(self.allocator, node)) orelse return false;
    defer info.dims.deinit(self.allocator);

    const k = info.dims.items.len;
    if (k == 0) return false;

    var all_comptime = true;
    for (info.dims.items) |dim_node| {
        switch (dim_node.*) {
            .number, .integer => {},
            else => {
                all_comptime = false;
                break;
            },
        }
    }

    self.label_counter += 1;
    const lid = self.label_counter;

    if (all_comptime and isZeroLiteral(info.leaf)) {
        try self.emit("(std.mem.zeroes(", .{});
        for (info.dims.items) |dim_node| {
            try self.emit("[", .{});
            try self.transpileExprStrict(dim_node);
            try self.emit("]", .{});
        }
        if (info.leaf.* == .float or info.leaf.* == .number) {
            try self.emit("f64", .{});
        } else {
            try self.emit("i64", .{});
        }
        try self.emit("))", .{});
        return true;
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    for (info.dims.items, 0..) |dim_node, idx| {
        try self.emit("    const _dim_{d}_{d}: usize = @as(usize, @intCast(", .{ idx, lid });
        try self.transpileExprStrict(dim_node);
        try self.emit("));\n", .{});
    }
    try self.emit("    const _leaf_{d} = ", .{lid});
    try self.transpileExprStrict(info.leaf);
    try self.emit(";\n", .{});

    if (k == 1) {
        try self.emit("    const _row_{d} = alloc.alloc(@TypeOf(_leaf_{d}), _dim_0_{d}) catch unreachable;\n", .{ lid, lid, lid });
        try self.emit("    @memset(_row_{d}, _leaf_{d});\n", .{ lid, lid });
        try self.emit("    break :blk_{d} _row_{d};\n", .{ lid, lid });
        try self.emit("}})", .{});
        return true;
    }

    try self.emit("    const _total_{d} = ", .{lid});
    for (info.dims.items, 0..) |_, idx| {
        if (idx > 0) try self.emit(" * ", .{});
        try self.emit("_dim_{d}_{d}", .{ idx, lid });
    }
    try self.emit(";\n", .{});
    try self.emit("    const _buf_{d} = alloc.alloc(@TypeOf(_leaf_{d}), _total_{d}) catch unreachable;\n", .{ lid, lid, lid });
    try self.emit("    @memset(_buf_{d}, _leaf_{d});\n", .{ lid, lid });
    try self.emit("    break :blk_{d} _buf_{d};\n", .{ lid, lid });
    try self.emit("}})", .{});
    return true;
}
