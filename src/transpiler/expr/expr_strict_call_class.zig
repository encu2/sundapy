const std = @import("std");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileStrictClassCall(self: *Transpiler, c: anytype, name: []const u8) anyerror!bool {
    var is_class = false;
    if (std.mem.lastIndexOf(u8, name, ".")) |last_dot| {
        const base_name = name[last_dot + 1..];
        is_class = base_name.len > 0 and base_name[0] >= 'A' and base_name[0] <= 'Z';
    } else {
        is_class = name.len > 0 and name[0] >= 'A' and name[0] <= 'Z';
    }

    if (!self.classes.contains(name) and !is_class) {
        return false;
    }

    self.label_counter += 1;
    const lid = self.label_counter;
    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    if (@hasDecl(@This(), \"_sundapy_is_abi_{s}\") and @field(@This(), \"_sundapy_is_abi_{s}\")) {{\n", .{ name, name });
    try self.emit("        var _args_arr = [_]Dynamic{{", .{});
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
    try self.emit("}};\n", .{});
    if (c.kwargs.items.len > 0) {
        try self.emit("        var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
        for (c.kwargs.items) |kw| {
            try self.emit("        _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(kw.value);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(kw.value);
            }
            try self.emit(") catch {{}};\n", .{});
        }
        try self.emit("        break :blk_{d} try @field(@This(), \"{s}_dyn\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{ lid, name });
    } else {
        try self.emit("        break :blk_{d} try @field(@This(), \"{s}_dyn\").builtin_call(alloc, &_args_arr, null);\n", .{ lid, name });
    }
    try self.emit("    }} else {{\n", .{});
    try self.emit("        const T_{s} = @TypeOf({s});\n", .{ name, name });
    try self.emit("        if (T_{s} == type) {{\n", .{name});
    try self.emit("            var obj = {s}{{}};\n", .{name});
    try self.emit("            _ = try obj.__init__(", .{});
    for (c.args.items, 0..) |arg, idx| {
        if (self.is_strict) {
            try self.transpileExprStrict(arg);
        } else {
            try self.transpileExpr(arg);
        }
        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit(");\n", .{});
    try self.emit("            break :blk_{d} obj;\n", .{lid});
    try self.emit("        }} else if (T_{s} == dynamic.Dynamic) {{\n", .{name});
    try self.emit("            var _args_arr = [_]Dynamic{{", .{});
    for (c.args.items, 0..) |arg2, idx2| {
        if (self.is_strict) {
            try self.emit("Dynamic.fromAny(", .{});
            try self.transpileExprStrict(arg2);
            try self.emit(")", .{});
        } else {
            try self.transpileExpr(arg2);
        }
        if (idx2 < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit("}};\n", .{});
    if (c.kwargs.items.len > 0) {
        try self.emit("            var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
        for (c.kwargs.items) |kw2| {
            try self.emit("            _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw2.key});
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(kw2.value);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(kw2.value);
            }
            try self.emit(") catch {{}};\n", .{});
        }
        try self.emit("            break :blk_{d} try {s}.builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{ lid, name });
    } else {
        try self.emit("            break :blk_{d} try {s}.builtin_call(alloc, &_args_arr, null);\n", .{ lid, name });
    }
    try self.emit("        }} else if (comptime @typeInfo(T_{s}) == .@\"fn\") {{\n", .{name});
    try self.emit("            var _args_arr = [_]Dynamic{{\n", .{});
    for (c.args.items, 0..) |arg3, idx3| {
        if (self.is_strict) {
            try self.emit("Dynamic.fromAny(", .{});
            try self.transpileExprStrict(arg3);
            try self.emit(")", .{});
        } else {
            try self.transpileExpr(arg3);
        }
        if (idx3 < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit("}};\n", .{});
    if (c.kwargs.items.len > 0) {
        try self.emit("            var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
        for (c.kwargs.items) |kw3| {
            try self.emit("            _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw3.key});
            if (self.is_strict) {
                try self.emit("Dynamic.fromAny(", .{});
                try self.transpileExprStrict(kw3.value);
                try self.emit(")", .{});
            } else {
                try self.transpileExpr(kw3.value);
            }
            try self.emit(") catch {{}};\n", .{});
        }
        try self.emit("            break :blk_{d} try dynamic.toDynamicFunc({s}).builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{ lid, name });
    } else {
        try self.emit("            break :blk_{d} try dynamic.toDynamicFunc({s}).builtin_call(alloc, &_args_arr, null);\n", .{ lid, name });
    }
    try self.emit("        }} else {{\n", .{});
    try self.emit("            break :blk_{d} try {s}(", .{ lid, name });
    for (c.args.items, 0..) |arg3, idx3| {
        if (self.is_strict) {
            try self.transpileExprStrict(arg3);
        } else {
            try self.transpileExpr(arg3);
        }
        if (idx3 < c.args.items.len - 1) try self.emit(", ", .{});
    }
    try self.emit(");\n", .{});
    try self.emit("        }}\n", .{});
    try self.emit("    }}\n", .{});
    try self.emit("}})", .{});
    return true;
}
