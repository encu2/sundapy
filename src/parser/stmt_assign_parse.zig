const std = @import("std");
const ast = @import("../core/ast.zig");
const lexer = @import("../lexer/lexer.zig");
const Parser = @import("parser.zig").Parser;
const TokenType = lexer.TokenType;

pub fn isAugAssignOp(t: TokenType) bool {
    return switch (t) {
        .PlusEq, .MinusEq, .StarEq, .SlashEq, .PercentEq, .AmpersandEq, .PipeEq, .CaretEq, .LShiftEq, .RShiftEq, .SlashSlashEq, .StarStarEq => true,
        else => false,
    };
}

pub fn augAssignOpToBinOp(t: TokenType) []const u8 {
    return switch (t) {
        .PlusEq => "+", .MinusEq => "-", .StarEq => "*", .SlashEq => "/", .PercentEq => "%",
        .AmpersandEq => "&", .PipeEq => "|", .CaretEq => "^", .LShiftEq => "<<", .RShiftEq => ">>",
        .SlashSlashEq => "//", .StarStarEq => "**",
        else => "+",
    };
}

pub fn parseCommaTuple(self: *Parser, first: *ast.Node) !*ast.Node {
    var items = std.ArrayList(*ast.Node).empty;
    try items.append(self.allocator, first);
    while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent) {
        try items.append(self.allocator, try self.parseExpr(.none));
        if (!self.match(.Comma)) break;
    }
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .tuple_expr = .{ .items = items } };
    return node;
}

pub fn parseTupleAssign(self: *Parser, targets: std.ArrayList(*ast.Node)) anyerror!*ast.Node {
    var star_cnt: usize = 0;
    for (targets.items) |t| {
        if (t.* == .starred) star_cnt += 1;
    }
    if (star_cnt > 1) {
        std.debug.print("SyntaxError on line {d}: multiple starred expressions in assignment\n", .{self.current.line});
        return error.ParseError;
    }

    var rhs_items: std.ArrayList(*ast.Node) = .empty;
    const first_val = try self.parseExpr(.none);
    try rhs_items.append(self.allocator, first_val);
    if (self.match(.Comma)) {
        while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent) {
            try rhs_items.append(self.allocator, try self.parseExpr(.none));
            if (!self.match(.Comma)) break;
        }
        try self.consumeStmtEnd();
        const val_node = try self.allocator.create(ast.Node);
        val_node.* = .{ .list_expr = .{ .items = rhs_items } };
        const node = try self.allocator.create(ast.Node);
        node.* = .{ .tuple_assign = .{ .targets = targets, .value = val_node } };
        return node;
    } else {
        try self.consumeStmtEnd();
        const node = try self.allocator.create(ast.Node);
        node.* = .{ .tuple_assign = .{ .targets = targets, .value = first_val } };
        return node;
    }
}

pub fn parseAssignmentOrChained(self: *Parser, first_target: *ast.Node) anyerror!*ast.Node {
    var val = try self.parseExpr(.none);
    if (self.match(.Comma)) {
        var rhs_items: std.ArrayList(*ast.Node) = .empty;
        try rhs_items.append(self.allocator, val);
        while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent and self.current.type != .Eq) {
            try rhs_items.append(self.allocator, try self.parseExpr(.none));
            if (!self.match(.Comma)) break;
        }
        const val_node = try self.allocator.create(ast.Node);
        val_node.* = .{ .list_expr = .{ .items = rhs_items } };
        val = val_node;
    }

    if (self.match(.Eq)) {
        var targets = std.ArrayList(*ast.Node).empty;
        try targets.append(self.allocator, first_target);
        try targets.append(self.allocator, val);
        while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent) {
            val = try self.parseExpr(.none);
            if (self.match(.Comma)) {
                var rhs_items: std.ArrayList(*ast.Node) = .empty;
                try rhs_items.append(self.allocator, val);
                while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent and self.current.type != .Eq) {
                    try rhs_items.append(self.allocator, try self.parseExpr(.none));
                    if (!self.match(.Comma)) break;
                }
                const val_node = try self.allocator.create(ast.Node);
                val_node.* = .{ .list_expr = .{ .items = rhs_items } };
                val = val_node;
            }
            if (self.match(.Eq)) {
                try targets.append(self.allocator, val);
            } else break;
        }
        try self.consumeStmtEnd();
        const node = try self.allocator.create(ast.Node);
        node.* = .{ .chained_assign = .{ .targets = targets, .value = val } };
        return node;
    }

    try self.consumeStmtEnd();
    const node = try self.allocator.create(ast.Node);
    switch (first_target.*) {
        .identifier => |id| {
            node.* = .{ .assign = .{ .target = id.name, .type_ann = null, .value = val } };
            return node;
        },
        .getattr => |g| {
            node.* = .{ .setattr = .{ .target = g.target, .attr = g.attr, .value = val } };
            return node;
        },
        .subscript => |s| {
            node.* = .{ .subscript_assign = .{ .target = s.target, .index = s.index, .value = val } };
            return node;
        },
        .tuple_expr => |t| {
            node.* = .{ .tuple_assign = .{ .targets = t.items, .value = val } };
            return node;
        },
        .list_expr => |l| {
            node.* = .{ .tuple_assign = .{ .targets = l.items, .value = val } };
            return node;
        },
        else => {
            node.* = .{ .assign = .{ .target = "", .type_ann = null, .value = val } };
            return node;
        },
    }
}
