const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseTupleAssign(self: *Parser, targets: std.ArrayList(*ast.Node)) anyerror!*ast.Node {
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
