const std = @import("std");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileStrictBuiltinCall(self: *Transpiler, c: anytype, name: []const u8) anyerror!bool {
    if (std.mem.eql(u8, name, "range")) {
        if (c.args.items.len == 1) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = 0, .stop = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[0]);
            } else {
                try self.transpileExpr(c.args.items[0]);
            }
            try self.emit(").value.i64_type), .step = 1 }} }} }}", .{});
        } else if (c.args.items.len == 2) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[0]);
            } else {
                try self.transpileExpr(c.args.items[0]);
            }
            try self.emit(").value.i64_type), .stop = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[1]);
            } else {
                try self.transpileExpr(c.args.items[1]);
            }
            try self.emit(").value.i64_type), .step = 1 }} }} }}", .{});
        } else if (c.args.items.len == 3) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[0]);
            } else {
                try self.transpileExpr(c.args.items[0]);
            }
            try self.emit(").value.i64_type), .stop = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[1]);
            } else {
                try self.transpileExpr(c.args.items[1]);
            }
            try self.emit(").value.i64_type), .step = @intCast(dynamic.Dynamic.fromAny(", .{});
            if (self.is_strict) {
                try self.transpileExprStrict(c.args.items[2]);
            } else {
                try self.transpileExpr(c.args.items[2]);
            }
            try self.emit(").value.i64_type) }} }} }}", .{});
        }
        return true;
    } else if (std.mem.eql(u8, name, "len")) {
        try self.emit("(", .{});
        try self.transpileExpr(c.args.items[0]);
        try self.emit(").builtin_len()", .{});
        return true;
    } else if (std.mem.eql(u8, name, "type")) {
        try self.emit("(", .{});
        try self.transpileExpr(c.args.items[0]);
        try self.emit(").builtin_type()", .{});
        return true;
    } else if (std.mem.eql(u8, name, "isinstance")) {
        if (c.args.items.len >= 2 and c.args.items[1].* == .list_expr) {
            try self.emit("Dynamic.initBool(", .{});
            for (c.args.items[1].list_expr.items.items, 0..) |elem, idx| {
                if (idx > 0) try self.emit(" or ", .{});
                if (elem.* == .identifier) {
                    try self.emit("(", .{});
                    try self.transpileExpr(c.args.items[0]);
                    try self.emit(").builtin_isinstance(\"{s}\").toBool()", .{elem.identifier.name});
                } else {
                    try self.emit("false", .{});
                }
            }
            try self.emit(")", .{});
        } else {
            try self.emit("(", .{});
            try self.transpileExpr(c.args.items[0]);
            if (c.args.items.len >= 2 and c.args.items[1].* == .identifier) {
                try self.emit(").builtin_isinstance(\"{s}\")", .{c.args.items[1].identifier.name});
            } else {
                try self.emit(").builtin_isinstance(\"\")", .{});
            }
        }
        return true;
    } else if (std.mem.eql(u8, name, "input")) {
        try self.emit("Dynamic.builtin_input(alloc", .{});
        if (c.args.items.len > 0) {
            try self.emit(", ", .{});
            try self.transpileExpr(c.args.items[0]);
        } else {
            try self.emit(", Dynamic.initNone()", .{});
        }
        try self.emit(")", .{});
        return true;
    } else if (std.mem.eql(u8, name, "min") or std.mem.eql(u8, name, "max")) {
        try self.emit("Dynamic.builtin_{s}(&[_]Dynamic{{", .{name});
        for (c.args.items, 0..) |arg, idx| {
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(arg);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(arg);
            }
            if (idx < c.args.items.len - 1) try self.emit(", ", .{});
        }
        try self.emit("}})", .{});
        return true;
    }

    if (self.is_strict) {
        if (std.mem.eql(u8, name, "float")) {
            if (c.args.items.len == 0) {
                try self.emit("@as(f64, 0.0)", .{});
                return true;
            } else if (c.args.items.len == 1) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _v = ", .{});
                try self.transpileExprStrict(c.args.items[0]);
                try self.emit(";\n", .{});
                try self.emit("    const _T = @TypeOf(_v);\n", .{});
                try self.emit("    const _ti = @typeInfo(_T);\n", .{});
                try self.emit("    break :blk_{d} switch (_ti) {{\n", .{lid});
                try self.emit("        .int, .comptime_int => @as(f64, @floatFromInt(_v)),\n", .{});
                try self.emit("        .float, .comptime_float => @as(f64, @floatCast(_v)),\n", .{});
                try self.emit("        else => if (comptime (_ti == .@\"struct\" or _ti == .@\"union\") and @hasDecl(_T, \"builtin_float\")) _v.builtin_float().value.float_type else @as(f64, 0.0),\n", .{});
                try self.emit("    }};\n", .{});
                try self.emit("}})", .{});
                return true;
            }
        } else if (std.mem.eql(u8, name, "int")) {
            if (c.args.items.len == 0) {
                try self.emit("@as(i64, 0)", .{});
                return true;
            } else if (c.args.items.len == 1) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _v = ", .{});
                try self.transpileExprStrict(c.args.items[0]);
                try self.emit(";\n", .{});
                try self.emit("    const _T = @TypeOf(_v);\n", .{});
                try self.emit("    const _ti = @typeInfo(_T);\n", .{});
                try self.emit("    break :blk_{d} switch (_ti) {{\n", .{lid});
                try self.emit("        .int, .comptime_int => @as(i64, @intCast(_v)),\n", .{});
                try self.emit("        .float, .comptime_float => @as(i64, @intFromFloat(_v)),\n", .{});
                try self.emit("        else => if (comptime (_ti == .@\"struct\" or _ti == .@\"union\") and @hasDecl(_T, \"builtin_int\")) _v.builtin_int().value.i64_type else @as(i64, 0),\n", .{});
                try self.emit("    }};\n", .{});
                try self.emit("}})", .{});
                return true;
            }
        } else if (std.mem.eql(u8, name, "bool")) {
            if (c.args.items.len == 0) {
                try self.emit("false", .{});
                return true;
            } else if (c.args.items.len == 1) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    const _v = ", .{});
                try self.transpileExprStrict(c.args.items[0]);
                try self.emit(";\n", .{});
                try self.emit("    const _T = @TypeOf(_v);\n", .{});
                try self.emit("    const _ti = @typeInfo(_T);\n", .{});
                try self.emit("    break :blk_{d} switch (_ti) {{\n", .{lid});
                try self.emit("        .bool => _v,\n", .{});
                try self.emit("        .int, .comptime_int => _v != 0,\n", .{});
                try self.emit("        .float, .comptime_float => _v != 0.0,\n", .{});
                try self.emit("        else => if (comptime (_ti == .@\"struct\" or _ti == .@\"union\") and @hasDecl(_T, \"builtin_bool\")) _v.builtin_bool().value.bool_type else false,\n", .{});
                try self.emit("    }};\n", .{});
                try self.emit("}})", .{});
                return true;
            }
        }
    }

    const builtins_0_alloc = [_][]const u8{ "bytearray", "bytes", "dict", "frozenset", "list", "set", "tuple", "object", "super", "breakpoint" };
    for (builtins_0_alloc) |b| {
        if (std.mem.eql(u8, name, b)) {
            try self.emit("Dynamic.builtin_{s}(alloc", .{name});
            if (c.args.items.len > 0) {
                try self.emit(", ", .{});
                try self.transpileExpr(c.args.items[0]);
            } else {
                try self.emit(", Dynamic.initNone()", .{});
            }
            try self.emit(")", .{});
            return true;
        }
    }

    const builtins_1_alloc = [_][]const u8{ "str", "ascii", "bin", "chr", "hex", "oct", "repr" };
    for (builtins_1_alloc) |b| {
        if (std.mem.eql(u8, name, b)) {
            try self.emit("(", .{});
            try self.transpileExpr(c.args.items[0]);
            try self.emit(").builtin_{s}(alloc)", .{name});
            return true;
        }
    }

    const builtins_1 = [_][]const u8{ "len", "type", "int", "float", "bool", "sum", "abs", "all", "any", "callable", "enumerate", "hash", "id", "ord", "reversed", "round", "sorted" };
    for (builtins_1) |b| {
        if (std.mem.eql(u8, name, b)) {
            try self.emit("(", .{});
            try self.transpileExpr(c.args.items[0]);
            try self.emit(").builtin_{s}()", .{name});
            return true;
        }
    }

    const builtins_2 = [_][]const u8{ "divmod", "pow", "format", "issubclass" };
    for (builtins_2) |b| {
        if (std.mem.eql(u8, name, b)) {
            try self.emit("(", .{});
            try self.transpileExpr(c.args.items[0]);
            try self.emit(").builtin_{s}(", .{name});
            try self.transpileExpr(c.args.items[1]);
            try self.emit(")", .{});
            return true;
        }
    }

    const builtins_multi = [_][]const u8{ "zip", "open", "complex", "dir", "getattr", "setattr", "hasattr", "delattr", "filter", "map", "iter", "next", "help", "memoryview", "slice", "vars", "__import__" };
    for (builtins_multi) |b| {
        if (std.mem.eql(u8, name, b)) {
            try self.emit("Dynamic.builtin_{s}(alloc, &[_]Dynamic{{", .{name});
            for (c.args.items, 0..) |arg, idx| {
                try self.transpileExpr(arg);
                if (idx < c.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit("}})", .{});
            return true;
        }
    }

    return false;
}
