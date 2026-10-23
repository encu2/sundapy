const std = @import("std");
const ast = @import("../core/ast.zig");
const lexer = @import("../lexer/lexer.zig");
const Parser = @import("parser.zig").Parser;
const Precedence = @import("parser.zig").Precedence;
const TokenType = lexer.TokenType;

const stmt_assign = @import("stmt_assign_parse.zig");
const isAugAssignOp = stmt_assign.isAugAssignOp;
const augAssignOpToBinOp = stmt_assign.augAssignOpToBinOp;
const parseCommaTuple = stmt_assign.parseCommaTuple;

    pub fn parseBlock(self: *Parser) anyerror!std.ArrayList(*ast.Node) {
        var stmts: std.ArrayList(*ast.Node) = .empty;
        if (self.match(.Newline)) {
            try self.expect(.Indent);
            while (self.current.type != .Dedent and self.current.type != .EOF) {
                if (self.match(.Newline)) continue;
                if (self.match(.Semicolon)) continue;
                const stmt = try self.parseStmt();
                if (stmt.* == .compound_stmt) {
                    for (stmt.compound_stmt.items.items) |s| {
                        stmts.append(self.allocator, s) catch unreachable;
                    }
                } else {
                    stmts.append(self.allocator, stmt) catch unreachable;
                }
            }
            if (self.current.type == .Dedent) self.advance();
        } else {
            while (self.current.type != .Newline and self.current.type != .EOF and self.current.type != .Dedent) {
                if (self.match(.Semicolon)) continue;
                const stmt = try self.parseStmt();
                if (stmt.* == .compound_stmt) {
                    for (stmt.compound_stmt.items.items) |s| {
                        stmts.append(self.allocator, s) catch unreachable;
                    }
                } else {
                    stmts.append(self.allocator, stmt) catch unreachable;
                }
            }
            if (self.match(.Newline)) {}
        }
        return stmts;
    }
    pub fn parseStmt(self: *Parser) anyerror!*ast.Node {
        while (self.match(.Newline)) {}
        
        if (self.match(.KeywordPass)) { try self.consumeStmtEnd(); const node = try self.allocator.create(ast.Node); node.* = .pass_stmt; return node; }
        if (self.match(.Ellipsis)) { try self.consumeStmtEnd(); const node = try self.allocator.create(ast.Node); node.* = .ellipsis; return node; }
        if (self.match(.KeywordContinue)) { try self.consumeStmtEnd(); const node = try self.allocator.create(ast.Node); node.* = .continue_stmt; return node; }
        if (self.match(.KeywordBreak)) { try self.consumeStmtEnd(); const node = try self.allocator.create(ast.Node); node.* = .break_stmt; return node; }
        if (self.match(.KeywordDel)) {
            const first = try self.parseExpr(.none);
            if (self.match(.Comma)) {
                var del_stmts: std.ArrayList(*ast.Node) = .empty;
                const d1 = try self.allocator.create(ast.Node);
                d1.* = .{ .del_stmt = .{ .target = first } };
                try del_stmts.append(self.allocator, d1);
                while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent) {
                    const next_target = try self.parseExpr(.none);
                    const d_next = try self.allocator.create(ast.Node);
                    d_next.* = .{ .del_stmt = .{ .target = next_target } };
                    try del_stmts.append(self.allocator, d_next);
                    if (!self.match(.Comma)) break;
                }
                try self.consumeStmtEnd();
                const comp = try self.allocator.create(ast.Node);
                comp.* = .{ .compound_stmt = .{ .items = del_stmts } };
                return comp;
            } else {
                try self.consumeStmtEnd();
                const node = try self.allocator.create(ast.Node);
                node.* = .{ .del_stmt = .{ .target = first } };
                return node;
            }
        }
        if (self.match(.KeywordAssert)) {
            const cond = try self.parseExpr(.none);
            var msg: ?*ast.Node = null;
            if (self.match(.Comma)) {
                msg = try self.parseExpr(.none);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .assert_stmt = .{ .condition = cond, .message = msg } };
            return node;
        }
        if (self.match(.KeywordReturn)) {
            var val: ?*ast.Node = null;
            if (self.current.type != .Newline and self.current.type != .Semicolon) {
                val = try self.parseExpr(.none);
                if (self.match(.Comma)) val = try parseCommaTuple(self, val.?);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .return_stmt = .{ .value = val } };
            return node;
        }
        if (self.match(.KeywordYield)) {
            var is_from = false;
            var val: ?*ast.Node = null;
            if (self.match(.KeywordFrom)) {
                is_from = true;
                val = try self.parseExpr(.none);
            } else if (self.current.type != .Newline and self.current.type != .Semicolon) {
                val = try self.parseExpr(.none);
                if (self.match(.Comma)) val = try parseCommaTuple(self, val.?);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .yield_stmt = .{ .value = val, .is_from = is_from } };
            return node;
        }
        if (self.match(.KeywordRaise)) {
            var val: ?*ast.Node = null;
            if (self.current.type != .Newline and self.current.type != .Semicolon) {
                val = try self.parseExpr(.none);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .raise_stmt = .{ .value = val, .from_exc = null } };
            return node;
        }
        if (self.match(.KeywordTry)) {
            return try @import("stmt_control_parse.zig").parseTryStmt(self);
        }
        if (self.match(.KeywordIf)) {
            return try @import("stmt_control_parse.zig").parseIfStmt(self);
        }
        if (self.match(.KeywordMatch)) {
            return try @import("stmt_control_parse.zig").parseMatchStmt(self);
        }
        if (self.match(.KeywordWhile)) {
            return try @import("stmt_control_parse.zig").parseWhileStmt(self);
        }
        if (self.match(.KeywordFor)) {
            return try @import("stmt_control_parse.zig").parseForStmt(self, false);
        }
        if (self.match(.KeywordWith)) {
            return try @import("stmt_control_parse.zig").parseWithStmt(self, false);
        }
        if (self.match(.DirectiveStrict)) {
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .directive_strict;
            return node;
        }
        
        if (self.match(.KeywordGlobal)) {
            const name = self.current.lexeme;
            try self.expect(.Identifier);
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .global_decl = .{ .name = name } };
            return node;
        }

        if (self.match(.KeywordConst)) {
            const target = self.current.lexeme;
            try self.expect(.Identifier);
            var type_ann: ?[]const u8 = null;
            if (self.match(.Colon)) {
                if (self.current.type == .Identifier) {
                    type_ann = self.current.lexeme;
                    self.advance();
                } else if (self.current.type == .KeywordNone) {
                    type_ann = "None";
                    self.advance();
                } else if (self.current.type == .Ellipsis) {
                    type_ann = "...";
                    self.advance();
                } else {
                    std.debug.print("ParseError on line {d}: syntax error at token {any} ('{s}')\n", .{self.current.line, self.current.type, self.current.lexeme});
                    return error.ParseError; // failing here
                }
            }
            try self.expect(.Eq);
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .const_assign = .{ .target = target, .type_ann = type_ann, .value = val } };
            return node;
        }

        var decorators: std.ArrayList(*ast.Node) = .empty;
        while (self.match(.At)) {
            const dec = try self.parseExpr(.none);
            try decorators.append(self.allocator, dec);
            try self.consumeStmtEnd();
            while (self.match(.Newline)) {}
        }

        if (self.match(.KeywordDef)) {
            return try @import("stmt_decl.zig").parseDefStmt(self, false, decorators);
        }
        if (self.match(.KeywordAsync)) {
            // async with, async for, async def
            if (self.match(.KeywordDef)) {
                return try @import("stmt_decl.zig").parseDefStmt(self, true, decorators);
            } else if (self.match(.KeywordWith)) {
                if (decorators.items.len > 0) return error.ParseError;
                return try @import("stmt_control_parse.zig").parseWithStmt(self, true);
            } else if (self.match(.KeywordFor)) {
                if (decorators.items.len > 0) return error.ParseError;
                return try @import("stmt_control_parse.zig").parseForStmt(self, true);
            }
            std.debug.print("ParseError on line {d}: syntax error at token {any} ('{s}')\n", .{self.current.line, self.current.type, self.current.lexeme});
            return error.ParseError;
        }
        if (self.match(.KeywordClass)) {
            return try @import("stmt_decl.zig").parseClassStmt(self, decorators);
        }
        
        if (decorators.items.len > 0) {
            std.debug.print("ParseError on line {d}: unexpected decorator before {any}\n", .{self.current.line, self.current.type});
            return error.ParseError;
        }
        if (self.match(.KeywordImport)) {
            return try @import("stmt_import_parse.zig").parseImportStmt(self);
        }
        if (self.match(.KeywordFrom)) {
            return try @import("stmt_import_parse.zig").parseFromImport(self);
        }

        if (self.current.type == .Identifier) {
            if (self.peek_token.type == .Eq) {
                const target = self.current.lexeme;
                self.advance(); 
                self.advance(); 
                const target_node = try self.allocator.create(ast.Node);
                target_node.* = .{ .identifier = .{ .name = target } };
                return try @import("stmt_assign_parse.zig").parseAssignmentOrChained(self, target_node);
            } else if (isAugAssignOp(self.peek_token.type)) {
                const target = self.current.lexeme;
                self.advance();
                const op = augAssignOpToBinOp(self.current.type);
                self.advance();
                const val = try self.parseExpr(.none);
                try self.consumeStmtEnd();
                const target_ident = try self.allocator.create(ast.Node);
                target_ident.* = .{ .identifier = .{ .name = target } };
                const desugared_val = try self.allocator.create(ast.Node);
                desugared_val.* = .{ .binary = .{ .left = target_ident, .op = op, .right = val } };
                const node = try self.allocator.create(ast.Node);
                node.* = .{ .assign = .{ .target = target, .type_ann = null, .value = desugared_val } };
                return node;
            } else if (self.peek_token.type == .Colon) { 
                const target = self.current.lexeme;
                self.advance(); 
                self.advance(); 
                const type_ann_node = try self.parseExpr(.none);
                var type_ann: ?[]const u8 = null;
                if (type_ann_node.* == .identifier) {
                    type_ann = type_ann_node.identifier.name;
                } else if (type_ann_node.* == .getattr) {
                    if (type_ann_node.getattr.target.* == .identifier) {
                        const target_name = type_ann_node.getattr.target.identifier.name;
                        const attr_name = type_ann_node.getattr.attr;
                        const combined = try self.allocator.alloc(u8, target_name.len + attr_name.len + 1);
                        std.mem.copyForwards(u8, combined[0..target_name.len], target_name);
                        combined[target_name.len] = '.';
                        std.mem.copyForwards(u8, combined[target_name.len + 1..], attr_name);
                        type_ann = combined;
                    }
                } else if (type_ann_node.* == .none) {
                    type_ann = "None";
                } else if (type_ann_node.* == .ellipsis) {
                    type_ann = "...";
                }
                if (self.match(.Eq)) {
                    const val = try self.parseExpr(.none);
                    try self.consumeStmtEnd();
                    const node = try self.allocator.create(ast.Node);
                    node.* = .{ .assign = .{ .target = target, .type_ann = type_ann, .value = val } };
                    return node;
                } else {
                    try self.consumeStmtEnd();
                    const node = try self.allocator.create(ast.Node);
                    node.* = .{ .ann_decl = .{ .target = target, .type_ann = type_ann } };
                    return node;
                }
            } 
        }

        const expr = try self.parseExpr(.none);

        if (self.match(.Comma)) {
            var items = std.ArrayList(*ast.Node).empty;
            try items.append(self.allocator, expr);
            while (self.current.type != .Newline and self.current.type != .Semicolon and self.current.type != .EOF and self.current.type != .Dedent and self.current.type != .Eq) {
                const item = try self.parseExpr(.none);
                try items.append(self.allocator, item);
                if (!self.match(.Comma)) break;
            }
            if (self.match(.Eq)) {
                return try @import("stmt_assign_parse.zig").parseTupleAssign(self, items);
            }
            try self.consumeStmtEnd();
            const tup = try self.allocator.create(ast.Node);
            tup.* = .{ .tuple_expr = .{ .items = items } };
            return tup;
        }

        if (expr.* == .starred and self.match(.Eq)) {
            std.debug.print("SyntaxError on line {d}: starred assignment target must be in a list or tuple\n", .{self.current.line});
            return error.ParseError;
        }
        
        if ((expr.* == .getattr or expr.* == .subscript or expr.* == .list_expr or expr.* == .tuple_expr) and self.match(.Eq)) {
            return try @import("stmt_assign_parse.zig").parseAssignmentOrChained(self, expr);
        } else if (expr.* == .getattr and isAugAssignOp(self.current.type)) {
            const op = augAssignOpToBinOp(self.current.type); self.advance();
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const desugared_val = try self.allocator.create(ast.Node);
            desugared_val.* = .{ .binary = .{ .left = expr, .op = op, .right = val } };
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .setattr = .{ .target = expr.getattr.target, .attr = expr.getattr.attr, .value = desugared_val } };
            return node;
        } else if (expr.* == .subscript and isAugAssignOp(self.current.type)) {
            const op = augAssignOpToBinOp(self.current.type); self.advance();
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const desugared_val = try self.allocator.create(ast.Node);
            desugared_val.* = .{ .binary = .{ .left = expr, .op = op, .right = val } };
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .subscript_assign = .{ .target = expr.subscript.target, .index = expr.subscript.index, .value = desugared_val } };
            return node;
        }

        try self.consumeStmtEnd();
        return expr;
    }
