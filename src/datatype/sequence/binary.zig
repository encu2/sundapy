const std = @import("std");

pub const Bytes = []const u8;

pub const ByteArray = struct {
    list: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) ByteArray {
        return .{
            .list = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *ByteArray) void {
        self.list.deinit();
    }
};
