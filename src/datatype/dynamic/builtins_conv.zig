const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub fn builtin_int(self: Dynamic) Dynamic {
    switch (self.value) {
        .i64_type => return self,
        .i32_type => |v| return Dynamic.initInt(v),
        .i16_type => |v| return Dynamic.initInt(v),
        .i8_type => |v| return Dynamic.initInt(v),
        .u64_type => |v| return Dynamic.initInt(@bitCast(v)),
        .u32_type => |v| return Dynamic.initInt(v),
        .u16_type => |v| return Dynamic.initInt(v),
        .u8_type => |v| return Dynamic.initInt(v),
        .bool_type => |b| return Dynamic.initInt(if (b) 1 else 0),
        .float_type => |f| return Dynamic.initInt(@as(i64, @intFromFloat(f))),
        .str_type => |s| {
            const val = std.fmt.parseInt(i64, s, 10) catch std.debug.panic("ValueError: invalid literal for int() with base 10: {s}\n", .{s});
            return Dynamic.initInt(val);
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").sundapyBridge.getString(obj);
                const val = std.fmt.parseInt(i64, s, 10) catch 0;
                return Dynamic.initInt(val);
            }
            return Dynamic.initInt(0);
        },
        else => std.debug.panic("TypeError: int() argument must be a string, a bytes-like object or a real number\n", .{}),
    }
}
pub fn builtin_float(self: Dynamic) Dynamic {
    switch (self.value) {
        .float_type => return self,
        .i64_type => |i| return Dynamic.initFloat(@as(f64, @floatFromInt(i))),
        .i32_type => |i| return Dynamic.initFloat(@as(f64, @floatFromInt(i))),
        .i16_type => |i| return Dynamic.initFloat(@as(f64, @floatFromInt(i))),
        .i8_type => |i| return Dynamic.initFloat(@as(f64, @floatFromInt(i))),
        .u64_type => |u| return Dynamic.initFloat(@as(f64, @floatFromInt(u))),
        .u32_type => |u| return Dynamic.initFloat(@as(f64, @floatFromInt(u))),
        .u16_type => |u| return Dynamic.initFloat(@as(f64, @floatFromInt(u))),
        .u8_type => |u| return Dynamic.initFloat(@as(f64, @floatFromInt(u))),
        .bool_type => |b| return Dynamic.initFloat(if (b) 1.0 else 0.0),
        .str_type => |s| {
            const val = std.fmt.parseFloat(f64, s) catch std.debug.panic("ValueError: could not convert string to float: {s}\n", .{s});
            return Dynamic.initFloat(val);
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").sundapyBridge.getString(obj);
                const val = std.fmt.parseFloat(f64, s) catch 0.0;
                return Dynamic.initFloat(val);
            }
            return Dynamic.initFloat(0.0);
        },
        else => std.debug.panic("TypeError: float() argument must be a string or a real number\n", .{}),
    }
}
pub fn builtin_str(self: Dynamic, alloc: std.mem.Allocator) Dynamic {
    switch (self.value) {
        .str_type => return self,
        .i8_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i16_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i32_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i64_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i128_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i256_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i512_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .i1024_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u8_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u16_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u32_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u64_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u128_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u256_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u512_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .u1024_type => |v| return Dynamic.initStr(std.fmt.allocPrint(alloc, "{d}", .{v}) catch "0"),
        .float_type => |f| {
            const s = std.fmt.allocPrint(alloc, "{d}", .{f}) catch unreachable;
            return Dynamic.initStr(s);
        },
        .complex_type => |v| {
            const s = std.fmt.allocPrint(alloc, "{d}+{d}j", .{ v.re, v.im }) catch unreachable;
            return Dynamic.initStr(s);
        },
        .bool_type => |b| {
            if (b) return Dynamic.initStr("True");
            return Dynamic.initStr("False");
        },
        .none_type => return Dynamic.initStr("None"),
        .ellipsis_type => return Dynamic.initStr("Ellipsis"),
        .list_type => |l| {
            var buf: std.ArrayList(u8) = .empty;
            buf.append(alloc, '[') catch unreachable;
            for (l.items.items, 0..) |item, idx| {
                const str_item = item.builtin_str(alloc);
                if (item.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                }
                if (idx < l.items.items.len - 1) buf.appendSlice(alloc, ", ") catch unreachable;
            }
            buf.append(alloc, ']') catch unreachable;
            return Dynamic.initStr(buf.toOwnedSlice(alloc) catch "[]");
        },
        .dict_type => |d| {
            var buf: std.ArrayList(u8) = .empty;
            buf.append(alloc, '{') catch unreachable;
            var it = d.map.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) buf.appendSlice(alloc, ", ") catch unreachable;
                first = false;
                const k_dyn = entry.value_ptr.key;
                const v_dyn = entry.value_ptr.value;
                const k_str = k_dyn.builtin_str(alloc);
                if (k_dyn.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, k_str.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, k_str.value.str_type) catch unreachable;
                }
                buf.appendSlice(alloc, ": ") catch unreachable;
                const val_str = v_dyn.builtin_str(alloc);
                if (v_dyn.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, val_str.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, val_str.value.str_type) catch unreachable;
                }
            }
            buf.append(alloc, '}') catch unreachable;
            return Dynamic.initStr(buf.toOwnedSlice(alloc) catch "{}");
        },

        .tuple_type => |t| {
            if (t.items.len == 0) return Dynamic.initStr("()");
            var buf: std.ArrayList(u8) = .empty;
            buf.append(alloc, '(') catch unreachable;
            for (t.items, 0..) |item, idx| {
                const str_item = item.builtin_str(alloc);
                if (item.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                }
                if (t.items.len == 1) {
                    buf.append(alloc, ',') catch unreachable;
                } else if (idx < t.items.len - 1) {
                    buf.appendSlice(alloc, ", ") catch unreachable;
                }
            }
            buf.append(alloc, ')') catch unreachable;
            return Dynamic.initStr(buf.toOwnedSlice(alloc) catch "()");
        },
        .set_type => |s| {
            if (s.items.items.len == 0) return Dynamic.initStr("set()");
            var buf: std.ArrayList(u8) = .empty;
            buf.append(alloc, '{') catch unreachable;
            for (s.items.items, 0..) |item, idx| {
                const str_item = item.builtin_str(alloc);
                if (item.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                }
                if (idx < s.items.items.len - 1) buf.appendSlice(alloc, ", ") catch unreachable;
            }
            buf.append(alloc, '}') catch unreachable;
            return Dynamic.initStr(buf.toOwnedSlice(alloc) catch "set()");
        },
        .frozenset_type => |fs| {
            if (fs.items.len == 0) return Dynamic.initStr("frozenset()");
            var buf: std.ArrayList(u8) = .empty;
            buf.appendSlice(alloc, "frozenset({") catch unreachable;
            for (fs.items, 0..) |item, idx| {
                const str_item = item.builtin_str(alloc);
                if (item.value == .str_type) {
                    buf.append(alloc, '\'') catch unreachable;
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                    buf.append(alloc, '\'') catch unreachable;
                } else {
                    buf.appendSlice(alloc, str_item.value.str_type) catch unreachable;
                }
                if (idx < fs.items.len - 1) buf.appendSlice(alloc, ", ") catch unreachable;
            }
            buf.appendSlice(alloc, "})") catch unreachable;
            return Dynamic.initStr(buf.toOwnedSlice(alloc) catch "frozenset()");
        },
        .range_type => |r| {
            if (r.step == 1) {
                return Dynamic.initStr(std.fmt.allocPrint(alloc, "range({d}, {d})", .{ r.start, r.stop }) catch "range(...)");
            } else {
                return Dynamic.initStr(std.fmt.allocPrint(alloc, "range({d}, {d}, {d})", .{ r.start, r.stop, r.step }) catch "range(...)");
            }
        },
        .bytes_type => |b| {
            const s = std.fmt.allocPrint(alloc, "b'{s}'", .{b}) catch "b''";
            return Dynamic.initStr(s);
        },
        .bytearray_type => |b| {
            const s = std.fmt.allocPrint(alloc, "bytearray(b'{s}')", .{b.list.items}) catch "bytearray(...)";
            return Dynamic.initStr(s);
        },
        .py_obj_type => |p| {
            if (p) |obj| {
                const s = @import("../python_abi.zig").sundapyBridge.getString(obj);
                return Dynamic.initStr(s);
            }
            return Dynamic.initStr("None");
        },
        else => return Dynamic.initStr("<object>"),
    }
}

