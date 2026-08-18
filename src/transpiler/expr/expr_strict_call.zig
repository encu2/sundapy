const std = @import("std");
const ast = @import("../../core/ast.zig");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileStrictCall(self: *Transpiler, c: anytype) anyerror!void {
    if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "range")) {
        if (c.args.items.len == 1) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = 0, .stop = ", .{});
            try self.transpileExprStrict(c.args.items[0]);
            try self.emit(", .step = 1 }} }} }}", .{});
        } else if (c.args.items.len == 2) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = ", .{});
            try self.transpileExprStrict(c.args.items[0]);
            try self.emit(", .stop = ", .{});
            try self.transpileExprStrict(c.args.items[1]);
            try self.emit(", .step = 1 }} }} }}", .{});
        } else if (c.args.items.len == 3) {
            try self.emit("Dynamic{{ .value = .{{ .range_type = .{{ .start = ", .{});
            try self.transpileExprStrict(c.args.items[0]);
            try self.emit(", .stop = ", .{});
            try self.transpileExprStrict(c.args.items[1]);
            try self.emit(", .step = ", .{});
            try self.transpileExprStrict(c.args.items[2]);
            try self.emit(" }} }} }}", .{});
        }
    } else if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "len")) {
        try self.emit("(", .{});
        try self.transpileExpr(c.args.items[0]);
        try self.emit(").builtin_len()", .{});
    } else if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "type")) {
        try self.emit("(", .{});
        try self.transpileExpr(c.args.items[0]);
        try self.emit(").builtin_type()", .{});
    } else if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "isinstance")) {
        try self.emit("(", .{});
        try self.transpileExpr(c.args.items[0]);
        if (c.args.items[1].* == .identifier) {
            try self.emit(").builtin_isinstance(\"{s}\")", .{c.args.items[1].identifier.name});
        } else {
            try self.emit(").builtin_isinstance(\"\")", .{});
        }
    } else if (c.callee.* == .identifier and std.mem.eql(u8, c.callee.identifier.name, "input")) {
        try self.emit("Dynamic.builtin_input(alloc", .{});
        if (c.args.items.len > 0) {
            try self.emit(", ", .{});
            try self.transpileExpr(c.args.items[0]);
        } else {
            try self.emit(", Dynamic.initNone()", .{});
        }
        try self.emit(")", .{});
    } else if (c.callee.* == .identifier) {
        const name = c.callee.identifier.name;
        const builtins_0_alloc = [_][]const u8{"bytearray", "bytes", "dict", "frozenset", "list", "set", "tuple", "object", "super", "breakpoint"};
        const builtins_1_alloc = [_][]const u8{"str", "ascii", "bin", "chr", "hex", "oct", "repr"};
        const builtins_1 = [_][]const u8{"len", "type", "int", "float", "bool", "min", "max", "sum", "abs", "all", "any", "callable", "enumerate", "hash", "id", "ord", "reversed", "round", "sorted"};
        const builtins_2 = [_][]const u8{"divmod", "pow", "format", "issubclass"};
        const builtins_multi = [_][]const u8{"zip", "open", "complex", "dir", "getattr", "setattr", "hasattr", "delattr", "filter", "map", "iter", "next", "help", "memoryview", "slice", "vars", "__import__"};
        
        var handled = false;
        
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
                handled = true;
                break;
            }
        }
        
        if (!handled) {
            for (builtins_1_alloc) |b| {
                if (std.mem.eql(u8, name, b)) {
                    try self.emit("(", .{});
                    try self.transpileExpr(c.args.items[0]);
                    try self.emit(").builtin_{s}(alloc)", .{name});
                    handled = true;
                    break;
                }
            }
        }
        
        if (!handled) {
            for (builtins_1) |b| {
                if (std.mem.eql(u8, name, b)) {
                    try self.emit("(", .{});
                    try self.transpileExpr(c.args.items[0]);
                    try self.emit(").builtin_{s}()", .{name});
                    handled = true;
                    break;
                }
            }
        }
        
        if (!handled) {
            for (builtins_2) |b| {
                if (std.mem.eql(u8, name, b)) {
                    try self.emit("(", .{});
                    try self.transpileExpr(c.args.items[0]);
                    try self.emit(").builtin_{s}(", .{name});
                    try self.transpileExpr(c.args.items[1]);
                    try self.emit(")", .{});
                    handled = true;
                    break;
                }
            }
        }
        
        if (!handled) {
            for (builtins_multi) |b| {
                if (std.mem.eql(u8, name, b)) {
                    try self.emit("Dynamic.builtin_{s}(alloc, &[_]Dynamic{{", .{name});
                    for (c.args.items, 0..) |arg, idx| {
                        try self.transpileExpr(arg);
                        if (idx < c.args.items.len - 1) try self.emit(", ", .{});
                    }
                    try self.emit("}})", .{});
                    handled = true;
                    break;
                }
            }
        }
        
        if (!handled) {
            const is_class = name.len > 0 and name[0] >= 'A' and name[0] <= 'Z';
            if (self.classes.contains(name) or is_class) {
                self.label_counter += 1;
                const lid = self.label_counter;
                try self.emit("(blk_{d}: {{\n", .{lid});
                try self.emit("    if (@hasDecl(@This(), \"_sundapy_is_abi_{s}\") and @field(@This(), \"_sundapy_is_abi_{s}\")) {{\n", .{name, name});
                try self.emit("        var _args_arr = [_]Dynamic{{", .{});
                for (c.args.items, 0..) |arg, idx| {
                    if (self.is_strict) {
                        try self.transpileExprStrict(arg);
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
                            try self.transpileExprStrict(kw.value);
                        } else {
                            try self.transpileExpr(kw.value);
                        }
                        try self.emit(") catch {{}};\n", .{});
                    }
                    try self.emit("        break :blk_{d} try @field(@This(), \"{s}_dyn\").builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, name});
                } else {
                    try self.emit("        break :blk_{d} try @field(@This(), \"{s}_dyn\").builtin_call(alloc, &_args_arr, null);\n", .{lid, name});
                }
                try self.emit("    }} else {{\n", .{});
                try self.emit("        const T_{s} = @TypeOf({s});\n", .{name, name});
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
                try self.emit("        }} else {{\n", .{});
                try self.emit("            var _args_arr = [_]Dynamic{{", .{});
                for (c.args.items, 0..) |arg, idx| {
                    if (self.is_strict) {
                        try self.transpileExprStrict(arg);
                    } else {
                        try self.transpileExpr(arg);
                    }
                    if (idx < c.args.items.len - 1) try self.emit(", ", .{});
                }
                try self.emit("}};\n", .{});
                if (c.kwargs.items.len > 0) {
                    try self.emit("            var _kwargs_dict = dynamic.Dynamic.initDict(alloc);\n", .{});
                    for (c.kwargs.items) |kw| {
                        try self.emit("            _kwargs_dict.setDynamicItem(dynamic.Dynamic.initStr(\"{s}\"), ", .{kw.key});
                        if (self.is_strict) {
                            try self.transpileExprStrict(kw.value);
                        } else {
                            try self.transpileExpr(kw.value);
                        }
                        try self.emit(") catch {{}};\n", .{});
                    }
                    try self.emit("            break :blk_{d} try {s}.builtin_call(alloc, &_args_arr, _kwargs_dict);\n", .{lid, name});
                } else {
                    try self.emit("            break :blk_{d} try {s}.builtin_call(alloc, &_args_arr, null);\n", .{lid, name});
                }
                try self.emit("        }}\n", .{});
                try self.emit("    }}\n", .{});
                try self.emit("}})", .{});
                handled = true;
            }
        }
        
        if (!handled) {
            var is_strict_func = false;
            if (c.callee.* == .identifier) {
                if (self.strict_funcs) |sf| {
                    if (sf.contains(c.callee.identifier.name)) {
                        is_strict_func = true;
                    }
                }
            }
            if (self.try_depth == 0) {
                try self.emit("try ", .{});
            } else if (self.try_depth > 0) {
                try self.emit("(", .{});
            }
            try self.transpileExpr(c.callee);
            try self.emit("(", .{});
            for (c.args.items, 0..) |arg, idx| {
                if (is_strict_func or self.is_strict) {
                    try self.transpileExprStrict(arg);
                } else {
                    try self.transpileExpr(arg);
                }
                if (idx < c.args.items.len - 1) try self.emit(", ", .{});
            }
            try self.emit(")", .{});
            if (self.try_depth > 0) {
                self.label_counter += 1;
                try self.emit(" catch |err_{d}| break :blk_{d} err_{d})", .{self.label_counter, self.try_depth, self.label_counter});
            }
        }
    }
}
