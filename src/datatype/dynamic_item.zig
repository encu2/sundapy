const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;

pub fn len(self: Dynamic) usize {
    return switch (self.value) {
        .str_type => |s| s.len,
        .range_type => |r| if (r.step > 0) @intCast(@max(0, @divTrunc(r.stop - r.start + r.step - 1, r.step))) else @intCast(@max(0, @divTrunc(r.start - r.stop - r.step - 1, -r.step))),
        .list_type => |l| l.items.items.len,
        .set_type => |s| s.items.items.len,
        .frozenset_type => |f| f.items.len,
        .tuple_type => |t| t.items.len,
        .py_obj_type => |p| if (p) |obj| @import("python_abi.zig").sundapyBridge.getLength(obj) else 0,
        .gpu_buffer_type => |g| @import("gpu_types.zig").bufferLen(g),
        else => 0,
    };
}

pub fn getItem(self: Dynamic, idx: usize) Dynamic {
    return switch (self.value) {
        .str_type => |s| .{ .value = .{ .str_type = s[idx..idx+1] } },
        .range_type => |r| .{ .value = .{ .i64_type = r.start + @as(i64, @intCast(idx)) * r.step } },
        .list_type => |l| l.items.items[idx],
        .tuple_type => |t| t.items[idx],
        .py_obj_type => |p| if (p) |obj| @import("python_abi.zig").sundapyBridge.getItem(obj, idx) else .{ .value = .{ .none_type = {} } },
        .gpu_buffer_type => |g| @import("gpu_types.zig").bufferGetItem(g, Dynamic.initInt(@intCast(idx))) catch .{ .value = .{ .none_type = {} } },
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
    } else if (self.value == .tuple_type) {
        if (index.value != .i64_type) return error.TypeError;
        var idx = index.value.i64_type;
        const t_len: i64 = @intCast(self.value.tuple_type.items.len);
        if (idx < 0) idx += t_len;
        if (idx < 0 or idx >= t_len) return error.IndexError;
        return self.value.tuple_type.items[@intCast(idx)];
    } else if (self.value == .range_type) {
        if (index.value != .i64_type) return error.TypeError;
        const r = self.value.range_type;
        var idx = index.value.i64_type;
        const r_len_i: i64 = if (r.step > 0) @max(0, @divTrunc(r.stop - r.start + r.step - 1, r.step)) else @max(0, @divTrunc(r.start - r.stop - r.step - 1, -r.step));
        if (idx < 0) idx += r_len_i;
        if (idx < 0 or idx >= r_len_i) return error.IndexError;
        return Dynamic.initInt(r.start + idx * r.step);
    } else if (self.value == .bytes_type) {
        if (index.value != .i64_type) return error.TypeError;
        const b = self.value.bytes_type;
        var idx = index.value.i64_type;
        const b_len: i64 = @intCast(b.len);
        if (idx < 0) idx += b_len;
        if (idx < 0 or idx >= b_len) return error.IndexError;
        return Dynamic.initInt(b[@intCast(idx)]);
    } else if (self.value == .bytearray_type) {
        if (index.value != .i64_type) return error.TypeError;
        const ba = self.value.bytearray_type;
        var idx = index.value.i64_type;
        const ba_len: i64 = @intCast(ba.list.items.len);
        if (idx < 0) idx += ba_len;
        if (idx < 0 or idx >= ba_len) return error.IndexError;
        return Dynamic.initInt(ba.list.items[@intCast(idx)]);
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
            return @import("python_abi.zig").sundapyBridge.getDynamicItem(obj, arena.allocator(), index) catch return error.KeyError;
        }
    } else if (self.value == .gpu_buffer_type) {
        return @import("gpu_types.zig").bufferGetItem(self.value.gpu_buffer_type, index);
    } else if (self.isFunction()) {
        return @import("gpu_types.zig").createBoundKernel(self, index);
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
    } else if (self.value == .bytearray_type) {
        if (index.value != .i64_type) return error.TypeError;
        var idx = index.value.i64_type;
        const items = self.value.bytearray_type.list.items;
        if (idx < 0) idx = @as(i64, @intCast(items.len)) + idx;
        if (idx < 0 or idx >= items.len) return error.IndexError;
        const v = value.toInt();
        if (v < 0 or v > 255) return error.ValueError;
        items[@intCast(idx)] = @intCast(v);
        return;
    } else if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            return @import("python_abi.zig").sundapyBridge.setDynamicItem(obj, index, value);
        }
    } else if (self.value == .gpu_buffer_type) {
        return @import("gpu_types.zig").bufferSetItem(self.value.gpu_buffer_type, index, value);
    }
    return error.TypeError;
}


const SliceIndices = struct {
    start: i64,
    stop: i64,
    step: i64,
};

fn sliceIndexOpt(d: Dynamic) ?i64 {
    return switch (d.value) {
        .i64_type => |v| v,
        .bool_type => |v| if (v) 1 else 0,
        else => null,
    };
}

