const std = @import("std");
const ast = @import("../core/ast.zig");
const lexer_mod = @import("../lexer/lexer.zig");
const Lexer = lexer_mod.Lexer;
const Token = lexer_mod.Token;
const TokenType = lexer_mod.TokenType;

pub const Precedence = enum(u8) {
    none = 0,
    assignment = 1,
    logicalOr = 2,
    logicalAnd = 3,
    bitwiseOr = 4,
    bitwiseXor = 5,
    bitwiseAnd = 6,
    equality = 7,
    comparison = 8,
    shift = 9,
    term = 10,
    factor = 11,
    call = 12,
    primary = 13,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: *Lexer,
    current: Token,
    peek_token: Token,

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {
        var p = Parser{
            .allocator = allocator,
            .lexer = lexer,
            .current = undefined,
            .peek_token = undefined,
        };
        p.current = p.lexer.nextToken();
        p.peek_token = p.lexer.nextToken();
        return p;
    }

    pub fn advance(self: *Parser) void {
        self.current = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    pub fn match(self: *Parser, t: TokenType) bool {
        if (self.current.type == t) {
            self.advance();
            return true;
        }
        return false;
    }

    pub fn expect(self: *Parser, t: TokenType) !void {
        if (self.current.type == t) {
            self.advance();
        } else {
            std.debug.print("ParseError in expect. Expected {any}, got {any} '{s}'\n", .{t, self.current.type, self.current.lexeme});
            return error.ParseError;
        }
    }

    pub fn getPrecedence(t: TokenType) Precedence {
        return switch (t) {
            .KeywordIf => .assignment,
            .KeywordOr => .logicalOr,
            .KeywordAnd => .logicalAnd,
            .Pipe => .bitwiseOr,
            .Caret => .bitwiseXor,
            .Ampersand => .bitwiseAnd,
            .EqEq, .BangEq => .equality,
            .Lt, .Gt, .LtEq, .GtEq => .comparison,
            .LtLt, .GtGt => .shift,
            .Plus, .Minus => .term,
            .Star, .Slash, .SlashSlash, .Percent, .StarStar => .factor,
            .LParen, .Dot, .LBracket => .call,
            else => .none,
        };
    }

    pub fn parseProgram(self: *Parser) anyerror!std.ArrayList(*ast.Node) {
        var stmts: std.ArrayList(*ast.Node) = .empty;
        while (self.current.type != .EOF) {
            if (self.match(.Newline)) continue;
            if (self.match(.Semicolon)) continue;
            const stmt = try self.parseStmt();
            stmts.append(self.allocator, stmt) catch unreachable;
        }
        return stmts;
    }

    pub const parseBlock = @import("stmt.zig").parseBlock;
    pub fn consumeStmtEnd(self: *Parser) !void {
        if (self.current.type == .Newline) return;
        if (self.match(.Semicolon)) return;
        if (self.current.type == .EOF or self.current.type == .Dedent) return;
        
        std.debug.print("ParseError: expected newline or semicolon at end of statement, got {any}\n", .{self.current.type});
        return error.ParseError;
    }

    pub const parseStmt = @import("stmt.zig").parseStmt;

    pub const parseExpr = @import("expr.zig").parseExpr;
};
