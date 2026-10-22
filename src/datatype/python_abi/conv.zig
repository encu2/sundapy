const std = @import("std");
const dynamic = @import("../dynamic.zig");
const Dynamic = dynamic.Dynamic;
const sym = @import("symbols.zig");

pub fn dynamicToPyObject(arg: Dynamic) ?*anyopaque {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    return switch (arg.value) {
        .none_type => {
            if (sym.py_none) |n| {
                sym.fn_Py_IncRef(n);
                return n;
            }
            return null;
        },
        .ellipsis_type => {
            if (sym.py_ellipsis) |e| {
                sym.fn_Py_IncRef(e);
                return e;
            }
            return null;
        },
        .str_type => |s| sym.fn_PyUnicode_FromStringAndSize(@ptrCast(s.ptr), @intCast(s.len)),
        .bytes_type => |b| sym.fn_PyBytes_FromStringAndSize(@ptrCast(b.ptr), @intCast(b.len)),
        .i64_type => |i| sym.fn_PyLong_FromLongLong(i),
        .i32_type => |i| sym.fn_PyLong_FromLongLong(@as(i64, i)),
        .i16_type => |i| sym.fn_PyLong_FromLongLong(@as(i64, i)),
        .i8_type => |i| sym.fn_PyLong_FromLongLong(@as(i64, i)),
        .u64_type => |u| sym.fn_PyLong_FromLongLong(@as(i64, @bitCast(u))),
        .u32_type => |u| sym.fn_PyLong_FromLongLong(@as(i64, u)),
        .u16_type => |u| sym.fn_PyLong_FromLongLong(@as(i64, u)),
        .u8_type => |u| sym.fn_PyLong_FromLongLong(@as(i64, u)),
        .float_type => |f| sym.fn_PyFloat_FromDouble(f),
        .bool_type => |b| sym.fn_PyBool_FromLong(if (b) 1 else 0),
        .py_obj_type => |p| {
            if (p) |ptr| sym.fn_Py_IncRef(ptr);
            return p;
        },
        .list_type => |l| {
            const py_list = sym.fn_PyList_New(@intCast(l.items.items.len)) orelse return null;
            for (l.items.items, 0..) |item, i| {
                const py_item = dynamicToPyObject(item) orelse (if (sym.py_none) |n| blk: {
                    sym.fn_Py_IncRef(n);
                    break :blk n;
                } else continue);
                _ = sym.fn_PyList_SetItem(py_list, @intCast(i), py_item);
            }
            return py_list;
        },
        .tuple_type => |t| {
            const py_tuple = sym.fn_PyTuple_New(@intCast(t.items.len)) orelse return null;
            for (t.items, 0..) |item, i| {
                const py_item = dynamicToPyObject(item) orelse (if (sym.py_none) |n| blk: {
                    sym.fn_Py_IncRef(n);
                    break :blk n;
                } else continue);
                _ = sym.fn_PyTuple_SetItem(py_tuple, @intCast(i), py_item);
            }
            return py_tuple;
        },
        .dict_type => |d| {
            const py_dict = sym.fn_PyDict_New() orelse return null;
            d.lock();
            defer d.unlock();
            var it = d.map.iterator();
            while (it.next()) |entry| {
                const py_k = dynamicToPyObject(entry.value_ptr.key) orelse continue;
                defer sym.fn_Py_DecRef(py_k);
                const v_obj = dynamicToPyObject(entry.value_ptr.value) orelse continue;
                if (sym.fn_PyObject_SetItem) |set_item| {
                    _ = set_item(py_dict, py_k, v_obj);
                } else if (entry.value_ptr.key.value == .str_type) {
                    const k_str = entry.value_ptr.key.value.str_type;
                    var c_str: [256]u8 = undefined;
                    if (k_str.len < 255) {
                        @memcpy(c_str[0..k_str.len], k_str);
                        c_str[k_str.len] = 0;
                        _ = sym.fn_PyDict_SetItemString(py_dict, &c_str, v_obj);
                    }
                }
                sym.fn_Py_DecRef(v_obj);
            }
            return py_dict;
        },

        else => null,
    };
}

pub fn getLength(obj: *anyopaque) usize {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const length = sym.fn_PyObject_Length(obj);
    if (length < 0) {
        sym.fn_PyErr_Clear();
        return 0;
    }
    return @intCast(length);
}

