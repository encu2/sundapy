const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const methods_case = @import("../sequence/string/methods_case.zig");
const methods_split = @import("../sequence/string/methods_split.zig");

pub fn str_split(self: Dynamic, allocator: std.mem.Allocator, sep: ?Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;

    if (sep) |s| {
        if (s.value == .str_type) {
            var slices = try methods_split.split(allocator, self.value.str_type, s.value.str_type);
            defer slices.deinit(allocator);

            var dynamic_list: std.ArrayList(Dynamic) = .empty;
            try dynamic_list.ensureTotalCapacity(allocator, slices.items.len);
            for (slices.items) |slice| {
                dynamic_list.appendAssumeCapacity(Dynamic.initStr(slice));
            }

            return Dynamic.initList(dynamic_list);
        }
    }

    var slices = try methods_split.splitWhitespace(allocator, self.value.str_type);
    defer slices.deinit(allocator);

    var dynamic_list: std.ArrayList(Dynamic) = .empty;
    try dynamic_list.ensureTotalCapacity(allocator, slices.items.len);
    for (slices.items) |slice| {
        dynamic_list.appendAssumeCapacity(Dynamic.initStr(slice));
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

    const items = iterable.value.list_type.items.items;
    if (items.len == 0) return Dynamic.initStr("");
    if (items.len == 1) {
        if (items[0].value != .str_type) return error.TypeError;
        return items[0];
    }

    const sep = self.value.str_type;
    var total_len: usize = sep.len * (items.len - 1);
    for (items) |item| {
        if (item.value != .str_type) return error.TypeError;
        total_len += item.value.str_type.len;
    }

    const buf = try allocator.alloc(u8, total_len);
    var offset: usize = 0;
    for (items, 0..) |item, idx| {
        if (idx > 0 and sep.len > 0) {
            @memcpy(buf[offset .. offset + sep.len], sep);
            offset += sep.len;
        }
        const s = item.value.str_type;
        if (s.len > 0) {
            @memcpy(buf[offset .. offset + s.len], s);
            offset += s.len;
        }
    }

    return Dynamic.initStr(buf);
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
