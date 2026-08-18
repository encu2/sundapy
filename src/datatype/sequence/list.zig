const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const Tuple = struct {
    items: []const Dynamic,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, items: []const Dynamic) !Tuple {
        const slice = try allocator.alloc(Dynamic, items.len);
        @memcpy(slice, items);
        return .{
            .items = slice,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Tuple) void {
        self.allocator.free(self.items);
    }
};

pub const List = struct {
    items: std.ArrayList(Dynamic),

    pub fn init() List {
        return .{
            .items = .empty,
        };
    }

    pub fn deinit(self: *List) void {
        self.items.deinit();
    }
};
