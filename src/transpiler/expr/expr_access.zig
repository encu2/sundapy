const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileGetattr(self: *Transpiler, g: anytype) anyerror!void {
    if (g.target.* == .identifier) {
        const id = g.target.identifier.name;
        var is_mod = false;
        for (self.imported_modules.items) |mod| {
            if (std.mem.eql(u8, id, mod)) { is_mod = true; break; }
        }
        if (!is_mod and self.module_aliases.get(id) != null) is_mod = true;
        if (is_mod) {
            const esc_id = try self.escapeKeyword(id);
            defer self.allocator.free(esc_id);
            if (self.is_strict) {
                try self.emit("{s}.{s}", .{esc_id, g.attr});
            } else {
                try self.emit("(if (comptime @TypeOf({s}.{s}) == type) {s}.{s} else Dynamic.fromAny({s}.{s}))", .{esc_id, g.attr, esc_id, g.attr, esc_id, g.attr});
            }
            return;
        }
    }

    self.label_counter += 1;
    const lid = self.label_counter;
    try self.emit("((blk_{d}: {{\n", .{lid});
    try self.emit("    const _target_{d} = ", .{lid});
    try self.transpileExpr(g.target);
    try self.emit(";\n", .{});
    try self.emit("    const T_{d} = @TypeOf(_target_{d});\n", .{ lid, lid });
    try self.emit("    const info_{d} = @typeInfo(T_{d});\n", .{ lid, lid });
    try self.emit("    if (T_{d} == Dynamic) {{\n", .{lid});
    try self.emit("        break :blk_{d} _target_{d}.builtin_getattr(\"{s}\");\n", .{ lid, lid, g.attr });
    try self.emit("    }} else if (info_{d} == .pointer and @typeInfo(info_{d}.pointer.child) == .@\"struct\") {{\n", .{ lid, lid });
    try self.emit("        if (@hasField(info_{d}.pointer.child, \"{s}\")) {{\n", .{ lid, g.attr });
    try self.emit("            const _f = _target_{d}.{s};\n", .{ lid, g.attr });
    try self.emit("            const F = @TypeOf(_f);\n", .{});
    try self.emit("            if (F == Dynamic) break :blk_{d} _f;\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .int or F == comptime_int) break :blk_{d} Dynamic{{ .value = .{{ .i64_type = @intCast(_f) }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .float or F == comptime_float) break :blk_{d} Dynamic{{ .value = .{{ .float_type = @floatCast(_f) }} }};\n", .{lid});
    try self.emit("            if (F == bool) break :blk_{d} Dynamic{{ .value = .{{ .bool_type = _f }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .pointer) break :blk_{d} Dynamic{{ .value = .{{ .str_type = _f }} }};\n", .{lid});
    try self.emit("            break :blk_{d} Dynamic.fromAny(_f);\n", .{lid});
    try self.emit("        }}\n", .{});
    try self.emit("    }} else if (info_{d} == .@\"struct\") {{\n", .{lid});
    try self.emit("        if (@hasField(T_{d}, \"{s}\")) {{\n", .{ lid, g.attr });
    try self.emit("            const _f = _target_{d}.{s};\n", .{ lid, g.attr });
    try self.emit("            const F = @TypeOf(_f);\n", .{});
    try self.emit("            if (F == Dynamic) break :blk_{d} _f;\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .int or F == comptime_int) break :blk_{d} Dynamic{{ .value = .{{ .i64_type = @intCast(_f) }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .float or F == comptime_float) break :blk_{d} Dynamic{{ .value = .{{ .float_type = @floatCast(_f) }} }};\n", .{lid});
    try self.emit("            if (F == bool) break :blk_{d} Dynamic{{ .value = .{{ .bool_type = _f }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(F) == .pointer) break :blk_{d} Dynamic{{ .value = .{{ .str_type = _f }} }};\n", .{lid});
    try self.emit("            break :blk_{d} Dynamic.fromAny(_f);\n", .{lid});
    try self.emit("        }}\n", .{});
    try self.emit("    }} else if (T_{d} == type) {{\n", .{lid});
    try self.emit("        if (@hasDecl(_target_{d}, \"{s}\")) {{\n", .{ lid, g.attr });
    try self.emit("            const _d = @field(_target_{d}, \"{s}\");\n", .{ lid, g.attr });
    try self.emit("            const D = @TypeOf(_d);\n", .{});
    try self.emit("            if (D == Dynamic) break :blk_{d} _d;\n", .{lid});
    try self.emit("            if (@typeInfo(D) == .int or D == comptime_int) break :blk_{d} Dynamic{{ .value = .{{ .i64_type = @intCast(_d) }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(D) == .float or D == comptime_float) break :blk_{d} Dynamic{{ .value = .{{ .float_type = @floatCast(_d) }} }};\n", .{lid});
    try self.emit("            if (D == bool) break :blk_{d} Dynamic{{ .value = .{{ .bool_type = _d }} }};\n", .{lid});
    try self.emit("            if (@typeInfo(D) == .pointer) break :blk_{d} Dynamic{{ .value = .{{ .str_type = _d }} }};\n", .{lid});
    try self.emit("            break :blk_{d} Dynamic.fromAny(_d);\n", .{lid});
    try self.emit("        }} else if (@hasDecl(_target_{d}, \"builtin_getattr\")) {{\n", .{lid});
    try self.emit("            const _res_{d} = _target_{d}.builtin_getattr(\"{s}\");\n", .{ lid, lid, g.attr });
    try self.emit("            break :blk_{d} if (@typeInfo(@TypeOf(_res_{d})) == .error_union) try _res_{d} else _res_{d};\n", .{ lid, lid, lid, lid });
    try self.emit("        }}\n", .{});
    try self.emit("    }} else if ((info_{d} == .@\"struct\" or info_{d} == .@\"union\") and @hasDecl(T_{d}, \"builtin_getattr\")) {{\n", .{ lid, lid, lid });
    try self.emit("        const _res_{d} = _target_{d}.builtin_getattr(\"{s}\");\n", .{ lid, lid, g.attr });
    try self.emit("        break :blk_{d} if (@typeInfo(@TypeOf(_res_{d})) == .error_union) try _res_{d} else _res_{d};\n", .{ lid, lid, lid, lid });
    try self.emit("    }}\n", .{});
    try self.emit("    break :blk_{d} Dynamic{{ .value = .none_type }};\n", .{lid});
    try self.emit("}}))", .{});
}