pub fn getItem(obj: *anyopaque, idx: usize) Dynamic {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const item = sym.fn_PySequence_GetItem(obj, @intCast(idx));
    if (item == null) {
        sym.fn_PyErr_Clear();
        return Dynamic{ .value = .{ .none_type = {} } };
    }
    if (sym.py_ellipsis != null and item.? == sym.py_ellipsis.?) {
        return Dynamic{ .value = .{ .ellipsis_type = {} } };
    }
    return Dynamic{ .value = .{ .py_obj_type = item.? } };
}

pub fn compare(obj1: *anyopaque, val2: Dynamic, op: c_int) bool {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const py_val2 = dynamicToPyObject(val2) orelse return false;
    defer sym.fn_Py_DecRef(py_val2);
    const res = sym.fn_PyObject_RichCompareBool(obj1, py_val2, op);
    if (res < 0) {
        sym.fn_PyErr_Clear();
        return false;
    }
    return res == 1;
}

pub fn isTrue(obj: *anyopaque) bool {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const res = sym.fn_PyObject_IsTrue(obj);
    if (res < 0) {
        sym.fn_PyErr_Clear();
        return false;
    }
    return res == 1;
}

pub fn getString(obj: *anyopaque) []const u8 {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const str_obj = sym.fn_PyObject_Str(obj);
    if (str_obj == null) {
        sym.fn_PyErr_Print();
        return "<error formatting python object>";
    }
    defer sym.fn_Py_DecRef(str_obj.?);
    const utf8 = sym.fn_PyUnicode_AsUTF8(str_obj.?);
    if (utf8 == null) {
        sym.fn_PyErr_Print();
        return "<error extracting python string>";
    }
    return std.mem.span(utf8.?);
}

fn dynamicListToPyTuple(l: anytype) ?*anyopaque {
    const py_tuple = sym.fn_PyTuple_New(@intCast(l.items.items.len)) orelse return null;
    for (l.items.items, 0..) |item, i| {
        const py_item = dynamicToPyObject(item) orelse (if (sym.py_none) |n| blk: {
            sym.fn_Py_IncRef(n);
            break :blk n;
        } else continue);
        _ = sym.fn_PyTuple_SetItem(py_tuple, @intCast(i), py_item);
    }
    return py_tuple;
}

pub fn getDynamicItem(obj: *anyopaque, alloc: std.mem.Allocator, key: Dynamic) !Dynamic {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    _ = alloc;
    const py_key = dynamicToPyObject(key);
    if (py_key == null) return error.PythonError;
    defer sym.fn_Py_DecRef(py_key.?);

    var item = sym.fn_PyObject_GetItem(obj, py_key.?);
    if (item == null and key.value == .list_type) {
        sym.fn_PyErr_Clear();
        if (dynamicListToPyTuple(key.value.list_type)) |pt| {
            defer sym.fn_Py_DecRef(pt);
            item = sym.fn_PyObject_GetItem(obj, pt);
        }
    }
    if (item == null) {
        sym.fn_PyErr_Print();
        return error.PythonError;
    }
    return Dynamic{ .value = .{ .py_obj_type = item.? } };
}

pub fn doMathReverse(val1: Dynamic, obj2: *anyopaque, op: []const u8) !Dynamic {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const py_val1 = dynamicToPyObject(val1);
    if (py_val1 == null) return error.TypeError;
    defer sym.fn_Py_DecRef(py_val1.?);

    var res: ?*anyopaque = null;
    if (std.mem.eql(u8, op, "+")) {
        res = sym.fn_PyNumber_Add(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "-")) {
        res = sym.fn_PyNumber_Subtract(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "*")) {
        res = sym.fn_PyNumber_Multiply(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "/")) {
        res = sym.fn_PyNumber_TrueDivide(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "//")) {
        if (sym.fn_PyNumber_FloorDivide) |f| res = f(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "%")) {
        if (sym.fn_PyNumber_Remainder) |f| res = f(py_val1.?, obj2);
    } else if (std.mem.eql(u8, op, "**")) {
        if (sym.fn_PyNumber_Power) |f| res = f(py_val1.?, obj2, sym.py_none orelse obj2);
    }

    if (res == null) {
        sym.fn_PyErr_Print();
        return error.MathError;
    }
    return Dynamic{ .value = .{ .py_obj_type = res } };
}

