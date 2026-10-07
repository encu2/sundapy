const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

fn isMathModule(self: *Transpiler, target: *ast.Node) bool {
    if (target.* == .identifier) {
        if (std.mem.eql(u8, target.identifier.name, "math")) return true;
        if (self.module_aliases.get(target.identifier.name)) |orig| {
            if (std.mem.eql(u8, orig, "math")) return true;
        }
    }
    return false;
}

pub fn tryLowerMathIntrinsic(self: *Transpiler, m: anytype) anyerror!bool {
    if (!self.isStrict()) return false;
    if (!isMathModule(self, m.target)) return false;
    if (m.kwargs.items.len > 0) return false;

    const args = m.args.items;

    // 1-argument mathematical functions
    if (args.len == 1) {
        const arg = args[0];
        const intrinsic_fn: ?[]const u8 = if (std.mem.eql(u8, m.method, "sqrt"))
            "@sqrt"
        else if (std.mem.eql(u8, m.method, "sin"))
            "@sin"
        else if (std.mem.eql(u8, m.method, "cos"))
            "@cos"
        else if (std.mem.eql(u8, m.method, "tan"))
            "@tan"
        else if (std.mem.eql(u8, m.method, "exp"))
            "@exp"
        else if (std.mem.eql(u8, m.method, "exp2"))
            "@exp2"
        else if (std.mem.eql(u8, m.method, "log"))
            "@log"
        else if (std.mem.eql(u8, m.method, "log2"))
            "@log2"
        else if (std.mem.eql(u8, m.method, "log10"))
            "@log10"
        else if (std.mem.eql(u8, m.method, "floor"))
            "@floor"
        else if (std.mem.eql(u8, m.method, "ceil"))
            "@ceil"
        else if (std.mem.eql(u8, m.method, "trunc"))
            "@trunc"
        else if (std.mem.eql(u8, m.method, "round"))
            "@round"
        else if (std.mem.eql(u8, m.method, "fabs"))
            "@abs"
        else if (std.mem.eql(u8, m.method, "asin"))
            "std.math.asin"
        else if (std.mem.eql(u8, m.method, "acos"))
            "std.math.acos"
        else if (std.mem.eql(u8, m.method, "atan"))
            "std.math.atan"
        else if (std.mem.eql(u8, m.method, "sinh"))
            "std.math.sinh"
        else if (std.mem.eql(u8, m.method, "cosh"))
            "std.math.cosh"
        else if (std.mem.eql(u8, m.method, "tanh"))
            "std.math.tanh"
        else if (std.mem.eql(u8, m.method, "asinh"))
            "std.math.asinh"
        else if (std.mem.eql(u8, m.method, "acosh"))
            "std.math.acosh"
        else if (std.mem.eql(u8, m.method, "atanh"))
            "std.math.atanh"
        else if (std.mem.eql(u8, m.method, "isnan"))
            "std.math.isNan"
        else if (std.mem.eql(u8, m.method, "isinf"))
            "std.math.isInf"
        else if (std.mem.eql(u8, m.method, "isfinite"))
            "std.math.isFinite"
        else
            null;

        if (intrinsic_fn) |fn_name| {
            try self.emit("{s}(_sundapy_to_f64(", .{fn_name});
            try self.transpileExprStrict(arg);
            try self.emit("))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "radians")) {
            try self.emit("(_sundapy_to_f64(", .{});
            try self.transpileExprStrict(arg);
            try self.emit(") * (std.math.pi / 180.0))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "degrees")) {
            try self.emit("(_sundapy_to_f64(", .{});
            try self.transpileExprStrict(arg);
            try self.emit(") * (180.0 / std.math.pi))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "isqrt")) {
            try self.emit("@as(i64, @intCast(std.math.sqrt(@as(u64, @intCast(@abs(", .{});
            try self.transpileExprStrict(arg);
            try self.emit("))))))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "popcount") or std.mem.eql(u8, m.method, "bit_count")) {
            try self.emit("@as(i64, @intCast(@popCount(@as(u64, @bitCast(", .{});
            try self.transpileExprStrict(arg);
            try self.emit(")))))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "factorial")) {
            try self.emit("(blk: {{ const _n: i64 = @intCast(", .{});
            try self.transpileExprStrict(arg);
            try self.emit("); var _acc: i64 = 1; var _i: i64 = 2; while (_i <= _n) : (_i += 1) _acc *%= _i; break :blk _acc; }})", .{});
            return true;
        }
    }

    // 2-argument mathematical functions
    if (args.len == 2) {
        if (std.mem.eql(u8, m.method, "gcd")) {
            try self.emit("@as(i64, @intCast(std.math.gcd(@as(u64, @intCast(@abs(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("))), @as(u64, @intCast(@abs(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("))))))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "lcm")) {
            try self.emit("blk: {{ const _a: u64 = @intCast(@abs(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit(")); const _b: u64 = @intCast(@abs(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit(")); if (_a == 0 or _b == 0) break :blk @as(i64, 0); const _g = std.math.gcd(_a, _b); break :blk @as(i64, @intCast((_a / _g) * _b)); }}", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "comb") or std.mem.eql(u8, m.method, "binomial")) {
            try self.emit("(blk: {{ const _n: i64 = @intCast(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("); var _k: i64 = @intCast(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("); if (_k < 0 or _k > _n) break :blk @as(i64, 0); if (_k == 0 or _k == _n) break :blk @as(i64, 1); if (_k > _n - _k) _k = _n - _k; var _c: i64 = 1; var _i: i64 = 0; while (_i < _k) : (_i += 1) _c = @divExact(_c *% (_n - _i), _i + 1); break :blk _c; }})", .{});
            return true;
        }
        if (std.mem.eql(u8, m.method, "hypot")) {
            try self.emit("std.math.hypot(_sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("), _sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "pow")) {
            try self.emit("std.math.pow(f64, _sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("), _sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "atan2")) {
            try self.emit("std.math.atan2(_sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("), _sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("))", .{});
            return true;
        }

        if (std.mem.eql(u8, m.method, "copysign")) {
            try self.emit("std.math.copysign(_sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[0]);
            try self.emit("), _sundapy_to_f64(", .{});
            try self.transpileExprStrict(args[1]);
            try self.emit("))", .{});
            return true;
        }
    }

    return false;
}

pub fn tryLowerMathAttr(self: *Transpiler, g: anytype) anyerror!bool {
    if (!self.isStrict()) return false;
    if (!isMathModule(self, g.target)) return false;

    if (std.mem.eql(u8, g.attr, "pi")) {
        try self.emit("std.math.pi", .{});
        return true;
    }
    if (std.mem.eql(u8, g.attr, "e")) {
        try self.emit("std.math.e", .{});
        return true;
    }
    if (std.mem.eql(u8, g.attr, "tau")) {
        try self.emit("std.math.tau", .{});
        return true;
    }
    if (std.mem.eql(u8, g.attr, "inf")) {
        try self.emit("std.math.inf(f64)", .{});
        return true;
    }
    if (std.mem.eql(u8, g.attr, "nan")) {
        try self.emit("std.math.nan(f64)", .{});
        return true;
    }

    return false;
}
