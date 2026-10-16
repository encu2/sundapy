const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub fn builtin_min(args: []const Dynamic) Dynamic {
    if (args.len == 0) {
        std.debug.panic("TypeError: min expected at least 1 argument, got 0\n", .{});
    }
    if (args.len == 1) {
        const self = args[0];
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            if (items.len == 0) std.debug.panic("ValueError: min() arg is an empty sequence\n", .{});
            var m = items[0];
            for (items[1..]) |it| {
                if (it.lt(m).value.bool_type) m = it;
            }
            return m;
        } else if (self.value == .tuple_type) {
            const items = self.value.tuple_type.items;
            if (items.len == 0) std.debug.panic("ValueError: min() arg is an empty sequence\n", .{});
            var m = items[0];
            for (items[1..]) |it| {
                if (it.lt(m).value.bool_type) m = it;
            }
            return m;
        }
        std.debug.panic("TypeError: min() arg is not iterable\n", .{});
        unreachable;
    }
    var m = args[0];
    for (args[1..]) |it| {
        if (it.lt(m).value.bool_type) m = it;
    }
    return m;
}

pub fn builtin_max(args: []const Dynamic) Dynamic {
    if (args.len == 0) {
        std.debug.panic("TypeError: max expected at least 1 argument, got 0\n", .{});
    }
    if (args.len == 1) {
        const self = args[0];
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            if (items.len == 0) std.debug.panic("ValueError: max() arg is an empty sequence\n", .{});
            var m = items[0];
            for (items[1..]) |it| {
                if (it.gt(m).value.bool_type) m = it;
            }
            return m;
        } else if (self.value == .tuple_type) {
            const items = self.value.tuple_type.items;
            if (items.len == 0) std.debug.panic("ValueError: max() arg is an empty sequence\n", .{});
            var m = items[0];
            for (items[1..]) |it| {
                if (it.gt(m).value.bool_type) m = it;
            }
            return m;
        }
        std.debug.panic("TypeError: max() arg is not iterable\n", .{});
        unreachable;
    }
    var m = args[0];
    for (args[1..]) |it| {
        if (it.gt(m).value.bool_type) m = it;
    }
    return m;
}

pub fn builtin_sum(self: Dynamic) Dynamic {
    if (self.value == .list_type) {
        const items = self.value.list_type.items.items;
        var sum = Dynamic.initInt(0);
        for (items) |it| {
            sum = sum.add(it);
        }
        return sum;
    }
    std.debug.panic("TypeError: sum() arg is not iterable\n", .{});
    unreachable;
}

pub fn builtin_abs(self: Dynamic) Dynamic {
    switch (self.value) {
        .i64_type => |i| return Dynamic.initInt(@as(i64, @intCast(@abs(i)))),
        .float_type => |f| return Dynamic.initFloat(@abs(f)),
        else => std.debug.panic("TypeError: bad operand type for abs()\n", .{}),
    }
}

pub fn builtin_round(self: Dynamic) Dynamic {
    switch (self.value) {
        .i64_type => return self,
        .float_type => |f| return Dynamic.initInt(@intFromFloat(@round(f))),
        else => std.debug.panic("TypeError: type doesn't define __round__ method\n", .{}),
    }
}

pub fn builtin_divmod(self: Dynamic, other: Dynamic) Dynamic {
    const q = self.floorDiv(other);
    const r = self.mod(other);
    const alloc = std.heap.page_allocator;
    const items = alloc.alloc(Dynamic, 2) catch unreachable;
    items[0] = q;
    items[1] = r;
    return Dynamic{ .value = .{ .tuple_type = .{ .items = items, .allocator = alloc } } };
}

pub fn builtin_pow(self: Dynamic, other: Dynamic) Dynamic {
    if (self.value == .i64_type and other.value == .i64_type) {
        return Dynamic.initInt(std.math.powi(i64, self.value.i64_type, other.value.i64_type) catch std.debug.panic("OverflowError: math range error\n", .{}));
    }
    std.debug.panic("TypeError: unsupported operand types for pow()\n", .{});
    unreachable;
}