pub fn transpileSafeGetattr(self: *Transpiler, g: anytype) anyerror!void {
    self.label_counter += 1;
    const lid = self.label_counter;
    try self.emit("((blk_{d}: {{\n", .{lid});
    try self.emit("    const _target_{d} = ", .{lid});
    try self.transpileExpr(g.target);
    try self.emit(";\n", .{});
    try self.emit("    const T_{d} = @TypeOf(_target_{d});\n", .{ lid, lid });
    try self.emit("    if (T_{d} == @TypeOf(null)) break :blk_{d} Dynamic.initNone();\n", .{ lid, lid });
    try self.emit("    if (T_{d} == Dynamic and _target_{d}.isNone()) break :blk_{d} Dynamic.initNone();\n", .{ lid, lid, lid });
    try self.emit("    if (@typeInfo(T_{d}) == .optional and _target_{d} == null) break :blk_{d} Dynamic.initNone();\n", .{ lid, lid, lid });
    try self.emit("    if (T_{d} == Dynamic) break :blk_{d} _target_{d}.builtin_getattr(\"{s}\");\n", .{ lid, lid, lid, g.attr });
    try self.emit("    if (@hasField(T_{d}, \"{s}\")) break :blk_{d} Dynamic.fromAny(@field(_target_{d}, \"{s}\"));\n", .{ lid, g.attr, lid, lid, g.attr });
    try self.emit("    if (@typeInfo(T_{d}) == .pointer and @hasField(@typeInfo(T_{d}).pointer.child, \"{s}\")) break :blk_{d} Dynamic.fromAny(@field(_target_{d}, \"{s}\"));\n", .{ lid, lid, g.attr, lid, lid, g.attr });
    try self.emit("    break :blk_{d} Dynamic.initNone();\n", .{lid});
    try self.emit("}}))", .{});
}

pub fn transpileCoalesceExpr(self: *Transpiler, c: anytype) anyerror!void {
    self.label_counter += 1;
    const lid = self.label_counter;
    try self.emit("((blk_{d}: {{\n", .{lid});
    try self.emit("    const _left_{d} = ", .{lid});
    try self.transpileExpr(c.left);
    try self.emit(";\n", .{});
    try self.emit("    const T_{d} = @TypeOf(_left_{d});\n", .{ lid, lid });
    try self.emit("    if (T_{d} == Dynamic and !_left_{d}.isNone()) break :blk_{d} _left_{d};\n", .{ lid, lid, lid, lid });
    try self.emit("    if (@typeInfo(T_{d}) == .optional and _left_{d} != null) break :blk_{d} Dynamic.fromAny(_left_{d}.?);\n", .{ lid, lid, lid, lid });
    try self.emit("    if (T_{d} != Dynamic and @typeInfo(T_{d}) != .optional and T_{d} != @TypeOf(null)) break :blk_{d} Dynamic.fromAny(_left_{d});\n", .{ lid, lid, lid, lid, lid });
    try self.emit("    break :blk_{d} Dynamic.fromAny(", .{lid});
    try self.transpileExpr(c.right);
    try self.emit(");\n", .{});
    try self.emit("}}))", .{});
}
