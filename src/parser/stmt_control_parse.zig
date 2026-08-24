const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseTryStmt(self: *Parser) anyerror!*ast.Node {
    try self.expect(.Colon);
    const try_block = try self.parseBlock();
    
    var except_block: ?std.ArrayList(*ast.Node) = null;
    var except_type: ?[]const u8 = null;
    var except_as: ?[]const u8 = null;
    if (self.match(.KeywordExcept)) {
        if (self.current.type == .Identifier) {
            except_type = self.current.lexeme;
            self.advance();
            if (self.match(.KeywordAs)) {
                except_as = self.current.lexeme;
                self.advance();
            }
        }
        while (self.current.type != .Colon and self.current.type != .EOF) {
            self.advance();
        }
        try self.expect(.Colon);
        except_block = try self.parseBlock();
    }
    
    var finally_block: ?std.ArrayList(*ast.Node) = null;
    if (self.match(.KeywordFinally)) {
        try self.expect(.Colon);
        finally_block = try self.parseBlock();
    }
    
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .try_stmt = .{ .body = try_block, .except_branch = except_block, .except_type = except_type, .except_as = except_as, .finally_branch = finally_block } };
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
            const pattern = try self.parseExpr(.none);
            try self.expect(.Colon);
            const block = try self.parseBlock();
            cases.append(self.allocator, .{ .pattern = pattern, .body = block }) catch unreachable;
        } else {
            std.debug.print("ParseError: expected 'case' inside match block, got {any} ('{s}') on line {d}\n", .{self.current.type, self.current.lexeme, self.current.line});
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
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .while_stmt = .{ .condition = cond, .body = block } };
    return node;
}

pub fn parseForStmt(self: *Parser) anyerror!*ast.Node {
    const iter_name = self.current.lexeme;
    try self.expect(.Identifier);
    try self.expect(.KeywordIn);
    const iter = try self.parseExpr(.none);
    try self.expect(.Colon);
    const block = try self.parseBlock();
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .for_stmt = .{ .iterator = iter_name, .iterable = iter, .body = block } };
    return node;
}
