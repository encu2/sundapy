const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn split(allocator: std.mem.Allocator, self: Dynamic, sep: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    if (sep.value != .str_type) return error.TypeError;

    var list: std.ArrayList(Dynamic) = .empty;
    var it = std.mem.splitSequence(u8, self.value.str_type, sep.value.str_type);
    while (it.next()) |part| {
        try list.append(allocator, Dynamic{ .value = .{ .str_type = part } });
    }

    return Dynamic{ .value = .{ .list_type = .{ .items = list } } };
}

pub fn replace(allocator: std.mem.Allocator, self: Dynamic, old: Dynamic, new: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    if (old.value != .str_type) return error.TypeError;
    if (new.value != .str_type) return error.TypeError;

    const result = try std.mem.replaceOwned(u8, allocator, self.value.str_type, old.value.str_type, new.value.str_type);
    return Dynamic{ .value = .{ .str_type = result } };
}

pub fn join(allocator: std.mem.Allocator, self: Dynamic, iterable: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    if (iterable.value != .list_type) return error.TypeError;

    var strings: std.ArrayList([]const u8) = .empty;
    defer strings.deinit(allocator);

    for (iterable.value.list_type.items.items) |item| {
        if (item.value != .str_type) return error.TypeError;
        try strings.append(allocator, item.value.str_type);
    }

    const result = try std.mem.join(allocator, self.value.str_type, strings.items);
    return Dynamic{ .value = .{ .str_type = result } };
}

pub fn upper(allocator: std.mem.Allocator, self: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    
    const result = try allocator.alloc(u8, self.value.str_type.len);
    for (self.value.str_type, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }
    return Dynamic{ .value = .{ .str_type = result } };
}

pub fn lower(allocator: std.mem.Allocator, self: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    
    const result = try allocator.alloc(u8, self.value.str_type.len);
    for (self.value.str_type, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }
    return Dynamic{ .value = .{ .str_type = result } };
}
