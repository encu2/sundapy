const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const methods_case = @import("../sequence/string/methods_case.zig");
const methods_split = @import("../sequence/string/methods_split.zig");

pub fn str_split(self: Dynamic, allocator: std.mem.Allocator, sep: ?Dynamic) !Dynamic {
    return str_split_max(self, allocator, sep, null);
}

pub fn str_split_max(self: Dynamic, allocator: std.mem.Allocator, sep: ?Dynamic, maxsplit: ?Dynamic) !Dynamic {
    if (self.value != .str_type) return error.TypeError;

    const max_s: isize = if (maxsplit) |ms| switch (ms.value) {
        .i64_type => |i| @intCast(i),
        .i32_type => |i| @intCast(i),
        else => -1,
    } else -1;

    if (sep) |s| {
        if (s.value == .str_type) {
            var slices = try methods_split.split(allocator, self.value.str_type, s.value.str_type, max_s);
            defer slices.deinit(allocator);

            var dynamic_list: std.ArrayList(Dynamic) = .empty;
            try dynamic_list.ensureTotalCapacity(allocator, slices.items.len);
            for (slices.items) |slice| {
                dynamic_list.appendAssumeCapacity(Dynamic.initStr(slice));
            }

            return Dynamic.initList(dynamic_list);
        }
    }

    var slices = try methods_split.splitWhitespace(allocator, self.value.str_type, max_s);
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
    const items: []const Dynamic = switch (iterable.value) {
        .list_type => |l| l.items.items,
        .tuple_type => |t| t.items,
        else => return error.TypeError,
    };

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

pub fn str_startswith(self: Dynamic, allocator: std.mem.Allocator, prefix: Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type or prefix.value != .str_type) return error.TypeError;
    return Dynamic.initBool(std.mem.startsWith(u8, self.value.str_type, prefix.value.str_type));
}

pub fn str_endswith(self: Dynamic, allocator: std.mem.Allocator, suffix: Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type or suffix.value != .str_type) return error.TypeError;
    return Dynamic.initBool(std.mem.endsWith(u8, self.value.str_type, suffix.value.str_type));
}

pub fn str_find(self: Dynamic, allocator: std.mem.Allocator, sub: Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type or sub.value != .str_type) return error.TypeError;
    if (std.mem.indexOf(u8, self.value.str_type, sub.value.str_type)) |idx| {
        return Dynamic.initInt(@intCast(idx));
    }
    return Dynamic.initInt(-1);
}

pub fn str_strip(self: Dynamic, allocator: std.mem.Allocator, chars: ?Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type) return error.TypeError;
    const trim_chars = if (chars != null and chars.?.value == .str_type) chars.?.value.str_type else " \t\r\n";
    const res = std.mem.trim(u8, self.value.str_type, trim_chars);
    return Dynamic.initStr(res);
}

pub fn str_lstrip(self: Dynamic, allocator: std.mem.Allocator, chars: ?Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type) return error.TypeError;
    const trim_chars = if (chars != null and chars.?.value == .str_type) chars.?.value.str_type else " \t\r\n";
    const res = std.mem.trimStart(u8, self.value.str_type, trim_chars);
    return Dynamic.initStr(res);
}

pub fn str_rstrip(self: Dynamic, allocator: std.mem.Allocator, chars: ?Dynamic) !Dynamic {
    _ = allocator;
    if (self.value != .str_type) return error.TypeError;
    const trim_chars = if (chars != null and chars.?.value == .str_type) chars.?.value.str_type else " \t\r\n";
    const res = std.mem.trimEnd(u8, self.value.str_type, trim_chars);
    return Dynamic.initStr(res);
}