pub fn doMath(obj1: *anyopaque, val2: Dynamic, op: []const u8) !Dynamic {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);
    const py_val2 = dynamicToPyObject(val2);
    if (py_val2 == null) return error.TypeError;
    defer sym.fn_Py_DecRef(py_val2.?);

    var res: ?*anyopaque = null;
    if (std.mem.eql(u8, op, "+")) {
        res = sym.fn_PyNumber_Add(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "-")) {
        res = sym.fn_PyNumber_Subtract(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "*")) {
        res = sym.fn_PyNumber_Multiply(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "/")) {
        res = sym.fn_PyNumber_TrueDivide(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "//")) {
        if (sym.fn_PyNumber_FloorDivide) |f| res = f(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "%")) {
        if (sym.fn_PyNumber_Remainder) |f| res = f(obj1, py_val2.?);
    } else if (std.mem.eql(u8, op, "**")) {
        if (sym.fn_PyNumber_Power) |f| res = f(obj1, py_val2.?, sym.py_none orelse obj1);
    }

    if (res == null) {
        sym.fn_PyErr_Print();
        return error.MathError;
    }
    return Dynamic{ .value = .{ .py_obj_type = res } };
}

pub fn setDynamicItem(obj: *anyopaque, index: Dynamic, value: Dynamic) !void {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);

    const set_fn = sym.fn_PyObject_SetItem orelse return error.TypeError;
    const py_key = dynamicToPyObject(index) orelse return error.TypeError;
    defer sym.fn_Py_DecRef(py_key);

    const py_val = dynamicToPyObject(value) orelse return error.TypeError;
    defer sym.fn_Py_DecRef(py_val);

    var res = set_fn(obj, py_key, py_val);
    if (res != 0 and index.value == .list_type) {
        sym.fn_PyErr_Clear();
        if (dynamicListToPyTuple(index.value.list_type)) |pt| {
            defer sym.fn_Py_DecRef(pt);
            res = set_fn(obj, pt, py_val);
        }
    }
    if (res != 0) {
        sym.fn_PyErr_Clear();
        return error.KeyError;
    }
}

pub fn getDynamicSlice(obj: *anyopaque, start: Dynamic, stop: Dynamic, step: Dynamic) !Dynamic {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);

    const slice_fn = sym.fn_PySlice_New orelse return error.TypeError;
    const py_start: ?*anyopaque = if (start.value != .none_type) dynamicToPyObject(start) else null;
    defer if (py_start) |ps| sym.fn_Py_DecRef(ps);

    const py_stop: ?*anyopaque = if (stop.value != .none_type) dynamicToPyObject(stop) else null;
    defer if (py_stop) |ps| sym.fn_Py_DecRef(ps);

    const py_step: ?*anyopaque = if (step.value != .none_type) dynamicToPyObject(step) else null;
    defer if (py_step) |ps| sym.fn_Py_DecRef(ps);

    const slice_obj = slice_fn(py_start, py_stop, py_step) orelse return error.TypeError;
    defer sym.fn_Py_DecRef(slice_obj);

    const res_obj = sym.fn_PyObject_GetItem(obj, slice_obj) orelse return error.TypeError;
    return Dynamic{ .value = .{ .py_obj_type = res_obj } };
}

pub fn makePySlice(start: Dynamic, stop: Dynamic, step: Dynamic) ?*anyopaque {
    const _gstate = sym.fn_PyGILState_Ensure();
    defer sym.fn_PyGILState_Release(_gstate);

    const slice_fn = sym.fn_PySlice_New orelse return null;
    const py_start: ?*anyopaque = if (start.value != .none_type) dynamicToPyObject(start) else null;
    defer if (py_start) |ps| sym.fn_Py_DecRef(ps);

    const py_stop: ?*anyopaque = if (stop.value != .none_type) dynamicToPyObject(stop) else null;
    defer if (py_stop) |ps| sym.fn_Py_DecRef(ps);

    const py_step: ?*anyopaque = if (step.value != .none_type) dynamicToPyObject(step) else null;
    defer if (py_step) |ps| sym.fn_Py_DecRef(ps);

    return slice_fn(py_start, py_stop, py_step);
}

