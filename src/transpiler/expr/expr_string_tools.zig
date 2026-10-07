const std = @import("std");

/// Computes common indentation and dedents string at compile-time (PEP 822)
pub fn dedentString(allocator: std.mem.Allocator, input: []const u8) []const u8 {
    var min_indent: usize = std.math.maxInt(usize);
    var it = std.mem.splitScalar(u8, input, '\n');

    // First pass: find minimum indentation of non-empty lines
    var is_first = true;
    while (it.next()) |line| {
        if (is_first) {
            is_first = false;
            // Often first line after d""" is empty newline
            if (line.len == 0) continue;
        }
        var indent: usize = 0;
        for (line) |ch| {
            if (ch == ' ') {
                indent += 1;
            } else if (ch == '\t') {
                indent += 4;
            } else {
                break;
            }
        }
        if (indent < line.len) {
            if (indent < min_indent) min_indent = indent;
        }
    }

    if (min_indent == std.math.maxInt(usize)) {
        min_indent = 0;
    }

    // Second pass: strip min_indent from each line
    var res: std.ArrayList(u8) = .empty;
    var it2 = std.mem.splitScalar(u8, input, '\n');
    var is_first2 = true;
    while (it2.next()) |line| {
        if (!is_first2) {
            res.append(allocator, '\n') catch unreachable;
        }
        is_first2 = false;
        if (line.len > min_indent) {
            res.appendSlice(allocator, line[min_indent..]) catch unreachable;
        } else {
            // Line with only spaces
            const trimmed = std.mem.trim(u8, line, " \t");
            res.appendSlice(allocator, trimmed) catch unreachable;
        }
    }
    return res.items;
}

pub fn escapeForZig(allocator: std.mem.Allocator, s: []const u8) []const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (s) |c| {
        if (c == '"') {
            out.appendSlice(allocator, "\\\"") catch unreachable;
        } else if (c == '\\') {
            out.appendSlice(allocator, "\\\\") catch unreachable;
        } else if (c == '\n') {
            out.appendSlice(allocator, "\\n") catch unreachable;
        } else if (c == '\r') {
            out.appendSlice(allocator, "\\r") catch unreachable;
        } else if (c == '\t') {
            out.appendSlice(allocator, "\\t") catch unreachable;
        } else {
            out.append(allocator, c) catch unreachable;
        }
    }
    return out.items;
}
