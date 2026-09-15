const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parsePrefix(self: *Parser) anyerror!*ast.Node {
    const node = try self.allocator.create(ast.Node);
    switch (self.current.type) {
        .Minus, .KeywordNot, .Tilde, .Plus, .Star, .StarStar => {
            const op = self.current.lexeme;
            self.advance();
            const right = try parsePrefix(self);
            node.* = .{ .unary = .{ .op = op, .right = right } };
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
            node.* = .{ .float = self.current.lexeme };
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
            var is_async_comp = false;
            if (self.current.type == .KeywordAsync and self.peek_token.type == .KeywordFor) {
                is_async_comp = true;
                self.advance(); // consume async
            }
            if (self.current.type == .KeywordFor) {
                self.advance(); // consume for
                const target_name = self.current.lexeme;
                try self.expect(.Identifier);
                try self.expect(.KeywordIn);
                // Parse iterable with .logicalOr precedence to stop before 'if' keyword
                const iter_expr = try self.parseExpr(.logicalOr);
                var cond: ?*ast.Node = null;
                if (self.current.type == .KeywordIf) {
                    self.advance();
                    // Parse filter condition with .logicalOr precedence to stop before ']' or 'for'
                    cond = try self.parseExpr(.logicalOr);
                }
                try self.expect(.RBracket);
                node.* = .{ .list_comp = .{
                    .expression = first_expr,
                    .target = target_name,
                    .iterable = iter_expr,
                    .condition = cond,
                    .is_async = is_async_comp,
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
                
                var is_async_comp = false;
                if (self.current.type == .KeywordAsync and self.peek_token.type == .KeywordFor) {
                    is_async_comp = true;
                    self.advance();
                }
                if (self.current.type == .KeywordFor) {
                    var depth: usize = 1;
                    while (self.current.type != .EOF) {
                        if (self.current.type == .LParen) depth += 1;
                        if (self.current.type == .RParen) {
                            depth -= 1;
                            if (depth == 0) {
                                self.advance();
                                break;
                            }
                        }
                        self.advance();
                    }
                    node.* = .{ .dummy_expr = .{ .desc = "generator_comprehension" } };
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
                node.* = .{ .list_expr = .{ .items = items } };
                return node;
            }
            return items.items[0];
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
            var val: ?*ast.Node = null;
            if (self.match(.KeywordFrom)) {
                val = try self.parseExpr(.none);
            } else if (self.current.type != .Newline and self.current.type != .RParen and self.current.type != .Semicolon and self.current.type != .RBracket and self.current.type != .RBrace) {
                val = try self.parseExpr(.none);
            }
            node.* = .{ .yield_expr = .{ .value = val } };
        },
        .KeywordLambda => {
            // lambda args: body -- consume until newline or closing bracket
            // We stub lambda as dummy_expr since it requires generator/closure support
            while (self.current.type != .Newline and
                   self.current.type != .Semicolon and
                   self.current.type != .Comma and
                   self.current.type != .RParen and
                   self.current.type != .RBracket and
                   self.current.type != .RBrace and
                   self.current.type != .EOF)
            {
                self.advance();
            }
            node.* = .{ .dummy_expr = .{ .desc = "lambda" } };
        },
        else => {
            std.debug.print("ParseError on line {d} (parsePrefix): Token: {any} '{s}'\n", .{self.current.line, self.current.type, self.current.lexeme});
            return error.ParseError;
        }
    }
    return node;
}
