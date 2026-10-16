const std = @import("std");

pub var lib: ?std.DynLib = null;

pub var fn_PyNumber_Add: *const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyNumber_Subtract: *const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyNumber_Multiply: *const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyNumber_TrueDivide: *const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyNumber_FloorDivide: ?*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = null;
pub var fn_PyNumber_Remainder: ?*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = null;
pub var fn_PyNumber_Power: ?*const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.c) ?*anyopaque = null;
pub var fn_PyCallable_Check: ?*const fn (*anyopaque) callconv(.c) c_int = null;
pub var fn_PyObject_SetItem: ?*const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.c) c_int = null;
pub var fn_PySlice_New: ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque = null;


pub var fn_Py_Initialize: *const fn () callconv(.c) void = undefined;
pub var fn_PyRun_SimpleString: *const fn ([*c]const u8) callconv(.c) c_int = undefined;
pub var fn_Py_FinalizeEx: *const fn () callconv(.c) c_int = undefined;
pub var fn_PyUnicode_DecodeFSDefault: *const fn ([*c]const u8) callconv(.c) *anyopaque = undefined;
pub var fn_Py_IncRef: *const fn (*anyopaque) callconv(.c) void = undefined;
pub var fn_Py_DecRef: *const fn (*anyopaque) callconv(.c) void = undefined;
pub var fn_PyImport_Import: *const fn (*anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyObject_CallObject: *const fn (*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque = undefined;

pub var fn_PyEval_SaveThread: *const fn () callconv(.c) ?*anyopaque = undefined;
pub var fn_PyEval_RestoreThread: *const fn (?*anyopaque) callconv(.c) void = undefined;
pub var fn_PyGILState_Ensure: *const fn () callconv(.c) c_int = undefined;
pub var fn_PyGILState_Release: *const fn (c_int) callconv(.c) void = undefined;
pub var _main_thread_state: ?*anyopaque = null;
pub var fn_PyTuple_New: *const fn (isize) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyTuple_SetItem: *const fn (*anyopaque, isize, *anyopaque) callconv(.c) c_int = undefined;
pub var fn_PyErr_Print: *const fn () callconv(.c) void = undefined;
pub var fn_PyErr_Clear: *const fn () callconv(.c) void = undefined;
pub var fn_PyObject_GetAttrString: *const fn (*anyopaque, [*c]const u8) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyObject_Call: *const fn (*anyopaque, *anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyDict_New: *const fn () callconv(.c) ?*anyopaque = undefined;
pub var fn_PyDict_SetItemString: *const fn (*anyopaque, [*c]const u8, *anyopaque) callconv(.c) c_int = undefined;
pub var fn_PyUnicode_FromStringAndSize: *const fn ([*c]const u8, isize) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyBytes_FromStringAndSize: *const fn ([*c]const u8, isize) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyLong_FromLongLong: *const fn (i64) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyFloat_FromDouble: *const fn (f64) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyBool_FromLong: *const fn (c_long) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyObject_Length: *const fn (*anyopaque) callconv(.c) isize = undefined;
pub var fn_PySequence_GetItem: *const fn (*anyopaque, isize) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyObject_Str: *const fn (*anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyUnicode_AsUTF8: *const fn (*anyopaque) callconv(.c) ?[*:0]const u8 = undefined;
pub var fn_PyObject_RichCompareBool: *const fn (*anyopaque, *anyopaque, c_int) callconv(.c) c_int = undefined;
pub var fn_PyObject_GetItem: *const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyUnicode_AsUTF8AndSize: *const fn (*anyopaque, ?*isize) callconv(.c) [*c]const u8 = undefined;
pub var fn_PyLong_AsLongLong: *const fn (*anyopaque) callconv(.c) i64 = undefined;
pub var fn_PyFloat_AsDouble: *const fn (*anyopaque) callconv(.c) f64 = undefined;
pub var fn_PyBool_Type: *anyopaque = undefined;
pub var fn_PyObject_IsTrue: *const fn (*anyopaque) callconv(.c) c_int = undefined;
pub var py_none: ?*anyopaque = null;

extern "c" fn dlopen(path: [*c]const u8, mode: c_int) ?*anyopaque;

pub var fn_PyList_New: *const fn (isize) callconv(.c) ?*anyopaque = undefined;
pub var fn_PyList_SetItem: *const fn (*anyopaque, isize, *anyopaque) callconv(.c) c_int = undefined;

pub fn loadSymbols() !void {
    if (lib != null) return;

    const names = [_][]const u8{ "libpython3.14.so", "libpython3.14.so.1.0", "libpython3.13.so", "libpython3.13.so.1.0", "libpython3.12.so", "libpython3.12.so.1.0", "libpython3.11.so", "libpython3.11.so.1.0", "libpython3.10.so", "libpython3.10.so.1.0", "libpython3.so" };
    const builtin = @import("builtin");
    for (names) |name| {
        if (builtin.os.tag == .linux) {
            const RTLD_LAZY = 2; // RTLD_NOW
            const RTLD_GLOBAL = 256;

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

    fn_PyNumber_Add = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Add") orelse return error.MissingSymbol;
    fn_PyNumber_Subtract = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Subtract") orelse return error.MissingSymbol;
    fn_PyNumber_Multiply = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Multiply") orelse return error.MissingSymbol;
    fn_PyNumber_TrueDivide = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_TrueDivide") orelse return error.MissingSymbol;

    fn_Py_Initialize = lib.?.lookup(*const fn () callconv(.c) void, "Py_Initialize") orelse return error.MissingSymbol;
    fn_PyRun_SimpleString = lib.?.lookup(*const fn ([*c]const u8) callconv(.c) c_int, "PyRun_SimpleString") orelse return error.MissingSymbol;
    fn_Py_FinalizeEx = lib.?.lookup(*const fn () callconv(.c) c_int, "Py_FinalizeEx") orelse return error.MissingSymbol;
    fn_PyUnicode_DecodeFSDefault = lib.?.lookup(*const fn ([*c]const u8) callconv(.c) *anyopaque, "PyUnicode_DecodeFSDefault") orelse return error.MissingSymbol;
    fn_Py_IncRef = lib.?.lookup(*const fn (*anyopaque) callconv(.c) void, "Py_IncRef") orelse return error.MissingSymbol;
    fn_Py_DecRef = lib.?.lookup(*const fn (*anyopaque) callconv(.c) void, "Py_DecRef") orelse return error.MissingSymbol;
    fn_PyImport_Import = lib.?.lookup(*const fn (*anyopaque) callconv(.c) ?*anyopaque, "PyImport_Import") orelse return error.MissingSymbol;
    fn_PyErr_Print = lib.?.lookup(*const fn () callconv(.c) void, "PyErr_Print") orelse return error.MissingSymbol;
    fn_PyErr_Clear = lib.?.lookup(*const fn () callconv(.c) void, "PyErr_Clear") orelse return error.MissingSymbol;
    fn_PyTuple_New = lib.?.lookup(*const fn (isize) callconv(.c) ?*anyopaque, "PyTuple_New") orelse return error.MissingSymbol;
    fn_PyTuple_SetItem = lib.?.lookup(*const fn (*anyopaque, isize, *anyopaque) callconv(.c) c_int, "PyTuple_SetItem") orelse return error.MissingSymbol;

    fn_PyEval_SaveThread = lib.?.lookup(*const fn () callconv(.c) ?*anyopaque, "PyEval_SaveThread") orelse return error.MissingSymbol;
    fn_PyEval_RestoreThread = lib.?.lookup(*const fn (?*anyopaque) callconv(.c) void, "PyEval_RestoreThread") orelse return error.MissingSymbol;
    fn_PyGILState_Ensure = lib.?.lookup(*const fn () callconv(.c) c_int, "PyGILState_Ensure") orelse return error.MissingSymbol;
    fn_PyGILState_Release = lib.?.lookup(*const fn (c_int) callconv(.c) void, "PyGILState_Release") orelse return error.MissingSymbol;

    fn_PyList_New = lib.?.lookup(*const fn (isize) callconv(.c) ?*anyopaque, "PyList_New") orelse return error.MissingSymbol;
    fn_PyList_SetItem = lib.?.lookup(*const fn (*anyopaque, isize, *anyopaque) callconv(.c) c_int, "PyList_SetItem") orelse return error.MissingSymbol;
    fn_PyObject_CallObject = lib.?.lookup(*const fn (*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque, "PyObject_CallObject") orelse return error.MissingSymbol;
    fn_PyObject_GetAttrString = lib.?.lookup(*const fn (*anyopaque, [*c]const u8) callconv(.c) ?*anyopaque, "PyObject_GetAttrString") orelse return error.MissingSymbol;
    fn_PyObject_Call = lib.?.lookup(*const fn (*anyopaque, *anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque, "PyObject_Call") orelse return error.MissingSymbol;
    fn_PyDict_New = lib.?.lookup(*const fn () callconv(.c) ?*anyopaque, "PyDict_New") orelse return error.MissingSymbol;
    fn_PyDict_SetItemString = lib.?.lookup(*const fn (*anyopaque, [*c]const u8, *anyopaque) callconv(.c) c_int, "PyDict_SetItemString") orelse return error.MissingSymbol;
    fn_PyUnicode_FromStringAndSize = lib.?.lookup(*const fn ([*c]const u8, isize) callconv(.c) ?*anyopaque, "PyUnicode_FromStringAndSize") orelse return error.MissingSymbol;
    fn_PyBytes_FromStringAndSize = lib.?.lookup(*const fn ([*c]const u8, isize) callconv(.c) ?*anyopaque, "PyBytes_FromStringAndSize") orelse return error.MissingSymbol;
    fn_PyLong_FromLongLong = lib.?.lookup(*const fn (i64) callconv(.c) ?*anyopaque, "PyLong_FromLongLong") orelse return error.MissingSymbol;
    fn_PyFloat_FromDouble = lib.?.lookup(*const fn (f64) callconv(.c) ?*anyopaque, "PyFloat_FromDouble") orelse return error.MissingSymbol;
    fn_PyBool_FromLong = lib.?.lookup(*const fn (c_long) callconv(.c) ?*anyopaque, "PyBool_FromLong") orelse return error.MissingSymbol;
    fn_PyObject_Length = lib.?.lookup(*const fn (*anyopaque) callconv(.c) isize, "PyObject_Length") orelse return error.MissingSymbol;
    fn_PySequence_GetItem = lib.?.lookup(*const fn (*anyopaque, isize) callconv(.c) ?*anyopaque, "PySequence_GetItem") orelse return error.MissingSymbol;
    fn_PyObject_Str = lib.?.lookup(*const fn (*anyopaque) callconv(.c) ?*anyopaque, "PyObject_Str") orelse return error.MissingSymbol;
    fn_PyUnicode_AsUTF8 = lib.?.lookup(*const fn (*anyopaque) callconv(.c) ?[*:0]const u8, "PyUnicode_AsUTF8") orelse return error.MissingSymbol;
    fn_PyObject_RichCompareBool = lib.?.lookup(*const fn (*anyopaque, *anyopaque, c_int) callconv(.c) c_int, "PyObject_RichCompareBool") orelse return error.MissingSymbol;
    fn_PyObject_GetItem = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyObject_GetItem") orelse return error.MissingSymbol;
    fn_PyUnicode_AsUTF8AndSize = lib.?.lookup(*const fn (*anyopaque, ?*isize) callconv(.c) [*c]const u8, "PyUnicode_AsUTF8AndSize") orelse return error.MissingSymbol;
    fn_PyLong_AsLongLong = lib.?.lookup(*const fn (*anyopaque) callconv(.c) i64, "PyLong_AsLongLong") orelse return error.MissingSymbol;
    fn_PyFloat_AsDouble = lib.?.lookup(*const fn (*anyopaque) callconv(.c) f64, "PyFloat_AsDouble") orelse return error.MissingSymbol;
    fn_PyBool_Type = lib.?.lookup(*anyopaque, "PyBool_Type") orelse return error.MissingSymbol;
    fn_PyObject_IsTrue = lib.?.lookup(*const fn (*anyopaque) callconv(.c) c_int, "PyObject_IsTrue") orelse return error.MissingSymbol;
    py_none = lib.?.lookup(*anyopaque, "_Py_NoneStruct");
    fn_PyNumber_FloorDivide = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_FloorDivide");
    fn_PyNumber_Remainder = lib.?.lookup(*const fn (*anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Remainder");
    fn_PyNumber_Power = lib.?.lookup(*const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.c) ?*anyopaque, "PyNumber_Power");
    fn_PyCallable_Check = lib.?.lookup(*const fn (*anyopaque) callconv(.c) c_int, "PyCallable_Check");
    fn_PyObject_SetItem = lib.?.lookup(*const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.c) c_int, "PyObject_SetItem");
    fn_PySlice_New = lib.?.lookup(*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque, "PySlice_New");
}

