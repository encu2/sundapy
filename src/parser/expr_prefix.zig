const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parsePrefix(self: *Parser) anyerror!*ast.Node {
    const node = try self.allocator.create(ast.Node);
    switch (self.current.type) {
        .Minus, .KeywordNot, .Tilde, .Plus => {
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
        .String => {
            node.* = .{ .string = self.current.lexeme };
            self.advance();
        },
        .FString => {
            node.* = .{ .fstring = .{ .value = self.current.lexeme } };
            self.advance();
        },
        .Identifier => {
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
            if (self.current.type == .KeywordFor) {
                self.advance();
                const target = self.current.lexeme;
                try self.expect(.Identifier);
                try self.expect(.KeywordIn);
                const iterable = try self.parseExpr(.assignment);
                var condition: ?*ast.Node = null;
                if (self.current.type == .KeywordIf) {
                    self.advance();
                    condition = try self.parseExpr(.none);
                }
                try self.expect(.RBracket);
                node.* = .{ .list_comp = .{ .expression = first_expr, .target = target, .iterable = iterable, .condition = condition } };
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
            const inner = try self.parseExpr(.none);
            try self.expect(.RParen);
            return inner;
        },
        .LBrace => {
            self.advance();
            var keys: std.ArrayList(*ast.Node) = .empty;
            var values: std.ArrayList(*ast.Node) = .empty;
            while (self.current.type != .RBrace) {
                keys.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                try self.expect(.Colon);
                values.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                if (self.match(.Comma)) {}
            }
            try self.expect(.RBrace);
            node.* = .{ .dict_expr = .{ .keys = keys, .values = values } };
        },
        else => {
            std.debug.print("ParseError on line {d} (parsePrefix): Token: {any} '{s}'\n", .{self.current.line, self.current.type, self.current.lexeme});
            return error.ParseError;
        }
    }
    return node;
}
