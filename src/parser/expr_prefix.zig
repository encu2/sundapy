const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parsePrefix(self: *Parser) anyerror!*ast.Node {
    const node = try self.allocator.create(ast.Node);
    switch (self.current.type) {
        .Minus, .KeywordNot, .Tilde, .Plus, .Star, .StarStar => {
            const op = self.current.lexeme;
            const t = self.current.type;
            self.advance();
            const right = if (t == .KeywordNot)
                try self.parseExpr(.logicalOr)
            else
                try self.parseExpr(.factor);
            if (t == .Star) {
                node.* = .{ .starred = .{ .value = right } };
            } else {
                node.* = .{ .unary = .{ .op = op, .right = right } };
            }
        },
        .KeywordAwait => {
            self.advance();
            const right = try self.parseExpr(.none);
            node.* = .{ .await_expr = .{ .value = right } };
        },
        .Integer => {
            node.* = .{ .integer = self.current.lexeme };
            self.advance();
        },
        .Float => {
            const f_raw = self.current.lexeme;
            var f_norm: []const u8 = f_raw;
            if (f_raw.len > 0 and f_raw[0] == '.') {
                f_norm = try std.fmt.allocPrint(self.allocator, "0{s}", .{f_raw});
            } else if (f_raw.len > 0 and f_raw[f_raw.len - 1] == '.') {
                f_norm = try std.fmt.allocPrint(self.allocator, "{s}0", .{f_raw});
            } else if (std.mem.indexOf(u8, f_raw, ".e")) |idx| {
                f_norm = try std.fmt.allocPrint(self.allocator, "{s}.0e{s}", .{ f_raw[0..idx], f_raw[idx + 2 ..] });
            } else if (std.mem.indexOf(u8, f_raw, ".E")) |idx| {
                f_norm = try std.fmt.allocPrint(self.allocator, "{s}.0E{s}", .{ f_raw[0..idx], f_raw[idx + 2 ..] });
            }
            node.* = .{ .float = f_norm };
            self.advance();
        },
        .String, .FString => {
            var has_fstring = self.current.type == .FString;
            var total_len: usize = self.current.lexeme.len;
            var parts: std.ArrayList([]const u8) = .empty;
            parts.append(self.allocator, self.current.lexeme) catch unreachable;
            self.advance();
            while (self.current.type == .String or self.current.type == .FString) {
                if (self.current.type == .FString) has_fstring = true;
                parts.append(self.allocator, self.current.lexeme) catch unreachable;
                total_len += self.current.lexeme.len;
                self.advance();
            }
            
            var merged = self.allocator.alloc(u8, total_len) catch unreachable;
            var offset: usize = 0;
            for (parts.items) |part| {
                @memcpy(merged[offset..offset+part.len], part);
                offset += part.len;
            }
            
            if (has_fstring) {
                node.* = .{ .fstring = .{ .value = merged } };
            } else {
                node.* = .{ .string = merged };
            }
        },
        .TString => {
            const val = self.current.lexeme;
            self.advance();
            node.* = .{ .tstring = .{ .value = val } };
        },
        .DString => {
            const val = self.current.lexeme;
            self.advance();
            node.* = .{ .dstring = .{ .value = val } };
        },
        .Ellipsis => {
            self.advance();
            node.* = .ellipsis;
            return node;
        },
        .Identifier, .KeywordMatch => {
            node.* = .{ .identifier = .{ .name = self.current.lexeme } };
            self.advance();
        },
        .KeywordTrue => {
            node.* = .{ .identifier = .{ .name = "True" } }; 
            self.advance();
        },
        .KeywordFalse => {
            node.* = .{ .identifier = .{ .name = "False" } }; 
            self.advance();
        },
        .KeywordNone => {
            node.* = .none;
            self.advance();
        },
        .LBracket => {
            self.advance();
            if (self.current.type == .RBracket) {
                self.advance();
                node.* = .{ .list_expr = .{ .items = .empty } };
                return node;
            }
            const first_expr = try self.parseExpr(.none);
            if (self.current.type == .KeywordFor or (self.current.type == .KeywordAsync and self.peek_token.type == .KeywordFor)) {
                const clauses = try parseCompClauses(self);
                try self.expect(.RBracket);
                node.* = .{ .list_comp = .{
                    .expression = first_expr,
                    .clauses = clauses,
                } };
            } else {
                var items: std.ArrayList(*ast.Node) = .empty;
                items.append(self.allocator, first_expr) catch unreachable;
                if (self.match(.Comma)) {}
                while (self.current.type != .RBracket) {
                    items.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                    if (self.match(.Comma)) {}
                }
                try self.expect(.RBracket);
                node.* = .{ .list_expr = .{ .items = items } };
            }
        },
        .LParen => {
            self.advance();
            var items: std.ArrayList(*ast.Node) = .empty;
            var is_tuple = false;
            
            if (self.current.type == .RParen) {
                // Empty tuple ()
                self.advance();
                is_tuple = true;
            } else {
                const first = try self.parseExpr(.none);
                if (self.current.type == .KeywordFor or (self.current.type == .KeywordAsync and self.peek_token.type == .KeywordFor)) {
                    const clauses = try parseCompClauses(self);
                    try self.expect(.RParen);
                    node.* = .{ .list_comp = .{
                        .expression = first,
                        .clauses = clauses,
                    } };
                    return node;
                }
                
                items.append(self.allocator, first) catch unreachable;
                
                if (self.match(.Comma)) {
                    is_tuple = true;
                    while (self.current.type != .RParen) {
                        items.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                        if (self.match(.Comma)) {}
                    }
                }
                try self.expect(.RParen);
            }
            
            if (is_tuple) {
                node.* = .{ .tuple_expr = .{ .items = items } };
                return node;
            }
            const single = items.items[0];
            if (single.* == .binary) {
                single.binary.is_parenthesized = true;
            }
            return single;
        },
        .LBrace => {
            self.advance();
            var keys: std.ArrayList(*ast.Node) = .empty;
            var values: std.ArrayList(*ast.Node) = .empty;
            var is_comprehension = false;
            while (self.current.type != .RBrace) {
                if (self.current.type == .KeywordFor) {
                    is_comprehension = true;
                    // eat until RBrace with brace counting
                    var brace_depth: i32 = 1;
                    while (brace_depth > 0 and self.current.type != .EOF) {
                        if (self.current.type == .LBrace) brace_depth += 1;
                        if (self.current.type == .RBrace) brace_depth -= 1;
                        if (brace_depth == 0) break;
                        self.advance();
                    }
                    break;
                }
                keys.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                // It could be a set comprehension! {x for x in y}
                if (self.current.type == .KeywordFor) {
                    is_comprehension = true;
                    var brace_depth: i32 = 1;
                    while (brace_depth > 0 and self.current.type != .EOF) {
                        if (self.current.type == .LBrace) brace_depth += 1;
                        if (self.current.type == .RBrace) brace_depth -= 1;
                        if (brace_depth == 0) break;
                        self.advance();
                    }
                    break;
                }
                
                // If it's just a set, not dict
                if (self.match(.Comma)) {
                    continue; // Set elements
                } else if (self.match(.Colon)) {
                    values.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                    if (self.current.type == .KeywordFor) {
                        is_comprehension = true;
                        var brace_depth: i32 = 1;
                        while (brace_depth > 0 and self.current.type != .EOF) {
                            if (self.current.type == .LBrace) brace_depth += 1;
                            if (self.current.type == .RBrace) brace_depth -= 1;
                            if (brace_depth == 0) break;
                            self.advance();
                        }
                        break;
                    }
                    _ = self.match(.Comma);
                } else {
                    if (self.current.type != .RBrace) {
                        return error.ParseError;
                    }
                }
            }
            try self.expect(.RBrace);
            if (is_comprehension) {
                node.* = .{ .dummy_expr = .{ .desc = "dict_comprehension" } };
            } else {
                node.* = .{ .dict_expr = .{ .keys = keys, .values = values } }; // Or set_expr if values is empty and keys isn't
            }
        },
        .KeywordYield => {
            self.advance();
            var is_from = false;
            var val: ?*ast.Node = null;
            if (self.match(.KeywordFrom)) {
                is_from = true;
                val = try self.parseExpr(.none);
            } else if (self.current.type != .Newline and self.current.type != .RParen and self.current.type != .Semicolon and self.current.type != .RBracket and self.current.type != .RBrace) {
                val = try self.parseExpr(.none);
            }
            node.* = .{ .yield_expr = .{ .value = val, .is_from = is_from } };
        },
        .KeywordLambda => {
            // lambda args: body -- consume until newline or closing delimiter at depth 0
            // We stub lambda as dummy_expr since it requires generator/closure support
            var paren_depth: usize = 0;
            var bracket_depth: usize = 0;
            var brace_depth: usize = 0;
            while (self.current.type != .EOF) {
                const t = self.current.type;
                if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) {
                    if (t == .Newline or t == .Semicolon or t == .Comma or t == .RParen or t == .RBracket or t == .RBrace) {
                        break;
                    }
                }
                if (t == .LParen) {
                    paren_depth += 1;
                } else if (t == .RParen) {
                    if (paren_depth > 0) paren_depth -= 1;
                } else if (t == .LBracket) {
                    bracket_depth += 1;
                } else if (t == .RBracket) {
                    if (bracket_depth > 0) bracket_depth -= 1;
                } else if (t == .LBrace) {
                    brace_depth += 1;
                } else if (t == .RBrace) {
                    if (brace_depth > 0) brace_depth -= 1;
                }
                self.advance();
            }
            node.* = .{ .dummy_expr = .{ .desc = "lambda" } };
        },
        else => {
            if (!self.quiet) {
                std.debug.print("ParseError on line {d} (parsePrefix): Token: {any} '{s}'\n", .{self.current.line, self.current.type, self.current.lexeme});
            }
            return error.ParseError;
        }
    }
    return node;
}

