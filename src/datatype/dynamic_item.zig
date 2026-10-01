const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn len(self: Dynamic) usize {
    return switch (self.value) {
        .str_type => |s| s.len,
        .range_type => |r| if (r.step > 0) @intCast(@max(0, @divTrunc(r.stop - r.start + r.step - 1, r.step))) else @intCast(@max(0, @divTrunc(r.start - r.stop - r.step - 1, -r.step))),
        .list_type => |l| l.items.items.len,
        .tuple_type => |t| t.items.len,
        .py_obj_type => |p| if (p) |obj| @import("python_abi.zig").PikaPython.getLength(obj) else 0,
        else => 0,
    };
}

pub fn getItem(self: Dynamic, idx: usize) Dynamic {
    return switch (self.value) {
        .str_type => |s| .{ .value = .{ .str_type = s[idx..idx+1] } },
        .range_type => |r| .{ .value = .{ .i64_type = r.start + @as(i64, @intCast(idx)) * r.step } },
        .list_type => |l| l.items.items[idx],
        .tuple_type => |t| t.items[idx],
        .py_obj_type => |p| if (p) |obj| @import("python_abi.zig").PikaPython.getItem(obj, idx) else .{ .value = .{ .none_type = {} } },
        else => .{ .value = .{ .none_type = {} } },
    };
}

pub fn getDynamicItem(self: Dynamic, index: Dynamic) !Dynamic {
    if (self.value == .dict_type) {
        if (self.value.dict_type.get(index)) |val| {
            return val;
        } else {
            return error.KeyError;
        }
    } else if (self.value == .list_type) {
        if (index.value != .i64_type) return error.TypeError;
        var idx = index.value.i64_type;
        if (idx < 0) idx = @as(i64, @intCast(self.value.list_type.items.items.len)) + idx;
        if (idx < 0 or idx >= self.value.list_type.items.items.len) return error.IndexError;
        return self.value.list_type.items.items[@intCast(idx)];
    } else if (self.value == .str_type) {
        if (index.value != .i64_type) return error.TypeError;
        var idx = index.value.i64_type;
        if (idx < 0) idx = @as(i64, @intCast(self.value.str_type.len)) + idx;
        if (idx < 0 or idx >= self.value.str_type.len) return error.IndexError;
        const start = @as(usize, @intCast(idx));
        const end = start + 1;
        return Dynamic.initStr(self.value.str_type[start..end]);
    } else if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            return @import("python_abi.zig").PikaPython.getDynamicItem(obj, arena.allocator(), index) catch return error.KeyError;
        }
    }
    return error.TypeError;
}

pub fn setDynamicItem(self: Dynamic, index: Dynamic, value: Dynamic) !void {
    if (self.value == .dict_type) {
        try self.value.dict_type.put(index, value);
        return;
    } else if (self.value == .list_type) {
        if (index.value != .i64_type) return error.TypeError;
        var idx = index.value.i64_type;
        if (idx < 0) idx = @as(i64, @intCast(self.value.list_type.items.items.len)) + idx;
        if (idx < 0 or idx >= self.value.list_type.items.items.len) return error.IndexError;
        self.value.list_type.items.items[@intCast(idx)] = value;
        return;
    }
    return error.TypeError;
}

pub fn getDynamicSlice(self: Dynamic, start: Dynamic, stop: Dynamic, step: Dynamic) !Dynamic {
    if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            return @import("python_abi.zig").PikaPython.getDynamicSlice(obj, arena.allocator(), start, stop, step) catch return error.KeyError;
        }
    }
    // Minimal mock for slice on lists/strings...
    return error.TypeError;
}