pub fn stringifyStr(allocator: std.mem.Allocator, val: anytype) []const u8 {
    const T = @TypeOf(val);
    if (T == Dynamic) {
        return val.builtin_str(allocator).value.str_type;
    } else if (T == []const u8 or T == [:0]const u8 or T == []u8 or T == [:0]u8) {
        return val;
    } else if (T == bool) {
        return if (val) "True" else "False";
    } else if (T == @TypeOf(null)) {
        return "None";
    } else {
        const info = @typeInfo(T);
        switch (info) {
            .pointer => |ptr| {
                if (ptr.size == .one) {
                    const child_info = @typeInfo(ptr.child);
                    if (child_info == .array and child_info.array.child == u8) {
                        return val[0..];
                    }
                } else if (ptr.size == .slice and ptr.child == u8) {
                    return val;
                }
            },
            .optional => {
                if (val) |unwrapped| {
                    return stringifyStr(allocator, unwrapped);
                } else {
                    return "None";
                }
            },
            .int, .comptime_int => {
                return std.fmt.allocPrint(allocator, "{d}", .{val}) catch "0";
            },
            .float, .comptime_float => {
                return std.fmt.allocPrint(allocator, "{d}", .{val}) catch "0.0";
            },
            else => {},
        }
        return std.fmt.allocPrint(allocator, "{any}", .{val}) catch "<error>";
    }
}
pub fn builtin_bool(self: Dynamic) Dynamic {
    return Dynamic.initBool(self.toBool());
}

pub fn toInt(self: Dynamic) i64 {
    return switch (self.value) {
        .i64_type => |v| v,
        .i32_type => |v| v,
        .i16_type => |v| v,
        .i8_type => |v| v,
        .u64_type => |v| @bitCast(v),
        .u32_type => |v| @intCast(v),
        .u16_type => |v| @intCast(v),
        .u8_type => |v| @intCast(v),
        .bool_type => |b| if (b) 1 else 0,
        .float_type => |f| @intFromFloat(f),
        else => 0,
    };
}

pub fn toFloat(self: Dynamic) f64 {
    return switch (self.value) {
        .float_type => |f| f,
        .i64_type => |v| @floatFromInt(v),
        .i32_type => |v| @floatFromInt(v),
        .i16_type => |v| @floatFromInt(v),
        .i8_type => |v| @floatFromInt(v),
        .u64_type => |v| @floatFromInt(v),
        .u32_type => |v| @floatFromInt(v),
        .u16_type => |v| @floatFromInt(v),
        .u8_type => |v| @floatFromInt(v),
        .bool_type => |b| if (b) 1.0 else 0.0,
        else => 0.0,
    };
}

