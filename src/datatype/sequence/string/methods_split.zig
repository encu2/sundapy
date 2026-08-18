const std = @import("std");
const String = @import("types.zig").String;

/// ponytail: Zig 0.16 ArrayList API — .empty + append(allocator, item)
pub fn split(allocator: std.mem.Allocator, input: String, delimiter: String) !std.ArrayList(String) {
    var list: std.ArrayList(String) = .empty;
    var it = std.mem.splitSequence(u8, input, delimiter);
    while (it.next()) |chunk| {
        try list.append(allocator, chunk);
    }
    return list;
}

pub fn replace(allocator: std.mem.Allocator, input: String, old: String, new: String) !String {
    return try std.mem.replaceOwned(u8, allocator, input, old, new);
}
