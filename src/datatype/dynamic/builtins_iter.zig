const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const sequence = @import("../sequence.zig");
const mapping = @import("../mapping.zig");

pub fn builtin_bytearray(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc;
    _ = arg;
    return Dynamic.initStr("bytearray(...)");
}
pub fn builtin_bytes(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc;
    _ = arg;
    return Dynamic.initStr("b'...'");
}
pub fn builtin_dict(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    const d = mapping.Dict.init(alloc) catch unreachable;
    if (arg.value != .none_type) {
        if (arg.value == .dict_type) {
            var it = arg.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                d.put(entry.value_ptr.key, entry.value_ptr.value) catch unreachable;
            }
        } else if (arg.value == .list_type or arg.value == .tuple_type) {
            const length = arg.len();
            var i: usize = 0;
            while (i < length) : (i += 1) {
                const pair = arg.getItem(i);
                if (pair.len() >= 2) {
                    const k = pair.getItem(0);
                    const v = pair.getItem(1);
                    d.put(k, v) catch unreachable;
                }
            }
        } else {
            std.debug.panic("TypeError: cannot convert non-dict to dict in sundapy yet\n", .{});
        }
    }
    return Dynamic{ .value = .{ .dict_type = d } };
}
pub fn builtin_frozenset(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    _ = alloc;
    _ = arg;
    return Dynamic.initStr("frozenset(...)");
}
pub fn builtin_list(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    var l = sequence.List.init();
    if (arg.value != .none_type) {
        if (arg.value == .dict_type) {
            var it = arg.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                l.items.append(alloc, entry.value_ptr.key) catch unreachable;
            }
        } else {
            const length = arg.len();
            var i: usize = 0;
            while (i < length) : (i += 1) {
                l.items.append(alloc, arg.getItem(i)) catch unreachable;
            }
        }
    }
    return Dynamic{ .value = .{ .list_type = l } };
}
pub fn builtin_set(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    var s = @import("../set.zig").Set.init(alloc);
    if (arg.value != .none_type) {
        if (arg.value == .dict_type) {
            var it = arg.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                s.add(alloc, entry.value_ptr.key) catch unreachable;
            }
        } else {
            const length = arg.len();
            var i: usize = 0;
            while (i < length) : (i += 1) {
                s.add(alloc, arg.getItem(i)) catch unreachable;
            }
        }
    }
    return Dynamic{ .value = .{ .set_type = s } };
}
pub fn builtin_tuple(alloc: std.mem.Allocator, arg: Dynamic) Dynamic {
    var l = sequence.List.init();
    if (arg.value != .none_type) {
        if (arg.value == .dict_type) {
            var it = arg.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                l.items.append(alloc, entry.value_ptr.key) catch unreachable;
            }
        } else {
            const length = arg.len();
            var i: usize = 0;
            while (i < length) : (i += 1) {
                l.items.append(alloc, arg.getItem(i)) catch unreachable;
            }
        }
    }

    const t = sequence.Tuple.init(alloc, l.items.items) catch unreachable;
    return Dynamic{ .value = .{ .tuple_type = t } };
}
