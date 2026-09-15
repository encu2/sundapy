const std = @import("std");
const ast = @import("../core/ast.zig");
const Parser = @import("parser.zig").Parser;

pub fn parseDefStmt(self: *Parser, is_async: bool, decorators: std.ArrayList(*ast.Node)) anyerror!*ast.Node {
    const name = self.current.lexeme;
    try self.expect(.Identifier);
    try self.expect(.LParen);
    var params: std.ArrayList(ast.Param) = .empty;
    while (self.current.type != .RParen) {
        if (self.match(.StarStar)) {
            const p_name = self.current.lexeme;
            try self.expect(.Identifier);
            if (self.match(.Colon)) {
                _ = try self.parseExpr(.none);
            }
            params.append(self.allocator, .{ .name = p_name, .type_ann = null, .default_value = null }) catch unreachable;
            _ = self.match(.Comma);
            continue;
        } else if (self.match(.Star)) {
            if (self.current.type == .Identifier) {
                const p_name = self.current.lexeme;
                try self.expect(.Identifier);
                if (self.match(.Colon)) {
                    _ = try self.parseExpr(.none);
                }
                params.append(self.allocator, .{ .name = p_name, .type_ann = null, .default_value = null }) catch unreachable;
            } else {
                // just a * marker for kw-only args
            }
            _ = self.match(.Comma);
            continue;
        } else if (self.match(.Slash)) {
            _ = self.match(.Comma);
            continue;
        }
        
        const p_name = self.current.lexeme;
        try self.expect(.Identifier);
        var p_type: ?[]const u8 = null;
        if (self.match(.Colon)) {
            const t_expr = try self.parseExpr(.none);
            // Extract type name if it's a simple identifier (e.g. int, str, float, bool)
            if (t_expr.* == .identifier) {
                p_type = t_expr.identifier.name;
            }
        }
        var default_val: ?*ast.Node = null;
        if (self.match(.Eq)) {
            default_val = try self.parseExpr(.none);
        }
        params.append(self.allocator, .{ .name = p_name, .type_ann = p_type, .default_value = default_val }) catch unreachable;
        _ = self.match(.Comma);
    }
    try self.expect(.RParen);
    var ret_type: ?[]const u8 = null;
    if (self.current.type == .Identifier and std.mem.eql(u8, self.current.lexeme, "->")) {
        self.advance();
        const ret_expr = try self.parseExpr(.none);
        if (ret_expr.* == .identifier) {
            ret_type = ret_expr.identifier.name;
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
    node.* = .{ .def_stmt = .{ .name = name, .params = params, .return_type = ret_type, .body = block, .is_strict = is_strict, .is_async = is_async, .decorators = decorators } };
    return node;
}

pub fn parseClassStmt(self: *Parser, decorators: std.ArrayList(*ast.Node)) anyerror!*ast.Node {
    const name = self.current.lexeme;
    try self.expect(.Identifier);
    var base_class: ?[]const u8 = null;
    if (self.match(.LParen)) {
        if (self.current.type != .RParen) {
            const start_pos = self.current.lexeme.ptr;
            while (self.current.type != .RParen and self.current.type != .EOF) {
                self.advance();
            }
            const len = @intFromPtr(self.current.lexeme.ptr) - @intFromPtr(start_pos);
            base_class = start_pos[0..len];
        }
        try self.expect(.RParen);
    }
    try self.expect(.Colon);
    const block = try self.parseBlock();
    const node = try self.allocator.create(ast.Node);
    node.* = .{ .class_stmt = .{ .name = name, .base_class = base_class, .methods = block, .decorators = decorators } };
    return node;
}
