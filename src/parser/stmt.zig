const std = @import("std");
const ast = @import("../core/ast.zig");
const lexer = @import("../lexer/lexer.zig");
const Parser = @import("parser.zig").Parser;
const Precedence = @import("parser.zig").Precedence;
const TokenType = lexer.TokenType;

    pub fn parseBlock(self: *Parser) anyerror!std.ArrayList(*ast.Node) {
        var stmts: std.ArrayList(*ast.Node) = .empty;
        if (self.match(.Newline)) {
            try self.expect(.Indent);
            while (self.current.type != .Dedent and self.current.type != .EOF) {
                if (self.match(.Newline)) continue;
                if (self.match(.Semicolon)) continue;
                const stmt = try self.parseStmt();
                stmts.append(self.allocator, stmt) catch unreachable;
            }
            if (self.current.type == .Dedent) self.advance();
        } else {
            while (self.current.type != .Newline and self.current.type != .EOF and self.current.type != .Dedent) {
                if (self.match(.Semicolon)) continue;
                const stmt = try self.parseStmt();
                stmts.append(self.allocator, stmt) catch unreachable;
            }
            if (self.match(.Newline)) {}
        }
        return stmts;
    }
    pub fn parseStmt(self: *Parser) anyerror!*ast.Node {
        while (self.match(.Newline)) {}
        
        if (self.match(.KeywordPass)) {
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .pass_stmt;
            return node;
        }
        if (self.match(.KeywordContinue)) {
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .continue_stmt;
            return node;
        }
        if (self.match(.KeywordBreak)) {
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .break_stmt;
            return node;
        }
        if (self.match(.KeywordReturn)) {
            var val: ?*ast.Node = null;
            if (self.current.type != .Newline and self.current.type != .Semicolon) {
                val = try self.parseExpr(.none);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .return_stmt = .{ .value = val } };
            return node;
        }
        if (self.match(.KeywordYield)) {
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .yield_stmt = .{ .value = val } };
            return node;
        }
        if (self.match(.KeywordRaise)) {
            var val: ?*ast.Node = null;
            if (self.current.type != .Newline and self.current.type != .Semicolon) {
                val = try self.parseExpr(.none);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .raise_stmt = .{ .value = val } };
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
            return try @import("stmt_control_parse.zig").parseForStmt(self);
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
                } else {
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

        if (self.match(.KeywordDef)) {
            return try @import("stmt_decl.zig").parseDefStmt(self, false);
        }
        if (self.match(.KeywordAsync)) {
            if (self.match(.KeywordDef)) {
                return try @import("stmt_decl.zig").parseDefStmt(self, true);
            }
            return error.ParseError;
        }
        if (self.match(.KeywordClass)) {
            return try @import("stmt_decl.zig").parseClassStmt(self);
        }
        if (self.match(.KeywordImport)) {
            const name_ptr = self.current.lexeme.ptr;
            var name_len = self.current.lexeme.len;
            try self.expect(.Identifier);
            while (self.match(.Dot)) {
                name_len = (@intFromPtr(self.current.lexeme.ptr) - @intFromPtr(name_ptr)) + self.current.lexeme.len;
                try self.expect(.Identifier);
            }
            const name = name_ptr[0..name_len];
            
            var alias: ?[]const u8 = null;
            if (self.match(.KeywordAs)) {
                alias = self.current.lexeme;
                try self.expect(.Identifier);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .import_stmt = .{ .name = name, .alias = alias } };
            return node;
        }
        if (self.match(.KeywordFrom)) {
            const mod_ptr = self.current.lexeme.ptr;
            var mod_len = self.current.lexeme.len;
            try self.expect(.Identifier);
            while (self.match(.Dot)) {
                mod_len = (@intFromPtr(self.current.lexeme.ptr) - @intFromPtr(mod_ptr)) + self.current.lexeme.len;
                try self.expect(.Identifier);
            }
            const mod = mod_ptr[0..mod_len];
            
            try self.expect(.KeywordImport);
            const name = self.current.lexeme;
            try self.expect(.Identifier);
            var alias: ?[]const u8 = null;
            if (self.match(.KeywordAs)) {
                alias = self.current.lexeme;
                try self.expect(.Identifier);
            }
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .from_import = .{ .module = mod, .name = name, .alias = alias } };
            return node;
        }

        if (self.current.type == .Identifier) {
            if (self.peek_token.type == .Eq) {
                const target = self.current.lexeme;
                self.advance(); 
                self.advance(); 
                const val = try self.parseExpr(.none);
                try self.consumeStmtEnd();
                const node = try self.allocator.create(ast.Node);
                node.* = .{ .assign = .{ .target = target, .type_ann = null, .value = val } };
                return node;
            } else if (self.peek_token.type == .PlusEq or self.peek_token.type == .MinusEq or self.peek_token.type == .StarEq or self.peek_token.type == .SlashEq or self.peek_token.type == .PercentEq) {
                const target = self.current.lexeme;
                self.advance();
                const op_token = self.current;
                self.advance();
                
                const val = try self.parseExpr(.none);
                try self.consumeStmtEnd();
                
                var bin_op: []const u8 = "+";
                if (op_token.type == .MinusEq) bin_op = "-";
                if (op_token.type == .StarEq) bin_op = "*";
                if (op_token.type == .SlashEq) bin_op = "/";
                if (op_token.type == .PercentEq) bin_op = "%";
                
                const target_ident = try self.allocator.create(ast.Node);
                target_ident.* = .{ .identifier = .{ .name = target } };
                
                const desugared_val = try self.allocator.create(ast.Node);
                desugared_val.* = .{ .binary = .{ .left = target_ident, .op = bin_op, .right = val } };
                
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
                }
                try self.expect(.Eq);
                const val = try self.parseExpr(.none);
                try self.consumeStmtEnd();
                const node = try self.allocator.create(ast.Node);
                node.* = .{ .assign = .{ .target = target, .type_ann = type_ann, .value = val } };
                return node;
            } 
        }

        const expr = try self.parseExpr(.none);
        
        if (expr.* == .getattr and self.match(.Eq)) {
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .setattr = .{ .target = expr.getattr.target, .attr = expr.getattr.attr, .value = val } };
            return node;
        } else if (expr.* == .getattr and (self.current.type == .PlusEq or self.current.type == .MinusEq or self.current.type == .StarEq or self.current.type == .SlashEq or self.current.type == .PercentEq)) {
            const op_token = self.current; self.advance();
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            
            var bin_op: []const u8 = "+";
            if (op_token.type == .MinusEq) bin_op = "-";
            if (op_token.type == .StarEq) bin_op = "*";
            if (op_token.type == .SlashEq) bin_op = "/";
            if (op_token.type == .PercentEq) bin_op = "%";
            
            const desugared_val = try self.allocator.create(ast.Node);
            desugared_val.* = .{ .binary = .{ .left = expr, .op = bin_op, .right = val } };
            
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .setattr = .{ .target = expr.getattr.target, .attr = expr.getattr.attr, .value = desugared_val } };
            return node;
        } else if (expr.* == .subscript and self.match(.Eq)) {
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .subscript_assign = .{ .target = expr.subscript.target, .index = expr.subscript.index, .value = val } };
            return node;
        } else if (expr.* == .subscript and (self.current.type == .PlusEq or self.current.type == .MinusEq or self.current.type == .StarEq or self.current.type == .SlashEq or self.current.type == .PercentEq)) {
            const op_token = self.current; self.advance();
            const val = try self.parseExpr(.none);
            try self.consumeStmtEnd();
            
            var bin_op: []const u8 = "+";
            if (op_token.type == .MinusEq) bin_op = "-";
            if (op_token.type == .StarEq) bin_op = "*";
            if (op_token.type == .SlashEq) bin_op = "/";
            if (op_token.type == .PercentEq) bin_op = "%";
            
            const desugared_val = try self.allocator.create(ast.Node);
            desugared_val.* = .{ .binary = .{ .left = expr, .op = bin_op, .right = val } };
            
            const node = try self.allocator.create(ast.Node);
            node.* = .{ .subscript_assign = .{ .target = expr.subscript.target, .index = expr.subscript.index, .value = desugared_val } };
            return node;
        }

        try self.consumeStmtEnd();
        return expr;
    }
