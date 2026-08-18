const std = @import("std");

pub const token_mod = @import("token.zig");
pub const TokenType = token_mod.TokenType;
pub const Token = token_mod.Token;

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    pos: usize,
    line: usize,
    indents: std.ArrayList(usize),
    pending_tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        var indents: std.ArrayList(usize) = .empty;
        indents.append(allocator, 0) catch unreachable;
        return Lexer{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .line = 1,
            .indents = indents,
            .pending_tokens = .empty,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.indents.deinit(self.allocator);
        self.pending_tokens.deinit(self.allocator);
    }

    fn peek(self: *Lexer) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.peek();
        self.pos += 1;
        return c;
    }

    pub fn nextToken(self: *Lexer) Token {
        if (self.pending_tokens.items.len > 0) {
            return self.pending_tokens.orderedRemove(0);
        }

        while (self.pos < self.source.len) {
            const c = self.peek();
            
            if (c == ' ' or c == '\t') {
                _ = self.advance();
                continue;
            }

            if (c == '\r') {
                _ = self.advance();
                continue;
            }

            if (c == '\n') {
                _ = self.advance();
                self.line += 1;
                
                var indent: usize = 0;
                while (self.peek() == ' ' or self.peek() == '\t') {
                    if (self.peek() == ' ') indent += 1;
                    if (self.peek() == '\t') indent += 4;
                    _ = self.advance();
                }

                if (self.peek() == '\n' or self.peek() == '\r' or self.peek() == 0) {
                    continue; 
                }
                
                // If it's a comment but NOT #strict, we skip indentation check
                if (self.peek() == '#') {
                    // Check if it's #strict
                    var is_strict = false;
                    if (self.pos + 7 <= self.source.len and std.mem.eql(u8, self.source[self.pos..self.pos+7], "#strict")) {
                        is_strict = true;
                    }
                    if (!is_strict) {
                        continue;
                    }
                }

                const current_indent = self.indents.items[self.indents.items.len - 1];
                if (indent > current_indent) {
                    self.indents.append(self.allocator, indent) catch unreachable;
                    self.pending_tokens.append(self.allocator, .{ .type = .Indent, .lexeme = "", .line = self.line }) catch unreachable;
                } else if (indent < current_indent) {
                    while (self.indents.items.len > 1 and self.indents.items[self.indents.items.len - 1] > indent) {
                        _ = self.indents.pop();
                        self.pending_tokens.append(self.allocator, .{ .type = .Dedent, .lexeme = "", .line = self.line }) catch unreachable;
                    }
                }
                return .{ .type = .Newline, .lexeme = "\\n", .line = self.line - 1 };
            }

            if (c == '#') {
                const start = self.pos; // include the '#' character
                while (self.peek() != '\n' and self.peek() != 0) {
                    _ = self.advance();
                }
                const lexeme = self.source[start..self.pos];
                if (std.mem.eql(u8, lexeme, "#strict")) {
                    return .{ .type = .DirectiveStrict, .lexeme = lexeme, .line = self.line };
                }
                continue;
            }

            if (std.ascii.isAlphabetic(c) or c == '_') {
                const start = self.pos;
                if ((c == 'f' or c == 'F') and self.pos + 1 < self.source.len and (self.source[self.pos + 1] == '"' or self.source[self.pos + 1] == '\'')) {
                    _ = self.advance(); // consume f
                    const quote = self.advance(); // consume quote
                    const fstr_start = self.pos;
                    while (self.peek() != quote and self.peek() != 0) {
                        _ = self.advance();
                    }
                    const lexeme = self.source[fstr_start..self.pos];
                    if (self.peek() == quote) _ = self.advance();
                    return .{ .type = .FString, .lexeme = lexeme, .line = self.line };
                }
                while (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_') {
                    _ = self.advance();
                }
                const lexeme = self.source[start..self.pos];
                const tType = @import("lexer_keyword.zig").matchKeyword(lexeme);
                return .{ .type = tType, .lexeme = lexeme, .line = self.line };
            }

            if (std.ascii.isDigit(c)) {
                const start = self.pos;
                var is_float = false;
                while (std.ascii.isDigit(self.peek())) {
                    _ = self.advance();
                }
                if (self.peek() == '.') {
                    is_float = true;
                    _ = self.advance();
                    while (std.ascii.isDigit(self.peek())) {
                        _ = self.advance();
                    }
                }
                const lexeme = self.source[start..self.pos];
                return .{ .type = if (is_float) .Float else .Integer, .lexeme = lexeme, .line = self.line };
            }

            if (c == '"' or c == '\'') {
                const quote = self.advance();
                const start = self.pos;
                while (self.peek() != quote and self.peek() != 0) {
                    _ = self.advance();
                }
                const lexeme = self.source[start..self.pos];
                if (self.peek() == quote) _ = self.advance();
                return .{ .type = .String, .lexeme = lexeme, .line = self.line };
            }

            const start = self.pos;
            const ch = self.advance();
            switch (ch) {
                '+' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .PlusEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Plus, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '-' => {
                    if (self.peek() == '>') {
                        _ = self.advance();
                        return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Minus, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '*' => {
                    if (self.peek() == '*') {
                        _ = self.advance();
                        return .{ .type = .StarStar, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .StarEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Star, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '/' => {
                    if (self.peek() == '/') {
                        _ = self.advance();
                        return .{ .type = .SlashSlash, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .SlashEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Slash, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '%' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .PercentEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Percent, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '!' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .BangEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line }; // Fallback
                },
                '=' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .EqEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Eq, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '<' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .LtEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    } else if (self.peek() == '<') {
                        _ = self.advance();
                        return .{ .type = .LtLt, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Lt, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '>' => {
                    if (self.peek() == '=') {
                        _ = self.advance();
                        return .{ .type = .GtEq, .lexeme = self.source[start..self.pos], .line = self.line };
                    } else if (self.peek() == '>') {
                        _ = self.advance();
                        return .{ .type = .GtGt, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Gt, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '|' => return .{ .type = .Pipe, .lexeme = self.source[start..self.pos], .line = self.line },
                '^' => return .{ .type = .Caret, .lexeme = self.source[start..self.pos], .line = self.line },
                '&' => return .{ .type = .Ampersand, .lexeme = self.source[start..self.pos], .line = self.line },
                '~' => return .{ .type = .Tilde, .lexeme = self.source[start..self.pos], .line = self.line },
                ':' => return .{ .type = .Colon, .lexeme = self.source[start..self.pos], .line = self.line },
                ';' => return .{ .type = .Semicolon, .lexeme = self.source[start..self.pos], .line = self.line },
                ',' => return .{ .type = .Comma, .lexeme = self.source[start..self.pos], .line = self.line },
                '.' => return .{ .type = .Dot, .lexeme = self.source[start..self.pos], .line = self.line },
                '(' => return .{ .type = .LParen, .lexeme = self.source[start..self.pos], .line = self.line },
                ')' => return .{ .type = .RParen, .lexeme = self.source[start..self.pos], .line = self.line },
                '[' => return .{ .type = .LBracket, .lexeme = self.source[start..self.pos], .line = self.line },
                ']' => return .{ .type = .RBracket, .lexeme = self.source[start..self.pos], .line = self.line },
                '{' => return .{ .type = .LBrace, .lexeme = self.source[start..self.pos], .line = self.line },
                '}' => return .{ .type = .RBrace, .lexeme = self.source[start..self.pos], .line = self.line },
                else => {
                    return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line };
                },
            }
        }

        while (self.indents.items.len > 1) {
            _ = self.indents.pop();
            self.pending_tokens.append(self.allocator, .{ .type = .Dedent, .lexeme = "", .line = self.line }) catch unreachable;
        }

        if (self.pending_tokens.items.len > 0) {
            return self.pending_tokens.orderedRemove(0);
        }

        return .{ .type = .EOF, .lexeme = "", .line = self.line };
    }
};
