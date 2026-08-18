const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseDefStmt(self: *Parser) anyerror!*ast.Node {
    const name = self.current.lexeme;
    try self.expect(.Identifier);
    try self.expect(.LParen);
    var params: std.ArrayList(ast.Param) = .empty;
    while (self.current.type != .RParen) {
        const p_name = self.current.lexeme;
        try self.expect(.Identifier);
        var p_type: ?[]const u8 = null;
        if (self.match(.Colon)) {
            if (self.current.type == .Identifier) {
                p_type = self.current.lexeme;
                self.advance();
            } else if (self.current.type == .KeywordNone) {
                p_type = "None";
                self.advance();
            } else {
                return error.ParseError;
            }
        }
        params.append(self.allocator, .{ .name = p_name, .type_ann = p_type }) catch unreachable;
        if (self.match(.Comma)) {}
    }
    try self.expect(.RParen);
    var ret_type: ?[]const u8 = null;
    if (self.current.type == .Identifier and std.mem.eql(u8, self.current.lexeme, "->")) {
        self.advance();
        if (self.current.type == .Identifier) {
            ret_type = self.current.lexeme;
            self.advance();
        } else if (self.current.type == .KeywordNone) {
            ret_type = "None";
            self.advance();
        }
    } else if (self.match(.Minus)) { 
        _ = try self.parseExpr(.none);
    }
    try self.expect(.Colon);
    const block = try self.parseBlock();
    var is_strict = false;
    if (block.items.len > 0 and block.items[0].* == .directive_strict) {
        is_strict = true;
    }
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .def_stmt = .{ .name = name, .params = params, .return_type = ret_type, .body = block, .is_strict = is_strict } };
    return node;
}

pub fn parseClassStmt(self: *Parser) anyerror!*ast.Node {
    const name = self.current.lexeme;
    try self.expect(.Identifier);
    var base_class: ?[]const u8 = null;
    if (self.match(.LParen)) {
        base_class = self.current.lexeme;
        try self.expect(.Identifier);
        try self.expect(.RParen);
    }
    try self.expect(.Colon);
    const block = try self.parseBlock();
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .class_stmt = .{ .name = name, .base_class = base_class, .methods = block } };
    return node;
}
