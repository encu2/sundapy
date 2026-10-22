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
    paren_level: usize,

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
            .paren_level = 0,
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

    fn lexStringLiteral(self: *Lexer, quote: u8) []const u8 {
        const is_triple = (self.peek() == quote and self.pos + 1 < self.source.len and self.source[self.pos + 1] == quote);
        if (is_triple) {
            _ = self.advance();
            _ = self.advance();
            const s_start = self.pos;
            while (self.pos + 2 < self.source.len) {
                if (self.source[self.pos] == quote and self.source[self.pos + 1] == quote and self.source[self.pos + 2] == quote) {
                    const lex = self.source[s_start..self.pos];
                    self.pos += 3;
                    return lex;
                }
                if (self.peek() == '\n') self.line += 1;
                _ = self.advance();
            }
            const lex = self.source[s_start..self.pos];
            return lex;
        } else {
            const s_start = self.pos;
            while (self.peek() != quote and self.peek() != 0 and self.peek() != '\n') {
                if (self.peek() == '\\' and self.pos + 1 < self.source.len) {
                    _ = self.advance();
                }
                _ = self.advance();
            }
            const lex = self.source[s_start..self.pos];
            if (self.peek() == quote) _ = self.advance();
            return lex;
        }
    }

    fn lexRawStringLiteral(self: *Lexer, quote: u8) []const u8 {
        const raw = self.lexStringLiteral(quote);
        var out: std.ArrayList(u8) = .empty;
        for (raw) |ch| {
            if (ch == '\\') out.appendSlice(self.allocator, "\\\\") catch unreachable
            else out.append(self.allocator, ch) catch unreachable;
        }
        return out.items;
    }

    pub fn nextToken(self: *Lexer) Token {
        if (self.pending_tokens.items.len > 0) {
            return self.pending_tokens.orderedRemove(0);
        }

        while (self.pos < self.source.len) {
            const c = self.peek();
            
            if (c == '\\') {
                _ = self.advance();
                if (self.peek() == '\n') {
                    _ = self.advance();
                    self.line += 1;
                } else if (self.peek() == '\r') {
                    _ = self.advance();
                    if (self.peek() == '\n') {
                        _ = self.advance();
                    }
                    self.line += 1;
                }
                continue;
            }

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
                
                if (self.paren_level > 0) {
                    continue;
                }
                
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
                if (std.mem.startsWith(u8, lexeme, "#@link:") or std.mem.startsWith(u8, lexeme, "# @link:")) {
                    const colon_pos = std.mem.indexOfScalar(u8, lexeme, ':').?;
                    const libs_str = lexeme[colon_pos + 1 ..];
                    var it = std.mem.splitScalar(u8, libs_str, ',');
                    while (it.next()) |raw_lib| {
                        const lib = std.mem.trim(u8, raw_lib, " \t\r\n");
                        if (lib.len > 0) {
                            @import("../core/compiler.zig").addLinkLib(self.allocator, lib) catch {};
                        }
                    }
                }
                continue;
            }

            if (std.ascii.isAlphabetic(c) or c == '_') {
                const start = self.pos;
                if ((c == 'f' or c == 'F') and self.pos + 1 < self.source.len and (self.source[self.pos + 1] == '"' or self.source[self.pos + 1] == '\'')) {
                    _ = self.advance(); // consume f
                    const quote = self.advance(); // consume quote
                    const lexeme = self.lexStringLiteral(quote);
                    return .{ .type = .FString, .lexeme = lexeme, .line = self.line };
                }
                if ((c == 't' or c == 'T' or c == 'd' or c == 'D') and self.pos + 1 < self.source.len and (self.source[self.pos + 1] == '"' or self.source[self.pos + 1] == '\'')) {
                    const is_tmpl = (c == 't' or c == 'T');
                    _ = self.advance();
                    const quote = self.advance();
                    const lexeme = self.lexStringLiteral(quote);
                    return .{ .type = if (is_tmpl) .TString else .DString, .lexeme = lexeme, .line = self.line };
                }
                if (self.pos + 2 < self.source.len and (self.source[self.pos + 2] == '"' or self.source[self.pos + 2] == '\'')) {
                    const c2 = self.source[self.pos + 1];
                    const is_rb = (c == 'r' or c == 'R') and (c2 == 'b' or c2 == 'B');
                    const is_br = (c == 'b' or c == 'B') and (c2 == 'r' or c2 == 'R');
                    if (is_rb or is_br) {
                        _ = self.advance();
                        _ = self.advance();
                        const quote = self.advance();
                        return .{ .type = .String, .lexeme = self.lexRawStringLiteral(quote), .line = self.line };
                    }
                }
                if ((c == 'b' or c == 'B' or c == 'r' or c == 'R' or c == 'u' or c == 'U') and self.pos + 1 < self.source.len and (self.source[self.pos + 1] == '"' or self.source[self.pos + 1] == '\'')) {
                    const is_raw = (c == 'r' or c == 'R');
                    _ = self.advance();
                    const quote = self.advance();
                    const lexeme = if (is_raw) self.lexRawStringLiteral(quote) else self.lexStringLiteral(quote);
                    return .{ .type = .String, .lexeme = lexeme, .line = self.line };
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
                while (std.ascii.isDigit(self.peek()) or self.peek() == '_' or self.peek() == 'x' or self.peek() == 'X' or self.peek() == 'b' or self.peek() == 'B' or self.peek() == 'o' or self.peek() == 'O' or (self.peek() >= 'a' and self.peek() <= 'f') or (self.peek() >= 'A' and self.peek() <= 'F')) {
                    _ = self.advance();
                }
                if (self.peek() == '.' and !(self.pos + 2 < self.source.len and self.source[self.pos + 1] == '.' and self.source[self.pos + 2] == '.')) {
                    is_float = true;
                    _ = self.advance();
                    while (std.ascii.isDigit(self.peek()) or self.peek() == '_') {
                        _ = self.advance();
                    }
                }
                if (self.peek() == 'e' or self.peek() == 'E') {
                    is_float = true;
                    _ = self.advance();
                    if (self.peek() == '+' or self.peek() == '-') {
                        _ = self.advance();
                    }
                    while (std.ascii.isDigit(self.peek()) or self.peek() == '_') {
                        _ = self.advance();
                    }
                }
                const lexeme = self.source[start..self.pos];
                return .{ .type = if (is_float) .Float else .Integer, .lexeme = lexeme, .line = self.line };
            }

            if (c == '"' or c == '\'') {
                const quote = self.advance();
                const lexeme = self.lexStringLiteral(quote);
                return .{ .type = .String, .lexeme = lexeme, .line = self.line };
            }

            const start = self.pos;
            const ch = self.advance();
            switch (ch) {
                '+' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .PlusEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Plus, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '-' => {
                    if (self.peek() == '>') { _ = self.advance(); return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .MinusEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Minus, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '*' => {
                    if (self.peek() == '*') { _ = self.advance(); return .{ .type = .StarStar, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .StarEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Star, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '/' => {
                    if (self.peek() == '/') { _ = self.advance(); return .{ .type = .SlashSlash, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .SlashEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Slash, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '%' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .PercentEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Percent, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '!' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .BangEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '=' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .EqEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Eq, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '<' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .LtEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '<') { _ = self.advance(); return .{ .type = .LtLt, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Lt, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '>' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .GtEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '>') { _ = self.advance(); return .{ .type = .GtGt, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Gt, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '|' => return .{ .type = .Pipe, .lexeme = self.source[start..self.pos], .line = self.line },
                '^' => return .{ .type = .Caret, .lexeme = self.source[start..self.pos], .line = self.line },
                '&' => return .{ .type = .Ampersand, .lexeme = self.source[start..self.pos], .line = self.line },
                '~' => return .{ .type = .Tilde, .lexeme = self.source[start..self.pos], .line = self.line },
                ':' => {
                    if (self.peek() == '=') { _ = self.advance(); return .{ .type = .ColonEq, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Colon, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                ';' => return .{ .type = .Semicolon, .lexeme = self.source[start..self.pos], .line = self.line },
                ',' => return .{ .type = .Comma, .lexeme = self.source[start..self.pos], .line = self.line },
                '.' => {
                    if (self.peek() == '.' and self.pos + 1 < self.source.len and self.source[self.pos + 1] == '.') {
                        _ = self.advance();
                        _ = self.advance();
                        return .{ .type = .Ellipsis, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    if (std.ascii.isDigit(self.peek())) {
                        while (std.ascii.isDigit(self.peek()) or self.peek() == '_') _ = self.advance();
                        if (self.peek() == 'e' or self.peek() == 'E') {
                            _ = self.advance();
                            if (self.peek() == '+' or self.peek() == '-') _ = self.advance();
                            while (std.ascii.isDigit(self.peek()) or self.peek() == '_') _ = self.advance();
                        }
                        return .{ .type = .Float, .lexeme = self.source[start..self.pos], .line = self.line };
                    }
                    return .{ .type = .Dot, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '?' => {
                    if (self.peek() == '.') { _ = self.advance(); return .{ .type = .QuestionDot, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    if (self.peek() == '?') { _ = self.advance(); return .{ .type = .QuestionQuestion, .lexeme = self.source[start..self.pos], .line = self.line }; }
                    return .{ .type = .Identifier, .lexeme = self.source[start..self.pos], .line = self.line };
                },
                '@' => return .{ .type = .At, .lexeme = self.source[start..self.pos], .line = self.line },
                '(' => { self.paren_level += 1; return .{ .type = .LParen, .lexeme = self.source[start..self.pos], .line = self.line }; },
                ')' => { if (self.paren_level > 0) self.paren_level -= 1; return .{ .type = .RParen, .lexeme = self.source[start..self.pos], .line = self.line }; },
                '[' => { self.paren_level += 1; return .{ .type = .LBracket, .lexeme = self.source[start..self.pos], .line = self.line }; },
                ']' => { if (self.paren_level > 0) self.paren_level -= 1; return .{ .type = .RBracket, .lexeme = self.source[start..self.pos], .line = self.line }; },
                '{' => { self.paren_level += 1; return .{ .type = .LBrace, .lexeme = self.source[start..self.pos], .line = self.line }; },
                '}' => { if (self.paren_level > 0) self.paren_level -= 1; return .{ .type = .RBrace, .lexeme = self.source[start..self.pos], .line = self.line }; },
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
