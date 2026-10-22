const std = @import("std");
const String = @import("types.zig").String;

/// ponytail: Zig 0.16 ArrayList API — .empty + append(allocator, item)
pub fn split(allocator: std.mem.Allocator, input: String, delimiter: String, maxsplit: isize) !std.ArrayList(String) {
    var list: std.ArrayList(String) = .empty;
    if (delimiter.len == 0) return list;
    var rest = input;
    var count: usize = 0;
    while (maxsplit < 0 or count < @as(usize, @intCast(maxsplit))) {
        if (std.mem.indexOf(u8, rest, delimiter)) |idx| {
            try list.append(allocator, rest[0..idx]);
            rest = rest[idx + delimiter.len ..];
            count += 1;
        } else {
            break;
        }
    }
    try list.append(allocator, rest);
    return list;
}

pub fn splitWhitespace(allocator: std.mem.Allocator, input: String, maxsplit: isize) !std.ArrayList(String) {
    var list: std.ArrayList(String) = .empty;
    var it = std.mem.tokenizeAny(u8, input, " \t\r\n");
    var count: usize = 0;
    while (it.next()) |chunk| {
        if (maxsplit >= 0 and count >= @as(usize, @intCast(maxsplit))) {
            const rest_start = @intFromPtr(chunk.ptr) - @intFromPtr(input.ptr);
            const trimmed_rest = std.mem.trimStart(u8, input[rest_start..], " \t\r\n");
            try list.append(allocator, trimmed_rest);
            break;
        }
        try list.append(allocator, chunk);
        count += 1;
    }
    return list;
}

pub fn replace(allocator: std.mem.Allocator, input: String, old: String, new: String) !String {
    return try std.mem.replaceOwned(u8, allocator, input, old, new);
}
