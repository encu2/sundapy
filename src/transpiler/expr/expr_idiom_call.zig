const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn tryLowerCallIdiom(self: *Transpiler, c: anytype) anyerror!bool {
    if (c.callee.* != .identifier) return false;
    const name = c.callee.identifier.name;

    if (std.mem.eql(u8, name, "sum")) {
        return tryLowerSum(self, c);
    } else if (std.mem.eql(u8, name, "any")) {
        return tryLowerAny(self, c);
    } else if (std.mem.eql(u8, name, "all")) {
        return tryLowerAll(self, c);
    } else if (std.mem.eql(u8, name, "max") or std.mem.eql(u8, name, "min")) {
        return tryLowerClamp(self, c, name);
    }

    return false;
}

fn tryLowerSum(self: *Transpiler, c: anytype) anyerror!bool {
    if (c.args.items.len < 1 or c.args.items.len > 2) return false;
    if (c.args.items[0].* != .list_comp) return false;
    const comp = c.args.items[0].list_comp;
    if (comp.is_async) return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    const target_alias = try std.fmt.allocPrint(self.allocator, "_{s}_{d}", .{ comp.target, lid });
    defer self.allocator.free(target_alias);

    const prev_alias = self.scoped_aliases.get(comp.target);
    try self.scoped_aliases.put(comp.target, target_alias);
    defer {
        if (prev_alias) |prev| {
            self.scoped_aliases.put(comp.target, prev) catch {};
        } else {
            _ = self.scoped_aliases.remove(comp.target);
        }
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    if (c.args.items.len == 2) {
        try self.emit("    var _sum_{d} = dynamic.Dynamic.fromAny(", .{lid});
        try self.transpileExpr(c.args.items[1]);
        try self.emit(");\n", .{});
    } else {
        try self.emit("    var _sum_{d} = dynamic.Dynamic.initInt(0);\n", .{lid});
    }

    try self.emit("    var _iter_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(comp.iterable);
    try self.emit(");\n", .{});

    try self.emit("    var _idx_{d}: usize = 0;\n", .{lid});
    try self.emit("    while (_idx_{d} < _iter_{d}.len()) : (_idx_{d} += 1) {{\n", .{ lid, lid, lid });
    try self.emit("        var {s} = _iter_{d}.getItem(_idx_{d});\n", .{ target_alias, lid, lid });
    try self.emit("        _ = &{s};\n", .{target_alias});

    if (comp.condition) |cond| {
        try self.emit("        if ((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(cond);
        try self.emit(")).toBool()) {{\n", .{});
        try self.emit("            _sum_{d} = _sum_{d}.add(dynamic.Dynamic.fromAny(", .{ lid, lid });
        try self.transpileExpr(comp.expression);
        try self.emit("));\n", .{});
        try self.emit("        }}\n", .{});
    } else {
        try self.emit("        _sum_{d} = _sum_{d}.add(dynamic.Dynamic.fromAny(", .{ lid, lid });
        try self.transpileExpr(comp.expression);
        try self.emit("));\n", .{});
    }

    try self.emit("    }}\n", .{});
    try self.emit("    break :blk_{d} _sum_{d};\n", .{ lid, lid });
    try self.emit("}})", .{});

    return true;
}

fn tryLowerAny(self: *Transpiler, c: anytype) anyerror!bool {
    if (c.args.items.len != 1) return false;
    if (c.args.items[0].* != .list_comp) return false;
    const comp = c.args.items[0].list_comp;
    if (comp.is_async) return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    const target_alias = try std.fmt.allocPrint(self.allocator, "_{s}_{d}", .{ comp.target, lid });
    defer self.allocator.free(target_alias);

    const prev_alias = self.scoped_aliases.get(comp.target);
    try self.scoped_aliases.put(comp.target, target_alias);
    defer {
        if (prev_alias) |prev| {
            self.scoped_aliases.put(comp.target, prev) catch {};
        } else {
            _ = self.scoped_aliases.remove(comp.target);
        }
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    var _res_{d} = false;\n", .{lid});
    try self.emit("    var _iter_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(comp.iterable);
    try self.emit(");\n", .{});

    try self.emit("    var _idx_{d}: usize = 0;\n", .{lid});
    try self.emit("    while (_idx_{d} < _iter_{d}.len()) : (_idx_{d} += 1) {{\n", .{ lid, lid, lid });
    try self.emit("        var {s} = _iter_{d}.getItem(_idx_{d});\n", .{ target_alias, lid, lid });
    try self.emit("        _ = &{s};\n", .{target_alias});

    if (comp.condition) |cond| {
        try self.emit("        if ((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(cond);
        try self.emit(")).toBool()) {{\n", .{});
        try self.emit("            if ((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(comp.expression);
        try self.emit(")).toBool()) {{ _res_{d} = true; break; }}\n", .{lid});
        try self.emit("        }}\n", .{});
    } else {
        try self.emit("        if ((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(comp.expression);
        try self.emit(")).toBool()) {{ _res_{d} = true; break; }}\n", .{lid});
    }

    try self.emit("    }}\n", .{});
    try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(_res_{d});\n", .{ lid, lid });
    try self.emit("}})", .{});

    return true;
}

fn tryLowerAll(self: *Transpiler, c: anytype) anyerror!bool {
    if (c.args.items.len != 1) return false;
    if (c.args.items[0].* != .list_comp) return false;
    const comp = c.args.items[0].list_comp;
    if (comp.is_async) return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    const target_alias = try std.fmt.allocPrint(self.allocator, "_{s}_{d}", .{ comp.target, lid });
    defer self.allocator.free(target_alias);

    const prev_alias = self.scoped_aliases.get(comp.target);
    try self.scoped_aliases.put(comp.target, target_alias);
    defer {
        if (prev_alias) |prev| {
            self.scoped_aliases.put(comp.target, prev) catch {};
        } else {
            _ = self.scoped_aliases.remove(comp.target);
        }
    }

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    var _res_{d} = true;\n", .{lid});
    try self.emit("    var _iter_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(comp.iterable);
    try self.emit(");\n", .{});

    try self.emit("    var _idx_{d}: usize = 0;\n", .{lid});
    try self.emit("    while (_idx_{d} < _iter_{d}.len()) : (_idx_{d} += 1) {{\n", .{ lid, lid, lid });
    try self.emit("        var {s} = _iter_{d}.getItem(_idx_{d});\n", .{ target_alias, lid, lid });
    try self.emit("        _ = &{s};\n", .{target_alias});

    if (comp.condition) |cond| {
        try self.emit("        if ((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(cond);
        try self.emit(")).toBool()) {{\n", .{});
        try self.emit("            if (!((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(comp.expression);
        try self.emit(")).toBool())) {{ _res_{d} = false; break; }}\n", .{lid});
        try self.emit("        }}\n", .{});
    } else {
        try self.emit("        if (!((dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(comp.expression);
        try self.emit(")).toBool())) {{ _res_{d} = false; break; }}\n", .{lid});
    }

    try self.emit("    }}\n", .{});
    try self.emit("    break :blk_{d} dynamic.Dynamic.initBool(_res_{d});\n", .{ lid, lid });
    try self.emit("}})", .{});

    return true;
}

fn tryLowerClamp(self: *Transpiler, c: anytype, name: []const u8) anyerror!bool {
    if (c.args.items.len != 2) return false;

    var lo_node: ?*ast.Node = null;
    var hi_node: ?*ast.Node = null;
    var val_node: ?*ast.Node = null;

    if (std.mem.eql(u8, name, "max")) {
        // max(lo, min(hi, val)) or max(min(hi, val), lo)
        if (isCallNamed(c.args.items[1], "min") and c.args.items[1].call.args.items.len == 2) {
            lo_node = c.args.items[0];
            const pair = pickValAndBound(c.args.items[1].call.args.items[0], c.args.items[1].call.args.items[1]);
            hi_node = pair.bound;
            val_node = pair.val;
        } else if (isCallNamed(c.args.items[0], "min") and c.args.items[0].call.args.items.len == 2) {
            lo_node = c.args.items[1];
            const pair = pickValAndBound(c.args.items[0].call.args.items[0], c.args.items[0].call.args.items[1]);
            hi_node = pair.bound;
            val_node = pair.val;
        }
    } else if (std.mem.eql(u8, name, "min")) {
        // min(hi, max(lo, val)) or min(max(lo, val), hi)
        if (isCallNamed(c.args.items[1], "max") and c.args.items[1].call.args.items.len == 2) {
            hi_node = c.args.items[0];
            const pair = pickValAndBound(c.args.items[1].call.args.items[0], c.args.items[1].call.args.items[1]);
            lo_node = pair.bound;
            val_node = pair.val;
        } else if (isCallNamed(c.args.items[0], "max") and c.args.items[0].call.args.items.len == 2) {
            hi_node = c.args.items[1];
            const pair = pickValAndBound(c.args.items[0].call.args.items[0], c.args.items[0].call.args.items[1]);
            lo_node = pair.bound;
            val_node = pair.val;
        }
    }

    const lo = lo_node orelse return false;
    const hi = hi_node orelse return false;
    const val = val_node orelse return false;

    self.label_counter += 1;
    const lid = self.label_counter;

    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _val_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(val);
    try self.emit(");\n", .{});

    try self.emit("    const _lo_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(lo);
    try self.emit(");\n", .{});

    try self.emit("    const _hi_{d} = dynamic.Dynamic.fromAny(", .{lid});
    try self.transpileExpr(hi);
    try self.emit(");\n", .{});

    try self.emit("    break :blk_{d} if (_val_{d}.lt(_lo_{d}).toBool()) _lo_{d} else if (_val_{d}.gt(_hi_{d}).toBool()) _hi_{d} else _val_{d};\n", .{ lid, lid, lid, lid, lid, lid, lid, lid });
    try self.emit("}})", .{});

    return true;
}

fn pickValAndBound(a: *ast.Node, b: *ast.Node) struct { val: *ast.Node, bound: *ast.Node } {
    const a_is_lit = (a.* == .number or a.* == .integer or a.* == .float);
    const b_is_lit = (b.* == .number or b.* == .integer or b.* == .float);
    if (a_is_lit and !b_is_lit) {
        return .{ .val = b, .bound = a };
    } else if (b_is_lit and !a_is_lit) {
        return .{ .val = a, .bound = b };
    }
    if (a.* == .identifier) {
        const n = a.identifier.name;
        if (std.mem.indexOf(u8, n, "max") != null or std.mem.indexOf(u8, n, "hi") != null or std.mem.indexOf(u8, n, "limit") != null or std.mem.indexOf(u8, n, "bound") != null or std.mem.indexOf(u8, n, "min") != null) {
            return .{ .val = b, .bound = a };
        }
    }
    return .{ .val = a, .bound = b };
}

fn isCallNamed(node: *ast.Node, expected_name: []const u8) bool {
    if (node.* != .call) return false;
    if (node.call.callee.* != .identifier) return false;
    return std.mem.eql(u8, node.call.callee.identifier.name, expected_name);
}
