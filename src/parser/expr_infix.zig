const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

fn parseSliceOrExpr(self: *Parser, target_node: *ast.Node) anyerror!*ast.Node {
    if (self.current.type == .Colon) {
        self.advance();
        var slice_stop: ?*ast.Node = null;
        var slice_step: ?*ast.Node = null;
        if (self.current.type != .Colon and self.current.type != .Comma and self.current.type != .RBracket) {
            slice_stop = try self.parseExpr(.none);
        }
        if (self.match(.Colon)) {
            if (self.current.type != .Comma and self.current.type != .RBracket) {
                slice_step = try self.parseExpr(.none);
            }
        }
        const s_node = try self.allocator.create(ast.Node);
        s_node.* = .{ .slice = .{ .target = target_node, .start = null, .stop = slice_stop, .step = slice_step } };
        return s_node;
    }
    const first = try self.parseExpr(.none);
    if (self.match(.Colon)) {
        var slice_stop: ?*ast.Node = null;
        var slice_step: ?*ast.Node = null;
        if (self.current.type != .Colon and self.current.type != .Comma and self.current.type != .RBracket) {
            slice_stop = try self.parseExpr(.none);
        }
        if (self.match(.Colon)) {
            if (self.current.type != .Comma and self.current.type != .RBracket) {
                slice_step = try self.parseExpr(.none);
            }
        }
        const s_node = try self.allocator.create(ast.Node);
        s_node.* = .{ .slice = .{ .target = target_node, .start = first, .stop = slice_stop, .step = slice_step } };
        return s_node;
    }
    return first;
}

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
                var arg_expr = try self.parseExpr(.none);
                if (self.current.type == .KeywordFor) {
                    self.advance();
                    const target_name = self.current.lexeme;
                    try self.expect(.Identifier);
                    try self.expect(.KeywordIn);
                    const iter_expr = try self.parseExpr(.logicalOr);
                    var cond: ?*ast.Node = null;
                    if (self.current.type == .KeywordIf) {
                        self.advance();
                        cond = try self.parseExpr(.logicalOr);
                    }
                    const comp_node = try self.allocator.create(ast.Node);
                    comp_node.* = .{ .list_comp = .{
                        .expression = arg_expr,
                        .target = target_name,
                        .iterable = iter_expr,
                        .condition = cond,
                        .is_async = false,
                    } };
                    arg_expr = comp_node;
                }
                args.append(self.allocator, arg_expr) catch unreachable;
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
    
    if (t == .QuestionDot) {
        self.advance();
        const attr = self.current.lexeme;
        try self.expect(.Identifier);
        node.* = .{ .safe_getattr = .{ .target = left, .attr = attr } };
        return node;
    }

    if (t == .QuestionQuestion) {
        self.advance();
        const right = try self.parseExpr(.logicalOr);
        node.* = .{ .coalesce_expr = .{ .left = left, .right = right } };
        return node;
    }
    
    if (t == .LBracket) {
        self.advance();
        const dummy_node = try self.allocator.create(ast.Node);
        dummy_node.* = .{ .dummy_expr = .{ .desc = "slice_item" } };
        const first_elem = try parseSliceOrExpr(self, dummy_node);
        if (self.match(.Comma)) {
            var items: std.ArrayList(*ast.Node) = .empty;
            items.append(self.allocator, first_elem) catch unreachable;
            while (self.current.type != .RBracket and self.current.type != .EOF) {
                items.append(self.allocator, try parseSliceOrExpr(self, dummy_node)) catch unreachable;
                if (!self.match(.Comma)) break;
            }
            try self.expect(.RBracket);
            const tuple_node = try self.allocator.create(ast.Node);
            tuple_node.* = .{ .tuple_expr = .{ .items = items } };
            node.* = .{ .subscript = .{ .target = left, .index = tuple_node } };
            return node;
        }
        try self.expect(.RBracket);
        if (first_elem.* == .slice) {
            first_elem.slice.target = left;
            return first_elem;
        }
        node.* = .{ .subscript = .{ .target = left, .index = first_elem } };
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
