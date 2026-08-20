const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;

var lib: ?std.DynLib = null;

var fn_PyNumber_Add: *const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyNumber_Subtract: *const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyNumber_Multiply: *const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyNumber_TrueDivide: *const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;

var fn_Py_Initialize: *const fn() callconv(.c) void = undefined;
var fn_Py_FinalizeEx: *const fn() callconv(.c) c_int = undefined;
var fn_PyUnicode_DecodeFSDefault: *const fn([*c]const u8) callconv(.c) *anyopaque = undefined;
var fn_Py_DecRef: *const fn(*anyopaque) callconv(.c) void = undefined;
var fn_PyImport_Import: *const fn(*anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyObject_CallObject: *const fn(*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyTuple_New: *const fn(isize) callconv(.c) ?*anyopaque = undefined;
var fn_PyTuple_SetItem: *const fn(*anyopaque, isize, *anyopaque) callconv(.c) c_int = undefined;
var fn_PyErr_Print: *const fn() callconv(.c) void = undefined;
var fn_PyObject_GetAttrString: *const fn(*anyopaque, [*c]const u8) callconv(.c) ?*anyopaque = undefined;
var fn_PyObject_Call: *const fn(*anyopaque, *anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyDict_New: *const fn() callconv(.c) ?*anyopaque = undefined;
var fn_PyDict_SetItemString: *const fn(*anyopaque, [*c]const u8, *anyopaque) callconv(.c) c_int = undefined;
var fn_PyUnicode_FromStringAndSize: *const fn([*c]const u8, isize) callconv(.c) ?*anyopaque = undefined;
var fn_PyLong_FromLongLong: *const fn(i64) callconv(.c) ?*anyopaque = undefined;
var fn_PyFloat_FromDouble: *const fn(f64) callconv(.c) ?*anyopaque = undefined;
var fn_PyBool_FromLong: *const fn(c_long) callconv(.c) ?*anyopaque = undefined;
var fn_PyObject_Length: *const fn(*anyopaque) callconv(.c) isize = undefined;
var fn_PySequence_GetItem: *const fn(*anyopaque, isize) callconv(.c) ?*anyopaque = undefined;
var fn_PyObject_Str: *const fn(*anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyUnicode_AsUTF8: *const fn(*anyopaque) callconv(.c) ?[*:0]const u8 = undefined;
var fn_PyObject_RichCompareBool: *const fn(*anyopaque, *anyopaque, c_int) callconv(.c) c_int = undefined;
var fn_PyObject_GetItem: *const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
var fn_PyUnicode_AsUTF8AndSize: *const fn(*anyopaque, ?*isize) callconv(.c) [*c]const u8 = undefined;
var fn_PyLong_AsLongLong: *const fn(*anyopaque) callconv(.c) i64 = undefined;
var fn_PyFloat_AsDouble: *const fn(*anyopaque) callconv(.c) f64 = undefined;
var fn_PyBool_Type: *anyopaque = undefined;

extern "c" fn dlopen(path: [*c]const u8, mode: c_int) ?*anyopaque;

var fn_PyList_New: *const fn(isize) callconv(.c) ?*anyopaque = undefined;
var fn_PyList_SetItem: *const fn(*anyopaque, isize, *anyopaque) callconv(.c) c_int = undefined;

pub const PikaPython = struct {
    pub fn init() !void {
        if (lib == null) {
            const names = [_][]const u8{
                "libpython3.14.so", "libpython3.14.so.1.0",
                "libpython3.13.so", "libpython3.13.so.1.0",
                "libpython3.12.so", "libpython3.12.so.1.0",
                "libpython3.11.so", "libpython3.11.so.1.0",
                "libpython3.10.so", "libpython3.10.so.1.0",
                "libpython3.so"
            };
            const builtin = @import("builtin");
            for (names) |name| {
                if (builtin.os.tag == .linux) {
                    const RTLD_LAZY = 2; // RTLD_NOW
                    const RTLD_GLOBAL = 256;
                    
                    // Convert to null-terminated C string manually to avoid allocation
                    var name_c: [256]u8 = undefined;
                    @memcpy(name_c[0..name.len], name);
                    name_c[name.len] = 0;
                    
                    if (dlopen(&name_c, RTLD_LAZY | RTLD_GLOBAL)) |handle| {
                        lib = std.DynLib{ .inner = .{ .handle = handle } };
                        break;
                    }
                } else {
                    if (std.DynLib.open(name)) |l| {
                        lib = l;
                        break;
                    } else |_| {}
                }
            }
            if (lib == null) return error.PythonRuntimeNotFound;

                        fn_PyNumber_Add = lib.?.lookup(*const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Add") orelse return error.MissingSymbol;
            fn_PyNumber_Subtract = lib.?.lookup(*const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Subtract") orelse return error.MissingSymbol;
            fn_PyNumber_Multiply = lib.?.lookup(*const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Multiply") orelse return error.MissingSymbol;
            fn_PyNumber_TrueDivide = lib.?.lookup(*const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_TrueDivide") orelse return error.MissingSymbol;

            fn_Py_Initialize = lib.?.lookup(*const fn() callconv(.c) void, "Py_Initialize") orelse return error.MissingSymbol;
            fn_Py_FinalizeEx = lib.?.lookup(*const fn() callconv(.c) c_int, "Py_FinalizeEx") orelse return error.MissingSymbol;
            fn_PyUnicode_DecodeFSDefault = lib.?.lookup(*const fn([*c]const u8) callconv(.c) *anyopaque, "PyUnicode_DecodeFSDefault") orelse return error.MissingSymbol;
            fn_Py_DecRef = lib.?.lookup(*const fn(*anyopaque) callconv(.c) void, "Py_DecRef") orelse return error.MissingSymbol;
            fn_PyImport_Import = lib.?.lookup(*const fn(*anyopaque) callconv(.c) ?*anyopaque, "PyImport_Import") orelse return error.MissingSymbol;
            fn_PyErr_Print = lib.?.lookup(*const fn() callconv(.c) void, "PyErr_Print") orelse return error.MissingSymbol;
            fn_PyTuple_New = lib.?.lookup(*const fn(isize) callconv(.c) ?*anyopaque, "PyTuple_New") orelse return error.MissingSymbol;
            fn_PyTuple_SetItem = lib.?.lookup(*const fn(*anyopaque, isize, *anyopaque) callconv(.c) c_int, "PyTuple_SetItem") orelse return error.MissingSymbol;
            
            fn_PyList_New = lib.?.lookup(*const fn(isize) callconv(.c) ?*anyopaque, "PyList_New") orelse return error.MissingSymbol;
            fn_PyList_SetItem = lib.?.lookup(*const fn(*anyopaque, isize, *anyopaque) callconv(.c) c_int, "PyList_SetItem") orelse return error.MissingSymbol;
            fn_PyObject_CallObject = lib.?.lookup(*const fn(*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque, "PyObject_CallObject") orelse return error.MissingSymbol;
            fn_PyObject_GetAttrString = lib.?.lookup(*const fn(*anyopaque, [*c]const u8) callconv(.c) ?*anyopaque, "PyObject_GetAttrString") orelse return error.MissingSymbol;
            fn_PyObject_Call = lib.?.lookup(*const fn(*anyopaque, *anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque, "PyObject_Call") orelse return error.MissingSymbol;
            fn_PyDict_New = lib.?.lookup(*const fn() callconv(.c) ?*anyopaque, "PyDict_New") orelse return error.MissingSymbol;
            fn_PyDict_SetItemString = lib.?.lookup(*const fn(*anyopaque, [*c]const u8, *anyopaque) callconv(.c) c_int, "PyDict_SetItemString") orelse return error.MissingSymbol;
            fn_PyUnicode_FromStringAndSize = lib.?.lookup(*const fn([*c]const u8, isize) callconv(.c) ?*anyopaque, "PyUnicode_FromStringAndSize") orelse return error.MissingSymbol;
            fn_PyLong_FromLongLong = lib.?.lookup(*const fn(i64) callconv(.c) ?*anyopaque, "PyLong_FromLongLong") orelse return error.MissingSymbol;
            fn_PyFloat_FromDouble = lib.?.lookup(*const fn(f64) callconv(.c) ?*anyopaque, "PyFloat_FromDouble") orelse return error.MissingSymbol;
            fn_PyBool_FromLong = lib.?.lookup(*const fn(c_long) callconv(.c) ?*anyopaque, "PyBool_FromLong") orelse return error.MissingSymbol;
            fn_PyObject_Length = lib.?.lookup(*const fn(*anyopaque) callconv(.c) isize, "PyObject_Length") orelse return error.MissingSymbol;
            fn_PySequence_GetItem = lib.?.lookup(*const fn(*anyopaque, isize) callconv(.c) ?*anyopaque, "PySequence_GetItem") orelse return error.MissingSymbol;
            fn_PyObject_Str = lib.?.lookup(*const fn(*anyopaque) callconv(.c) ?*anyopaque, "PyObject_Str") orelse return error.MissingSymbol;
            fn_PyUnicode_AsUTF8 = lib.?.lookup(*const fn(*anyopaque) callconv(.c) ?[*:0]const u8, "PyUnicode_AsUTF8") orelse return error.MissingSymbol;
            fn_PyObject_RichCompareBool = lib.?.lookup(*const fn(*anyopaque, *anyopaque, c_int) callconv(.c) c_int, "PyObject_RichCompareBool") orelse return error.MissingSymbol;
            fn_PyObject_GetItem = lib.?.lookup(*const fn(*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyObject_GetItem") orelse return error.MissingSymbol;
            fn_PyUnicode_AsUTF8AndSize = lib.?.lookup(*const fn(*anyopaque, ?*isize) callconv(.c) [*c]const u8, "PyUnicode_AsUTF8AndSize") orelse return error.MissingSymbol;
            fn_PyLong_AsLongLong = lib.?.lookup(*const fn(*anyopaque) callconv(.c) i64, "PyLong_AsLongLong") orelse return error.MissingSymbol;
            fn_PyFloat_AsDouble = lib.?.lookup(*const fn(*anyopaque) callconv(.c) f64, "PyFloat_AsDouble") orelse return error.MissingSymbol;
            fn_PyBool_Type = lib.?.lookup(*anyopaque, "PyBool_Type") orelse return error.MissingSymbol;


            fn_Py_Initialize();
        }
    }

    pub fn deinit() void {
        if (lib != null) {
            _ = fn_Py_FinalizeEx();
        }
    }

    pub fn importModule(name: [*c]const u8) !Dynamic {
        const py_name = fn_PyUnicode_DecodeFSDefault(name);
        defer fn_Py_DecRef(py_name);

        const module = fn_PyImport_Import(py_name);
        if (module == null) {
            fn_PyErr_Print();
            return error.ImportError;
        }

        return Dynamic{ .value = .{ .py_obj_type = module } };
    }

    pub fn getAttribute(obj: *anyopaque, attr: []const u8) !Dynamic {
        if (lib == null) return error.PythonNotLoaded;

        // Null-terminate the attribute string
        var attr_c: [256]u8 = undefined;
        if (attr.len >= 256) return error.AttributeTooLong;
        @memcpy(attr_c[0..attr.len], attr);
        attr_c[attr.len] = 0;

        const method_obj = fn_PyObject_GetAttrString(obj, @ptrCast(&attr_c));
        if (method_obj == null) {
            return error.AttributeNotFound;
        }

        return Dynamic{ .value = .{ .py_obj_type = method_obj } };
    }

    pub fn dynamicToPyObject(arg: Dynamic) ?*anyopaque {
        return switch (arg.value) {
            .str_type => |s| fn_PyUnicode_FromStringAndSize(@ptrCast(s.ptr), @intCast(s.len)),
            .i64_type => |i| fn_PyLong_FromLongLong(i),
            .float_type => |f| fn_PyFloat_FromDouble(f),
            .bool_type => |b| fn_PyBool_FromLong(if (b) 1 else 0),
            .py_obj_type => |p| p,
            .list_type => |l| {
                const py_list = fn_PyList_New(@intCast(l.items.items.len)) orelse return null;
                for (l.items.items, 0..) |item, i| {
                    const py_item = dynamicToPyObject(item) orelse continue;
                    _ = fn_PyList_SetItem(py_list, @intCast(i), py_item);
                }
                return py_list;
            },
            else => null,
        };
    }

    pub fn callObject(func: *anyopaque, alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) !Dynamic {
        _ = alloc;
        var args_tuple: ?*anyopaque = null;
        if (args.len > 0) {
            args_tuple = fn_PyTuple_New(@intCast(args.len));
            if (args_tuple == null) return error.PythonError;

            for (args, 0..) |arg, i| {
                const py_arg = dynamicToPyObject(arg) orelse continue; // Or return error?
                _ = fn_PyTuple_SetItem(args_tuple.?, @intCast(i), py_arg);
            }
        }
        
        const kwargs_dict: ?*anyopaque = null;
        if (kwargs) |_| {
            // kwargs_dict = fn_PyDict_New();
            // TODO: Populate dict from kwargs Dynamic
        }

        var res: ?*anyopaque = null;
        if (kwargs_dict != null) {
            res = fn_PyObject_Call(func, args_tuple, kwargs_dict);
        } else {
            res = fn_PyObject_CallObject(func, args_tuple);
        }
        
        if (args_tuple) |t| {
            fn_Py_DecRef(t);
        }
        if (kwargs_dict) |d| {
            fn_Py_DecRef(d);
        }
        if (res == null) {
            fn_PyErr_Print();
            return error.PythonError;
        }
        return Dynamic{ .value = .{ .py_obj_type = res.? } };
    }

    pub fn getLength(obj: *anyopaque) usize {
        const length = fn_PyObject_Length(obj);
        if (length < 0) {
            fn_PyErr_Print();
            return 0;
        }
        return @intCast(length);
    }

    pub fn getItem(obj: *anyopaque, idx: usize) Dynamic {
        const item = fn_PySequence_GetItem(obj, @intCast(idx));
        if (item == null) {
            fn_PyErr_Print();
            return Dynamic{ .value = .{ .none_type = {} } };
        }
        return Dynamic{ .value = .{ .py_obj_type = item.? } };
    }

    pub fn compare(obj1: *anyopaque, val2: @import("dynamic.zig").Dynamic, op: c_int) bool {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const py_val2 = dynamicToPyObject(val2) orelse return false;
        defer fn_Py_DecRef(py_val2);
        const res = fn_PyObject_RichCompareBool(obj1, py_val2, op);
        if (res < 0) {
            fn_PyErr_Print();
            return false;
        }
        return res == 1;
    }
    
    pub fn getString(obj: *anyopaque) []const u8 {
        const str_obj = fn_PyObject_Str(obj);
        if (str_obj == null) {
            fn_PyErr_Print();
            return "<error formatting python object>";
        }
        defer fn_Py_DecRef(str_obj.?);
        const utf8 = fn_PyUnicode_AsUTF8(str_obj.?);
        if (utf8 == null) {
            fn_PyErr_Print();
            return "<error extracting python string>";
        }
        return std.mem.span(utf8.?);
    }

    pub fn getDynamicItem(obj: *anyopaque, alloc: std.mem.Allocator, key: @import("dynamic.zig").Dynamic) !@import("dynamic.zig").Dynamic {
        _ = alloc;
        const py_key = dynamicToPyObject(key);
        if (py_key == null) return error.PythonError;
        defer fn_Py_DecRef(py_key.?);
        
        const item = fn_PyObject_GetItem(obj, py_key.?);
        if (item == null) {
            fn_PyErr_Print();
            return error.PythonError;
        }
        return @import("dynamic.zig").Dynamic{ .value = .{ .py_obj_type = item.? } };
    }
    
    pub fn doMathReverse(val1: @import("dynamic.zig").Dynamic, obj2: *anyopaque, op: []const u8) !@import("dynamic.zig").Dynamic {
        const py_val1 = dynamicToPyObject(val1);
        if (py_val1 == null) return error.TypeError;
        defer fn_Py_DecRef(py_val1.?);

        var res: ?*anyopaque = null;
        if (std.mem.eql(u8, op, "+")) {
            res = fn_PyNumber_Add(py_val1.?, obj2);
        } else if (std.mem.eql(u8, op, "-")) {
            res = fn_PyNumber_Subtract(py_val1.?, obj2);
        } else if (std.mem.eql(u8, op, "*")) {
            res = fn_PyNumber_Multiply(py_val1.?, obj2);
        } else if (std.mem.eql(u8, op, "/")) {
            res = fn_PyNumber_TrueDivide(py_val1.?, obj2);
        }

        if (res == null) {
            fn_PyErr_Print();
            return error.MathError;
        }
        return @import("dynamic.zig").Dynamic{ .value = .{ .py_obj_type = res } };
    }

    pub fn doMath(obj1: *anyopaque, val2: @import("dynamic.zig").Dynamic, op: []const u8) !@import("dynamic.zig").Dynamic {
        const py_val2 = dynamicToPyObject(val2);
        if (py_val2 == null) return error.TypeError;
        defer fn_Py_DecRef(py_val2.?);

        var res: ?*anyopaque = null;
        if (std.mem.eql(u8, op, "+")) {
            res = fn_PyNumber_Add(obj1, py_val2.?);
        } else if (std.mem.eql(u8, op, "-")) {
            res = fn_PyNumber_Subtract(obj1, py_val2.?);
        } else if (std.mem.eql(u8, op, "*")) {
            res = fn_PyNumber_Multiply(obj1, py_val2.?);
        } else if (std.mem.eql(u8, op, "/")) {
            res = fn_PyNumber_TrueDivide(obj1, py_val2.?);
        }

        if (res == null) {
            fn_PyErr_Print();
            return error.MathError;
        }
        return @import("dynamic.zig").Dynamic{ .value = .{ .py_obj_type = res } };
    }

};
