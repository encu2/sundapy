const std = @import("std");
const Transpiler = @import("../transpiler.zig").Transpiler;

pub fn transpileFString(self: *Transpiler, f: anytype, is_strict: bool) !void {
    if (std.mem.indexOfScalar(u8, f.value, '{') == null) {
        const escaped = @import("expr_string_tools.zig").escapeForZig(self.allocator, f.value);
        if (is_strict) {
            try self.emit("\"{s}\"", .{escaped});
        } else {
            try self.emit("Dynamic{{ .value = .{{ .str_type = \"{s}\" }} }}", .{escaped});
        }
        return;
    }

    self.label_counter += 1;
    const lid = self.label_counter;
    try self.emit("(blk_{d}: {{\n", .{lid});
    try self.emit("    const _parts_{d} = [_][]const u8{{\n", .{lid});

    var i: usize = 0;
    var start_idx: usize = 0;
    while (i < f.value.len) {
        if (f.value[i] == '{') {
            // Escaped brace: {{ -> literal "{"
            if (i + 1 < f.value.len and f.value[i + 1] == '{') {
                if (i > start_idx) {
                    const esc = @import("expr_string_tools.zig").escapeForZig(self.allocator, f.value[start_idx..i]);
                    try self.emit("        \"{s}\",\n", .{esc});
                }
                try self.emit("        \"{{\",\n", .{});
                i += 2;
                start_idx = i;
                continue;
            }

            if (i > start_idx) {
                const esc = @import("expr_string_tools.zig").escapeForZig(self.allocator, f.value[start_idx..i]);
                try self.emit("        \"{s}\",\n", .{esc});
            }
            i += 1;
            const var_start = i;
            var depth: usize = 1;
            while (i < f.value.len and depth > 0) {
                if (f.value[i] == '{') {
                    depth += 1;
                } else if (f.value[i] == '}') {
                    depth -= 1;
                    if (depth == 0) break;
                }
                i += 1;
            }
            if (i < f.value.len and f.value[i] == '}') {
                const var_name = f.value[var_start..i];
                var actual_var = var_name;
                if (std.mem.indexOfScalar(u8, var_name, ':')) |colon_idx| {
                    actual_var = var_name[0..colon_idx];
                }
                if (std.mem.indexOfScalar(u8, actual_var, '!')) |excl_idx| {
                    actual_var = actual_var[0..excl_idx];
                }
                const trimmed_var = std.mem.trim(u8, actual_var, " \t\r\n");
                if (trimmed_var.len == 0) {
                    try self.emit("        \"\",\n", .{});
                    start_idx = i + 1;
                    continue;
                }
                var sub_lexer = @import("../../lexer/lexer.zig").Lexer.init(self.allocator, trimmed_var);
                defer sub_lexer.deinit();
                var sub_parser = @import("../../parser/parser.zig").Parser.initQuiet(self.allocator, &sub_lexer);
                if (sub_parser.parseExpr(.none)) |expr_node| {
                    try self.emit("        dynamic.stringifyStr(alloc, ", .{});
                    if (is_strict) {
                        self.transpileExprStrict(expr_node) catch {
                            try self.transpileExpr(expr_node);
                        };
                    } else {
                        try self.transpileExpr(expr_node);
                    }
                    try self.emit("),\n", .{});
                } else |_| {
                    const esc = @import("expr_string_tools.zig").escapeForZig(self.allocator, trimmed_var);
                    try self.emit("        dynamic.stringifyStr(alloc, \"{s}\"),\n", .{esc});
                }
                start_idx = i + 1;
            }
        } else if (f.value[i] == '}') {
            // Escaped brace: }} -> literal "}"
            if (i + 1 < f.value.len and f.value[i + 1] == '}') {
                if (i > start_idx) {
                    const esc = @import("expr_string_tools.zig").escapeForZig(self.allocator, f.value[start_idx..i]);
                    try self.emit("        \"{s}\",\n", .{esc});
                }
                try self.emit("        \"}}\",\n", .{});
                i += 2;
                start_idx = i;
                continue;
            }
        }
        i += 1;
    }
    if (start_idx < f.value.len) {
        const esc = @import("expr_string_tools.zig").escapeForZig(self.allocator, f.value[start_idx..]);
        try self.emit("        \"{s}\",\n", .{esc});
    }
    try self.emit("    }};\n", .{});
    if (is_strict) {
        try self.emit("    break :blk_{d} (std.mem.concat(alloc, u8, &_parts_{d}) catch \"\");\n", .{ lid, lid });
    } else {
        try self.emit("    break :blk_{d} Dynamic{{ .value = .{{ .str_type = std.mem.concat(alloc, u8, &_parts_{d}) catch \"\" }} }};\n", .{ lid, lid });
    }
    try self.emit("}})", .{});
}