fn adjustSliceIndices(length: usize, start: Dynamic, stop: Dynamic, step: Dynamic) !SliceIndices {
    const len_i64: i64 = @intCast(length);
    const step_val: i64 = sliceIndexOpt(step) orelse 1;
    if (step_val == 0) return error.ValueError;

    var start_val: i64 = 0;
    var stop_val: i64 = 0;

    const opt_start = sliceIndexOpt(start);
    const opt_stop = sliceIndexOpt(stop);

    if (step_val > 0) {
        start_val = opt_start orelse 0;
        stop_val = opt_stop orelse len_i64;
        if (start_val < 0) start_val += len_i64;
        if (start_val < 0) start_val = 0;
        if (start_val > len_i64) start_val = len_i64;
        if (stop_val < 0) stop_val += len_i64;
        if (stop_val < 0) stop_val = 0;
        if (stop_val > len_i64) stop_val = len_i64;
    } else {
        start_val = opt_start orelse (len_i64 - 1);
        stop_val = opt_stop orelse -1;
        if (start_val < 0) start_val += len_i64;
        if (start_val < -1) start_val = -1;
        if (start_val >= len_i64) start_val = len_i64 - 1;
        if (opt_stop != null) {
            if (stop_val < 0) stop_val += len_i64;
            if (stop_val < -1) stop_val = -1;
            if (stop_val >= len_i64) stop_val = len_i64 - 1;
        } else {
            stop_val = -1;
        }
    }

    return .{ .start = start_val, .stop = stop_val, .step = step_val };
}

pub fn getDynamicSlice(self: Dynamic, start: Dynamic, stop: Dynamic, step: Dynamic) !Dynamic {
    if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            return @import("python_abi.zig").sundapyBridge.getDynamicSlice(obj, start, stop, step);
        }
        return error.TypeError;
    } else if (self.value == .str_type) {
        const s = self.value.str_type;
        const indices = try adjustSliceIndices(s.len, start, stop, step);
        if (indices.step == 1) {
            if (indices.start >= indices.stop) return Dynamic.initStr("");
            const ustart: usize = @intCast(indices.start);
            const ustop: usize = @intCast(indices.stop);
            return Dynamic.initStr(s[ustart..ustop]);
        }
        const alloc = std.heap.page_allocator;
        var buf = std.ArrayList(u8).empty;
        var i = indices.start;
        if (indices.step > 0) {
            while (i < indices.stop) : (i += indices.step) {
                try buf.append(alloc, s[@intCast(i)]);
            }
        } else {
            while (i > indices.stop) : (i += indices.step) {
                try buf.append(alloc, s[@intCast(i)]);
            }
        }
        return Dynamic.initStr(try buf.toOwnedSlice(alloc));
    } else if (self.value == .bytes_type) {
        const b = self.value.bytes_type;
        const indices = try adjustSliceIndices(b.len, start, stop, step);
        if (indices.step == 1) {
            if (indices.start >= indices.stop) return Dynamic{ .value = .{ .bytes_type = "" } };
            const ustart: usize = @intCast(indices.start);
            const ustop: usize = @intCast(indices.stop);
            return Dynamic{ .value = .{ .bytes_type = b[ustart..ustop] } };
        }
        const alloc = std.heap.page_allocator;
        var buf = std.ArrayList(u8).empty;
        var i = indices.start;
        if (indices.step > 0) {
            while (i < indices.stop) : (i += indices.step) {
                try buf.append(alloc, b[@intCast(i)]);
            }
        } else {
            while (i > indices.stop) : (i += indices.step) {
                try buf.append(alloc, b[@intCast(i)]);
            }
        }
        return Dynamic{ .value = .{ .bytes_type = try buf.toOwnedSlice(alloc) } };
    } else if (self.value == .list_type) {
        const items = self.value.list_type.items.items;
        const indices = try adjustSliceIndices(items.len, start, stop, step);
        const alloc = std.heap.page_allocator;
        var new_list = std.ArrayList(Dynamic).empty;
        var i = indices.start;
        if (indices.step > 0) {
            while (i < indices.stop) : (i += indices.step) {
                try new_list.append(alloc, items[@intCast(i)]);
            }
        } else {
            while (i > indices.stop) : (i += indices.step) {
                try new_list.append(alloc, items[@intCast(i)]);
            }
        }
        return Dynamic.initList(new_list);
    } else if (self.value == .tuple_type) {
        const items = self.value.tuple_type.items;
        const indices = try adjustSliceIndices(items.len, start, stop, step);
        const alloc = std.heap.page_allocator;
        var new_items = std.ArrayList(Dynamic).empty;
        defer new_items.deinit(alloc);
        var i = indices.start;
        if (indices.step > 0) {
            while (i < indices.stop) : (i += indices.step) {
                try new_items.append(alloc, items[@intCast(i)]);
            }
        } else {
            while (i > indices.stop) : (i += indices.step) {
                try new_items.append(alloc, items[@intCast(i)]);
            }
        }
        const tuple = try @import("sequence/list.zig").Tuple.init(alloc, new_items.items);
        return Dynamic{ .value = .{ .tuple_type = tuple } };
    }
    return error.TypeError;
}

