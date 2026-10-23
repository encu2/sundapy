const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseImportStmt(self: *Parser) anyerror!*ast.Node {
    var nodes: std.ArrayList(*ast.Node) = .empty;
    while (true) {
        var name: []const u8 = undefined;
        if (self.current.type == .String or self.current.type == .DString or self.current.type == .TString) {
            var raw = self.current.lexeme;
            if (raw.len >= 2 and (raw[0] == '"' or raw[0] == '\'')) {
                raw = raw[1 .. raw.len - 1];
            }
            name = raw;
            self.advance();
        } else {
            const name_ptr = self.current.lexeme.ptr;
            var name_len = self.current.lexeme.len;
            try self.expect(.Identifier);
            while (self.match(.Dot)) {
                name_len = (@intFromPtr(self.current.lexeme.ptr) - @intFromPtr(name_ptr)) + self.current.lexeme.len;
                try self.expect(.Identifier);
            }
            name = name_ptr[0..name_len];
        }

        var alias: ?[]const u8 = null;
        if (self.match(.KeywordAs)) {
            alias = self.current.lexeme;
            try self.expect(.Identifier);
        }
        const node = try self.allocator.create(ast.Node);
        node.* = .{ .import_stmt = .{ .name = name, .alias = alias } };
        try nodes.append(self.allocator, node);

        if (!self.match(.Comma)) break;
    }
    try self.consumeStmtEnd();
    if (nodes.items.len == 1) return nodes.items[0];
    const comp = try self.allocator.create(ast.Node);
    comp.* = .{ .compound_stmt = .{ .items = nodes } };
    return comp;
}

pub fn parseFromImport(self: *Parser) anyerror!*ast.Node {
    var mod: []const u8 = undefined;
    var level: usize = 0;
    if (self.current.type == .String or self.current.type == .DString or self.current.type == .TString) {
        var raw = self.current.lexeme;
        if (raw.len >= 2 and (raw[0] == '"' or raw[0] == '\'')) {
            raw = raw[1 .. raw.len - 1];
        }
        mod = raw;
        self.advance();
    } else {
        while (self.current.type == .Dot or self.current.type == .Ellipsis) {
            if (self.current.type == .Dot) {
                level += 1;
            } else {
                level += 3;
            }
            self.advance();
        }

        if (self.current.type == .Identifier) {
            const mod_ptr = self.current.lexeme.ptr;
            var mod_len = self.current.lexeme.len;
            try self.expect(.Identifier);
            while (self.match(.Dot)) {
                mod_len = (@intFromPtr(self.current.lexeme.ptr) - @intFromPtr(mod_ptr)) + self.current.lexeme.len;
                try self.expect(.Identifier);
            }
            const dotted = mod_ptr[0..mod_len];
            if (level > 0) {
                const dots_buf = try self.allocator.alloc(u8, level);
                @memset(dots_buf, '.');
                mod = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ dots_buf, dotted });
            } else {
                mod = dotted;
            }
        } else if (level > 0) {
            const dots_buf = try self.allocator.alloc(u8, level);
            @memset(dots_buf, '.');
            mod = dots_buf;
        } else {
            if (!self.quiet) std.debug.print("ParseError on line {d}: expected module name or '.' after 'from'\n", .{self.current.line});
            return error.ParseError;
        }
    }

    try self.expect(.KeywordImport);
    var nodes: std.ArrayList(*ast.Node) = .empty;
    const is_paren = self.match(.LParen);

    while (true) {
        if (is_paren) {
            while (self.match(.Newline)) {}
            if (self.match(.RParen)) break;
        }
        var name: []const u8 = undefined;
        if (self.match(.Star)) {
            name = "*";
        } else {
            name = self.current.lexeme;
            try self.expect(.Identifier);
        }
        var alias: ?[]const u8 = null;
        if (self.match(.KeywordAs)) {
            alias = self.current.lexeme;
            try self.expect(.Identifier);
        }
        const node = try self.allocator.create(ast.Node);
        node.* = .{ .from_import = .{ .module = mod, .name = name, .alias = alias, .level = level } };
        try nodes.append(self.allocator, node);

        if (is_paren) {
            while (self.match(.Newline)) {}
            if (self.match(.RParen)) break;
            if (!self.match(.Comma)) {
                while (self.match(.Newline)) {}
                if (self.match(.RParen)) break;
                if (!self.quiet) std.debug.print("ParseError on line {d}: expected ',' or ')' in import list\n", .{self.current.line});
                return error.ParseError;
            }
        } else {
            if (!self.match(.Comma)) break;
        }
    }

    try self.consumeStmtEnd();
    if (nodes.items.len == 1) return nodes.items[0];
    const comp = try self.allocator.create(ast.Node);
    comp.* = .{ .compound_stmt = .{ .items = nodes } };
    return comp;
}
