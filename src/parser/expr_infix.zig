const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseInfix(self: *Parser, left: *ast.Node) anyerror!*ast.Node {
    const node = try self.allocator.create(ast.Node);
    const t = self.current.type;
    const op = self.current.lexeme;
    
    if (t == .LParen) {
        self.advance(); 
        var args: std.ArrayList(*ast.Node) = .empty;
        var kwargs: std.ArrayList(ast.KeywordArg) = .empty;
        while (self.current.type != .RParen) {
            if (self.current.type == .Identifier and self.peek_token.type == .Eq) {
                const key = self.current.lexeme;
                self.advance(); // skip identifier
                self.advance(); // skip eq
                const val = try self.parseExpr(.none);
                kwargs.append(self.allocator, .{ .key = key, .value = val }) catch unreachable;
            } else {
                args.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
            }
            if (self.match(.Comma)) {}
        }
        try self.expect(.RParen);
        
        if (left.* == .getattr) {
            node.* = .{ .method_call = .{ .target = left.getattr.target, .method = left.getattr.attr, .args = args, .kwargs = kwargs } };
        } else {
            node.* = .{ .call = .{ .callee = left, .args = args, .kwargs = kwargs } };
        }
        return node;
    }
    
    if (t == .Dot) {
        self.advance();
        const attr = self.current.lexeme;
        try self.expect(.Identifier);
        node.* = .{ .getattr = .{ .target = left, .attr = attr } };
        return node;
    }
    
    if (t == .LBracket) {
        self.advance();
        var slice_start: ?*ast.Node = null;
        var slice_stop: ?*ast.Node = null;
        var slice_step: ?*ast.Node = null;
        var is_slice = false;

        if (self.current.type == .Colon) {
            is_slice = true;
            self.advance();
            if (self.current.type != .Colon and self.current.type != .RBracket) {
                slice_stop = try self.parseExpr(.none);
            }
            if (self.current.type == .Colon) {
                self.advance();
                if (self.current.type != .RBracket) {
                    slice_step = try self.parseExpr(.none);
                }
            }
        } else {
            const first = try self.parseExpr(.none);
            if (self.current.type == .Colon) {
                is_slice = true;
                slice_start = first;
                self.advance();
                if (self.current.type != .Colon and self.current.type != .RBracket) {
                    slice_stop = try self.parseExpr(.none);
                }
                if (self.current.type == .Colon) {
                    self.advance();
                    if (self.current.type != .RBracket) {
                        slice_step = try self.parseExpr(.none);
                    }
                }
            } else {
                if (self.current.type == .Comma) {
                    var items: std.ArrayList(*ast.Node) = .empty;
                    items.append(self.allocator, first) catch unreachable;
                    while (self.match(.Comma)) {
                        if (self.current.type == .RBracket) break;
                        items.append(self.allocator, try self.parseExpr(.none)) catch unreachable;
                    }
                    const tuple_node = try self.allocator.create(ast.Node);
                    tuple_node.* = .{ .list_expr = .{ .items = items } };
                    try self.expect(.RBracket);
                    node.* = .{ .subscript = .{ .target = left, .index = tuple_node } };
                    return node;
                }
                try self.expect(.RBracket);
                node.* = .{ .subscript = .{ .target = left, .index = first } };
                return node;
            }
        }

        try self.expect(.RBracket);
        node.* = .{ .slice = .{ .target = left, .start = slice_start, .stop = slice_stop, .step = slice_step } };
        return node;
    }


    
    if (t == .ColonEq) {
        self.advance();
        const right = try self.parseExpr(Parser.getPrecedence(.ColonEq));
        node.* = .{ .assign_expr = .{ .target = left, .value = right } };
        return node;
    }
    
    if (t == .KeywordIn) {
        self.advance();
        const right = try self.parseExpr(Parser.getPrecedence(.KeywordIn));
        node.* = .{ .binary = .{ .op = "in", .left = left, .right = right } };
        return node;
    }
    if (t == .KeywordIs) {
        self.advance();
        if (self.current.type == .KeywordNot) {
            self.advance();
            const right = try self.parseExpr(Parser.getPrecedence(.KeywordIs));
            node.* = .{ .binary = .{ .op = "is_not", .left = left, .right = right } };
            return node;
        } else {
            const right = try self.parseExpr(Parser.getPrecedence(.KeywordIs));
            node.* = .{ .binary = .{ .op = "is", .left = left, .right = right } };
            return node;
        }
    }
    if (t == .KeywordNot) {
        self.advance();
        if (self.current.type == .KeywordIn) {
            self.advance();
            const right = try self.parseExpr(Parser.getPrecedence(.KeywordNot));
            node.* = .{ .binary = .{ .op = "not_in", .left = left, .right = right } };
            return node;
        } else {
            return error.ParseError;
        }
    }

    if (t == .KeywordIf) {
        self.advance();
        const cond = try self.parseExpr(.none);
        try self.expect(.KeywordElse);
        const false_expr = try self.parseExpr(Parser.getPrecedence(.KeywordIf));
        node.* = .{ .ternary_expr = .{ .condition = cond, .true_expr = left, .false_expr = false_expr } };
        return node;
    }

    self.advance(); 
    const right = try self.parseExpr(Parser.getPrecedence(t));
    node.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
    return node;
}
