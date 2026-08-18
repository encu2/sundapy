const std = @import("std");
const ast = @import("../core/ast.zig");
const lexer = @import("../lexer/lexer.zig");
const Parser = @import("parser.zig").Parser;
const Precedence = @import("parser.zig").Precedence;
const TokenType = lexer.TokenType;

    pub fn parseExpr(self: *Parser, precedence: Precedence) anyerror!*ast.Node {
        var left = try @import("expr_prefix.zig").parsePrefix(self);

        while (@intFromEnum(precedence) < @intFromEnum(Parser.getPrecedence(self.current.type))) {
            left = try @import("expr_infix.zig").parseInfix(self, left);
        }

        return left;
    }
