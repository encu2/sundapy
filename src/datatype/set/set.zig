const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const Set = struct {
    items: std.ArrayList(Dynamic),

    pub fn init(allocator: std.mem.Allocator) Set {
        _ = allocator;
        return .{
            .items = .empty,
        };
    }

    pub fn deinit(self: *Set) void {
        self.items.deinit();
    }
    
    pub fn add(self: *Set, alloc: std.mem.Allocator, item: Dynamic) !void {
        for (self.items.items) |existing| {
            if (existing.eq(item).value.bool_type) return;
        }
        try self.items.append(alloc, item);
    }
};

pub const FrozenSet = struct {
    items: []const Dynamic,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, items: []const Dynamic) !FrozenSet {
        // Assume items are already deduplicated before passing here for now
        const slice = try allocator.alloc(Dynamic, items.len);
        @memcpy(slice, items);
        return .{
            .items = slice,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FrozenSet) void {
        self.allocator.free(self.items);
    }
};
