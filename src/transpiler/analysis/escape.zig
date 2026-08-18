const std = @import("std");
const ast = @import("../../core/ast.zig");

pub const StorageClass = enum {
    stack,
    heap,
};

pub const VarInfo = struct {
    name: []const u8,
    class: StorageClass,
    is_primitive: bool,
    primitive_type: []const u8 = "i64",
};

pub const EscapeAnalyzer = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(VarInfo),

    pub fn init(allocator: std.mem.Allocator) EscapeAnalyzer {
        return .{
            .allocator = allocator,
            .variables = std.StringHashMap(VarInfo).init(allocator),
        };
    }

    pub fn deinit(self: *EscapeAnalyzer) void {
        self.variables.deinit();
    }

    pub fn markEscape(self: *EscapeAnalyzer, name: []const u8) !void {
        if (self.variables.getPtr(name)) |v| {
            if (!v.is_primitive) {
                v.class = .heap;
            }
        }
    }

    pub fn analyzeFirstPass(self: *EscapeAnalyzer, node: *ast.Node) !void {
        try @import("escape_pass1.zig").analyzeFirstPass(self, node);
    }
    pub fn analyzeSecondPass(self: *EscapeAnalyzer, node: *ast.Node) !void {
        try @import("escape_pass2.zig").analyzeSecondPass(self, node);
    }

    pub fn isPrimitive(self: *EscapeAnalyzer, node: *ast.Node) bool {
        return switch (node.*) {
            .number, .integer, .float => true,
            .binary => |b| self.isPrimitive(b.left) and self.isPrimitive(b.right),
            .unary => |u| self.isPrimitive(u.right),
            .identifier => |i| {
                if (self.variables.get(i.name)) |v| {
                    return v.is_primitive;
                }
                return false;
            },
            else => false,
        };
    }

    pub fn primitiveTypeString(self: *EscapeAnalyzer, node: *ast.Node) []const u8 {
        switch (node.*) {
            .integer => return "i64",
            .number => return "i64",
            .float => return "f64",
            .string => return "[]const u8",
            .binary => |b| return self.primitiveTypeString(b.left),
            .unary => |u| return self.primitiveTypeString(u.right),
            .identifier => |i| {
                if (self.variables.get(i.name)) |v| {
                    if (v.is_primitive) return v.primitive_type;
                }
                return "i64";
            },
            else => return "i64", // default fallback
        }
    }
};
