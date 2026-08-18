const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const methods_case = @import("../sequence/string/methods_case.zig");
const methods_split = @import("../sequence/string/methods_split.zig");

/// ponytail: all ArrayList ops use Zig 0.16 API (.empty + allocator arg)
pub fn str_split(self: Dynamic, allocator: std.mem.Allocator, sep: Dynamic) !Dynamic {
    if (self.value != .str_type or sep.value != .str_type) return error.TypeError;

    var slices = try methods_split.split(allocator, self.value.str_type, sep.value.str_type);
    defer slices.deinit(allocator);

    var dynamic_list: std.ArrayList(Dynamic) = .empty;
    for (slices.items) |slice| {
        try dynamic_list.append(allocator, Dynamic.initStr(slice));
    }

    return Dynamic.initList(dynamic_list);
}

pub fn str_replace(self: Dynamic, allocator: std.mem.Allocator, old: Dynamic, new: Dynamic) !Dynamic {
    if (self.value != .str_type or old.value != .str_type or new.value != .str_type) return error.TypeError;
    const res = try methods_split.replace(allocator, self.value.str_type, old.value.str_type, new.value.str_type);
    return Dynamic.initStr(res);
}

pub fn str_join(self: Dynamic, allocator: std.mem.Allocator, iterable: Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    if (iterable.value != .list_type) return error.TypeError;

    // ponytail: collect string slices, then std.mem.join
    var strings: std.ArrayList([]const u8) = .empty;
    defer strings.deinit(allocator);

    for (iterable.value.list_type.items.items) |item| {
        if (item.value != .str_type) return error.TypeError;
        try strings.append(allocator, item.value.str_type);
    }

    const result = try std.mem.join(allocator, self.value.str_type, strings.items);
    return Dynamic.initStr(result);
}

pub fn str_upper(self: Dynamic, allocator: std.mem.Allocator) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    const res = try methods_case.upper(allocator, self.value.str_type);
    return Dynamic.initStr(res);
}

pub fn str_lower(self: Dynamic, allocator: std.mem.Allocator) !Dynamic {
    if (self.value != .str_type) return error.TypeError;
    const res = try methods_case.lower(allocator, self.value.str_type);
    return Dynamic.initStr(res);
}
