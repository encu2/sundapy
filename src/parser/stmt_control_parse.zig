const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseTryStmt(self: *Parser) anyerror!*ast.Node {
    try self.expect(.Colon);
    const try_block = try self.parseBlock();
    
    var except_clauses = std.ArrayList(ast.ExceptClause).empty;
    var first_except_block: ?std.ArrayList(*ast.Node) = null;
    var first_except_type: ?[]const u8 = null;
    var first_except_as: ?[]const u8 = null;
    var first_is_star = false;

    while (self.match(.KeywordExcept)) {
        var is_star = false;
        if (self.match(.Star)) {
            is_star = true;
        }
        var exc_type: ?[]const u8 = null;
        var exc_as: ?[]const u8 = null;
        if (self.current.type != .Colon) {
            const start_ptr = self.current.lexeme.ptr;
            var end_ptr = start_ptr + self.current.lexeme.len;
            if (self.current.type == .Identifier) {
                self.advance();
                end_ptr = self.current.lexeme.ptr;
                while (self.match(.Comma)) {
                    if (self.current.type == .Identifier) {
                        self.advance();
                        end_ptr = self.current.lexeme.ptr;
                    } else break;
                }
            } else if (self.current.type == .LParen) {
                self.advance();
                while (self.current.type != .RParen and self.current.type != .Colon and self.current.type != .EOF) {
                    end_ptr = self.current.lexeme.ptr + self.current.lexeme.len;
                    self.advance();
                }
                if (self.match(.RParen)) {
                    end_ptr = self.current.lexeme.ptr;
                }
            }
            const type_len = @intFromPtr(end_ptr) - @intFromPtr(start_ptr);
            exc_type = std.mem.trim(u8, start_ptr[0..type_len], " \t\r\n");

            if (self.match(.KeywordAs)) {
                if (self.current.type == .Identifier) {
                    exc_as = self.current.lexeme;
                    self.advance();
                }
            }
        }
        while (self.current.type != .Colon and self.current.type != .EOF) {
            self.advance();
        }
        try self.expect(.Colon);
        const block = try self.parseBlock();
        if (first_except_block == null) {
            first_except_block = block;
            first_except_type = exc_type;
            first_except_as = exc_as;
            first_is_star = is_star;
        }
        try except_clauses.append(self.allocator, .{
            .except_type = exc_type,
            .except_as = exc_as,
            .is_star = is_star,
            .body = block,
        });
    }
    
    var else_block: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordElse)) {
        try self.expect(.Colon);
        else_block = try self.parseBlock();
    }

    var finally_block: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordFinally)) {
        try self.expect(.Colon);
        finally_block = try self.parseBlock();
    }
    
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .try_stmt = .{
        .body = try_block,
        .except_clauses = except_clauses,
        .except_branch = first_except_block,
        .except_type = first_except_type,
        .except_as = first_except_as,
        .is_star = first_is_star,
        .finally_branch = finally_block,
        .else_branch = else_block,
    } };
    return node;
}

pub fn parseIfStmt(self: *Parser) anyerror!*ast.Node {
    const cond = try self.parseExpr(.none);
    try self.expect(.Colon);
    const block = try self.parseBlock();
    
    var elifs: std.ArrayList(ast.ElifBranch) = .empty;
    while (self.match(.KeywordElif)) {
        const econd = try self.parseExpr(.none);
        try self.expect(.Colon);
        const eblock = try self.parseBlock();
        elifs.append(self.allocator, .{ .condition = econd, .then_branch = eblock }) catch unreachable;
    }
    
    var else_branch: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordElse)) {
        try self.expect(.Colon);
        else_branch = try self.parseBlock();
    }
    
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .if_stmt = .{ .condition = cond, .then_branch = block, .elifs = elifs, .else_branch = else_branch } };
    return node;
}

pub fn parseMatchStmt(self: *Parser) anyerror!*ast.Node {
    const subject = try self.parseExpr(.none);
    try self.expect(.Colon);
    try self.expect(.Newline);
    try self.expect(.Indent);
    var cases: std.ArrayList(ast.CaseBranch) = .empty;
    while (self.current.type != .Dedent and self.current.type != .EOF) {
        if (self.match(.Newline)) continue;
        if (self.match(.KeywordCase)) {
            const pattern = try self.parseExpr(.logicalOr);
            var guard: ?*ast.Node = null;
            if (self.match(.KeywordIf)) {
                guard = try self.parseExpr(.none);
            }
            try self.expect(.Colon);
            const block = try self.parseBlock();
            cases.append(self.allocator, .{ .pattern = pattern, .guard = guard, .body = block }) catch unreachable;
        } else {
            if (!self.quiet) std.debug.print("ParseError: expected 'case' inside match block, got {any} ('{s}') on line {d}\n", .{self.current.type, self.current.lexeme, self.current.line});
            return error.ParseError;
        }
    }
    if (self.current.type == .Dedent) self.advance();
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .match_stmt = .{ .subject = subject, .cases = cases } };
    return node;
}

pub fn parseWhileStmt(self: *Parser) anyerror!*ast.Node {
    const cond = try self.parseExpr(.none);
    try self.expect(.Colon);
    const block = try self.parseBlock();
    var else_block: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordElse)) {
        try self.expect(.Colon);
        else_block = try self.parseBlock();
    }
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .while_stmt = .{ .condition = cond, .body = block, .else_body = else_block } };
    return node;
}

pub fn parseForStmt(self: *Parser, is_async: bool) anyerror!*ast.Node {
    
    const start_pos = self.current.lexeme.ptr;
    while (self.current.type != .KeywordIn and self.current.type != .EOF) {
        self.advance();
    }
    // actually, let's just do:
    const len = @intFromPtr(self.current.lexeme.ptr) - @intFromPtr(start_pos);
    const iter_name = start_pos[0..len];
    // advance over 'in'
    try self.expect(.KeywordIn);
    const iter = try self.parseExpr(.none);
    try self.expect(.Colon);
    const block = try self.parseBlock();
    var else_block: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordElse)) {
        try self.expect(.Colon);
        else_block = try self.parseBlock();
    }
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .for_stmt = .{ .is_async = is_async, .iterator = iter_name, .iterable = iter, .body = block, .else_body = else_block } };
    return node;
}

pub fn parseWithStmt(self: *Parser, is_async: bool) anyerror!*ast.Node {
    const context_expr = try self.parseExpr(.none);
    var as_name: ?[]const u8 = null;
    if (self.match(.KeywordAs)) {
        as_name = self.current.lexeme;
        try self.expect(.Identifier);
    }
    try self.expect(.Colon);
    const body = try self.parseBlock();
    
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .with_stmt = .{ .context_expr = context_expr, .as_name = as_name, .body = body, .is_async = is_async } };
    return node;
}

