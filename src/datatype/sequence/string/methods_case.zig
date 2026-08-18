const std = @import("std");
const String = @import("types.zig").String;

pub fn upper(allocator: std.mem.Allocator, input: String) !String {
    const output = try allocator.alloc(u8, input.len);
    for (input, 0..) |char, i| {
        output[i] = std.ascii.toUpper(char);
    }
    return output;
}

pub fn lower(allocator: std.mem.Allocator, input: String) !String {
    const output = try allocator.alloc(u8, input.len);
    for (input, 0..) |char, i| {
        output[i] = std.ascii.toLower(char);
    }
    return output;
}

pub fn capitalize(allocator: std.mem.Allocator, input: String) !String {
    if (input.len == 0) return try allocator.alloc(u8, 0);
    const output = try allocator.alloc(u8, input.len);
    output[0] = std.ascii.toUpper(input[0]);
    for (input[1..], 1..) |char, i| {
        output[i] = std.ascii.toLower(char);
    }
    return output;
}
