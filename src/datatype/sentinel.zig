const std = @import("std");

pub const Sentinel = struct {
    name: []const u8,
    repr_str: []const u8,

    pub fn init(comptime name: []const u8, comptime repr_str: []const u8) Sentinel {
        return .{
            .name = name,
            .repr_str = repr_str,
        };
    }

    pub fn isSame(self: *const Sentinel, other: *const Sentinel) bool {
        return @intFromPtr(self) == @intFromPtr(other);
    }
};

pub const MISSING = Sentinel.init("MISSING", "<sentinel MISSING>");
pub const NOT_GIVEN = Sentinel.init("NOT_GIVEN", "<sentinel NOT_GIVEN>");
pub const EllipsisSentinel = Sentinel.init("Ellipsis", "Ellipsis");