pub fn parseCompClauses(self: *Parser) !std.ArrayList(ast.CompClause) {
    var clauses = std.ArrayList(ast.CompClause).empty;
    while (self.current.type == .KeywordFor or (self.current.type == .KeywordAsync and self.peek_token.type == .KeywordFor)) {
        var is_async_comp = false;
        if (self.match(.KeywordAsync)) {
            is_async_comp = true;
        }
        self.advance(); // skip 'for'
        var targets_buf: std.ArrayList(u8) = .empty;
        while (true) {
            try targets_buf.appendSlice(self.allocator, self.current.lexeme);
            try self.expect(.Identifier);
            if (self.match(.Comma)) {
                try targets_buf.append(self.allocator, ',');
            } else break;
        }
        const target_name = targets_buf.items;
        try self.expect(.KeywordIn);
        const iter_expr = try self.parseExpr(.logicalOr);
        var cond: ?*ast.Node = null;
        while (self.current.type == .KeywordIf) {
            self.advance();
            const next_cond = try self.parseExpr(.logicalOr);
            if (cond) |c| {
                const bin = try self.allocator.create(ast.Node);
                bin.* = .{ .binary = .{ .op = "and", .left = c, .right = next_cond } };
                cond = bin;
            } else {
                cond = next_cond;
            }
        }
        try clauses.append(self.allocator, .{
            .target = target_name,
            .iterable = iter_expr,
            .condition = cond,
            .is_async = is_async_comp,
        });
    }
    return clauses;
}
