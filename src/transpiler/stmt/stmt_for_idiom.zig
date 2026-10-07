const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn tryLowerForStmt(
    self: *Transpiler,
    f: anytype,
    declared_vars: *std.StringHashMap(bool),
    strict_funcs: *std.StringHashMap(bool),
) anyerror!bool {
    if (f.iterable.* != .call) return false;
    const call_node = f.iterable.call;
    if (call_node.callee.* != .identifier) return false;
    const callee_name = call_node.callee.identifier.name;

    if (std.mem.eql(u8, callee_name, "enumerate")) {
        return tryLowerEnumerate(self, f, call_node, declared_vars, strict_funcs);
    } else if (std.mem.eql(u8, callee_name, "zip")) {
        return tryLowerZip(self, f, call_node, declared_vars, strict_funcs);
    }

    return false;
}

fn tryLowerEnumerate(
    self: *Transpiler,
    f: anytype,
    call_node: anytype,
    declared_vars: *std.StringHashMap(bool),
    strict_funcs: *std.StringHashMap(bool),
) anyerror!bool {
    if (call_node.args.items.len < 1 or call_node.args.items.len > 2) return false;

    const iter_str = std.mem.trim(u8, f.iterator, " ");
    var comma_idx: ?usize = null;
    for (iter_str, 0..) |c, idx| {
        if (c == ',') {
            comma_idx = idx;
            break;
        }
    }
    const idx_pos = comma_idx orelse return false;
    const target_idx_raw = std.mem.trim(u8, iter_str[0..idx_pos], " ");
    const target_item_raw = std.mem.trim(u8, iter_str[idx_pos + 1 ..], " ");
    if (target_idx_raw.len == 0 or target_item_raw.len == 0) return false;

    const target_idx = try self.escapeKeyword(target_idx_raw);
    defer self.allocator.free(target_idx);
    const target_item = try self.escapeKeyword(target_item_raw);
    defer self.allocator.free(target_item);

    try self.emit("{{\n", .{});
    self.indent_level += 1;

    try self.emitIndent();
    try self.emit("var iter_obj_{d} = ", .{self.indent_level});
    try self.transpileExpr(call_node.args.items[0]);
    try self.emit(";\n", .{});

    try self.emitIndent();
    try self.emit("var iter_idx_{d}: usize = 0;\n", .{self.indent_level});

    try self.emitIndent();
    if (call_node.args.items.len == 2) {
        try self.emit("const _start_{d}: i64 = blk_st: {{\n", .{self.indent_level});
        try self.emit("    const _st = dynamic.Dynamic.fromAny(", .{});
        try self.transpileExpr(call_node.args.items[1]);
        try self.emit(");\n", .{});
        try self.emit("    break :blk_st if (_st.value == .i64_type) _st.value.i64_type else 0;\n", .{});
        try self.emit("}};\n", .{});
    } else {
        try self.emit("const _start_{d}: i64 = 0;\n", .{self.indent_level});
    }

    try self.escape_analyzer.variables.put(target_idx, .{
        .name = target_idx,
        .class = .stack,
        .is_primitive = false,
    });
    try self.escape_analyzer.variables.put(target_item, .{
        .name = target_item,
        .class = .stack,
        .is_primitive = false,
    });

    try self.emitIndent();
    try self.emit("var {s} = dynamic.Dynamic{{ .value = .{{ .i64_type = _start_{d} }} }};\n", .{ target_idx, self.indent_level });
    try self.emitIndent();
    try self.emit("_ = &{s};\n", .{target_idx});

    try self.emitIndent();
    try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{target_item});
    try self.emitIndent();
    try self.emit("_ = &{s};\n", .{target_item});

    try self.emitIndent();
    try self.emit("while (iter_idx_{d} < iter_obj_{d}.len()) : (iter_idx_{d} += 1) {{\n", .{ self.indent_level, self.indent_level, self.indent_level });
    self.indent_level += 1;

    try self.emitIndent();
    try self.emit("{s} = dynamic.Dynamic{{ .value = .{{ .i64_type = _start_{d} + @as(i64, @intCast(iter_idx_{d})) }} }};\n", .{ target_idx, self.indent_level - 1, self.indent_level - 1 });
    try self.emitIndent();
    try self.emit("{s} = iter_obj_{d}.getItem(iter_idx_{d});\n", .{ target_item, self.indent_level - 1, self.indent_level - 1 });

    for (f.body.items) |stmt| {
        try self.transpileStmt(stmt, declared_vars, strict_funcs);
    }

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});

    return true;
}

fn tryLowerZip(
    self: *Transpiler,
    f: anytype,
    call_node: anytype,
    declared_vars: *std.StringHashMap(bool),
    strict_funcs: *std.StringHashMap(bool),
) anyerror!bool {
    const num_args = call_node.args.items.len;
    if (num_args < 2) return false;

    var target_list: std.ArrayList([]const u8) = .empty;
    defer target_list.deinit(self.allocator);

    const iter_str = std.mem.trim(u8, f.iterator, " ");
    var split = std.mem.splitSequence(u8, iter_str, ",");
    while (split.next()) |item| {
        const trimmed = std.mem.trim(u8, item, " ");
        if (trimmed.len > 0) {
            try target_list.append(self.allocator, trimmed);
        }
    }
    if (target_list.items.len != num_args) return false;

    try self.emit("{{\n", .{});
    self.indent_level += 1;

    for (call_node.args.items, 0..) |arg, idx| {
        try self.emitIndent();
        try self.emit("var _zip_{d}_{d} = ", .{ idx, self.indent_level });
        try self.transpileExpr(arg);
        try self.emit(";\n", .{});
    }

    try self.emitIndent();
    try self.emit("const _min_len_{d}: usize = ", .{self.indent_level});
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        if (i > 0) try self.emit(", ", .{});
        if (i == 0 and num_args > 1) try self.emit("@min(", .{});
        try self.emit("_zip_{d}_{d}.len()", .{ i, self.indent_level });
    }
    if (num_args > 1) try self.emit(")", .{});
    try self.emit(";\n", .{});

    try self.emitIndent();
    try self.emit("var iter_idx_{d}: usize = 0;\n", .{self.indent_level});

    for (target_list.items) |t_raw| {
        try self.escape_analyzer.variables.put(t_raw, .{
            .name = t_raw,
            .class = .stack,
            .is_primitive = false,
        });
        const t_escaped = try self.escapeKeyword(t_raw);
        defer self.allocator.free(t_escaped);
        try self.emitIndent();
        try self.emit("var {s} = dynamic.Dynamic.initNone();\n", .{t_escaped});
        try self.emitIndent();
        try self.emit("_ = &{s};\n", .{t_escaped});
    }

    try self.emitIndent();
    try self.emit("while (iter_idx_{d} < _min_len_{d}) : (iter_idx_{d} += 1) {{\n", .{ self.indent_level, self.indent_level, self.indent_level });
    self.indent_level += 1;

    for (target_list.items, 0..) |t_raw, idx| {
        const t_escaped = try self.escapeKeyword(t_raw);
        defer self.allocator.free(t_escaped);
        try self.emitIndent();
        try self.emit("{s} = _zip_{d}_{d}.getItem(iter_idx_{d});\n", .{ t_escaped, idx, self.indent_level - 1, self.indent_level - 1 });
    }

    for (f.body.items) |stmt| {
        try self.transpileStmt(stmt, declared_vars, strict_funcs);
    }

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});

    self.indent_level -= 1;
    try self.emitIndent();
    try self.emit("}}\n", .{});

    return true;
}
