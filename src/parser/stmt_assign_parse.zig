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
