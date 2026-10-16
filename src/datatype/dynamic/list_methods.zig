const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;
const ops = @import("../dynamic_ops.zig");
const sequence = @import("../sequence.zig");
const mapping = @import("../mapping.zig");

    pub fn list_append(self: *Dynamic, alloc: std.mem.Allocator, item: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            try self.value.list_type.items.append(alloc, item);
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }
    pub fn list_insert(self: *Dynamic, alloc: std.mem.Allocator, index: Dynamic, item: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            if (index.value != .i64_type) std.debug.panic("TypeError: integer argument expected\n", .{});
            var idx = index.value.i64_type;
            const len_i64 = @as(i64, @intCast(self.value.list_type.items.items.len));
            if (idx < 0) idx += len_i64;
            if (idx < 0) idx = 0;
            if (idx > len_i64) idx = len_i64;
            try self.value.list_type.items.insert(alloc, @intCast(idx), item);
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }
    pub fn list_remove(self: *Dynamic, item: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            for (items, 0..) |it, i| {
                if (it.eq(item).value.bool_type) {
                    _ = self.value.list_type.items.orderedRemove(i);
                    return Dynamic.initNone();
                }
            }
            std.debug.panic("ValueError: list.remove(x): x not in list\n", .{});
        }
        return error.AttributeError;
    }
    pub fn list_reverse(self: *Dynamic) !Dynamic {
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            std.mem.reverse(Dynamic, items);
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }
    pub fn list_count(self: Dynamic, item: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            var c: i64 = 0;
            for (items) |it| {
                if (it.eq(item).value.bool_type) c += 1;
            }
            return Dynamic.initInt(c);
        } else if (self.value == .str_type and item.value == .str_type) {
            return Dynamic.initInt(@intCast(std.mem.count(u8, self.value.str_type, item.value.str_type)));
        }
        return error.AttributeError;
    }
    pub fn list_index(self: Dynamic, item: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            const items = self.value.list_type.items.items;
            for (items, 0..) |it, i| {
                if (it.eq(item).value.bool_type) return Dynamic.initInt(@intCast(i));
            }
            std.debug.panic("ValueError: list.index(x): x not in list\n", .{});
        }
        return error.AttributeError;
    }
    pub fn list_pop(self: *Dynamic) !Dynamic {
        if (self.value == .list_type) {
            return self.value.list_type.items.pop() orelse std.debug.panic("IndexError: pop from empty list\n", .{});
        }
        return error.AttributeError;
    }
    pub fn list_pop_at(self: *Dynamic, index: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            if (index.value != .i64_type) std.debug.panic("TypeError: integer argument expected\n", .{});
            var idx = index.value.i64_type;
            const len_i64 = @as(i64, @intCast(self.value.list_type.items.items.len));
            if (idx < 0) idx += len_i64;
            if (idx < 0 or idx >= len_i64) std.debug.panic("IndexError: pop index out of range\n", .{});
            return self.value.list_type.items.orderedRemove(@intCast(idx));
        }
        return error.AttributeError;
    }
    pub fn list_clear(self: *Dynamic) !Dynamic {
        if (self.value == .list_type) {
            self.value.list_type.items.clearRetainingCapacity();
            return Dynamic.initNone();
        } else if (self.value == .dict_type) {
            self.value.dict_type.lock();
            defer self.value.dict_type.unlock();
            self.value.dict_type.map.clearRetainingCapacity();
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }
    pub fn list_copy(self: Dynamic, alloc: std.mem.Allocator) !Dynamic {
        if (self.value == .list_type) {
            var new_list = std.ArrayList(Dynamic).empty;
            try new_list.ensureTotalCapacity(alloc, self.value.list_type.items.items.len);
            for (self.value.list_type.items.items) |item| {
                new_list.appendAssumeCapacity(item);
            }
            return Dynamic.initList(new_list);
        } else if (self.value == .dict_type) {
            self.value.dict_type.lock();
            defer self.value.dict_type.unlock();
            const new_dict = Dynamic.initDict(alloc);
            var it = self.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                try new_dict.value.dict_type.put(entry.value_ptr.key, entry.value_ptr.value);
            }

            return new_dict;
        }
        return error.AttributeError;
    }
    pub fn list_extend(self: *Dynamic, alloc: std.mem.Allocator, iterable: Dynamic) !Dynamic {
        if (self.value == .list_type) {
            if (iterable.value == .list_type) {
                try self.value.list_type.items.appendSlice(alloc, iterable.value.list_type.items.items);
                return Dynamic.initNone();
            } else if (iterable.value == .tuple_type) {
                try self.value.list_type.items.appendSlice(alloc, iterable.value.tuple_type.items);
                return Dynamic.initNone();
            } else {
                const count = iterable.len();
                var i: usize = 0;
                while (i < count) : (i += 1) {
                    try self.value.list_type.items.append(alloc, iterable.getItem(i));
                }
                return Dynamic.initNone();
            }
        }
        return error.AttributeError;
    }
    fn sortFn(context: void, a: Dynamic, b: Dynamic) bool {
        _ = context;
        return a.lt(b).value.bool_type;
    }
    
    pub fn list_sort(self: *Dynamic) !Dynamic {
        if (self.value == .list_type) {
            std.mem.sort(Dynamic, self.value.list_type.items.items, {}, sortFn);
            return Dynamic.initNone();
        }
        return error.AttributeError;
    }
