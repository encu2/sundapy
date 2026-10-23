const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const sym = @import("python_abi/symbols.zig");
pub const conv = @import("python_abi/conv.zig");

pub const sundapyBridge = struct {
    pub const PythonAbi = sundapyBridge;
    pub const PikaPython = sundapyBridge;
    pub fn init() !void {
        if (sym.lib == null) {
            try sym.loadSymbols();

            sym.fn_Py_Initialize();
            _ = sym.fn_PyRun_SimpleString(
                \\import builtins
                \\import sys
                \\import os
                \\import threading
                \\import asyncio
                \\import inspect
                \\
                \\if not hasattr(sys, "argv") or len(sys.argv) == 0 or sys.argv == [""]:
                \\    try:
                \\        with open("/proc/self/cmdline", "rb") as _f:
                \\            _raw = _f.read()
                \\            if _raw.endswith(b"\x00"):
                \\                _raw = _raw[:-1]
                \\            _raw_cmd = _raw.split(b"\x00")
                \\            sys.argv = [a.decode("utf-8", "surrogateescape") for a in _raw_cmd]
                \\    except Exception:
                \\        pass
                \\    if not hasattr(sys, "argv") or len(sys.argv) == 0:
                \\        sys.argv = [""]
                \\
                \\_seen_pylib = set()
                \\def _add_pylib(p):
                \\    if p and p not in _seen_pylib and os.path.isdir(p):
                \\        _seen_pylib.add(p)
                \\        if p not in sys.path:
                \\            sys.path.insert(0, p)
                \\
                \\if "SUNDAPY_PYLIB" in os.environ:
                \\    _add_pylib(os.environ["SUNDAPY_PYLIB"])
                \\
                \\try:
                \\    _exe = os.path.realpath("/proc/self/exe")
                \\    _d = os.path.dirname(_exe)
                \\    for _ in range(8):
                \\        _add_pylib(os.path.join(_d, ".cache", "pyLibrary"))
                \\        _add_pylib(os.path.join(_d, "pyLibrary"))
                \\        _parent = os.path.dirname(_d)
                \\        if _parent == _d:
                \\            break
                \\        _d = _parent
                \\except Exception:
                \\    pass
                \\
                \\try:
                \\    _cwd = os.getcwd()
                \\    _d = _cwd
                \\    for _ in range(8):
                \\        _add_pylib(os.path.join(_d, ".cache", "pyLibrary"))
                \\        _add_pylib(os.path.join(_d, "pyLibrary"))
                \\        _parent = os.path.dirname(_d)
                \\        if _parent == _d:
                \\            break
                \\        _d = _parent
                \\except Exception:
                \\    pass
                \\
                \\user_site = os.path.expanduser("~/.local/lib/python3.14/site-packages")
                \\if os.path.exists(user_site) and user_site not in sys.path:
                \\    sys.path.append(user_site)
                \\
                \\try:
                \\    import httpx
                \\    _orig_AsyncClient = httpx.AsyncClient
                \\    def _patched_AsyncClient(*args, **kwargs):
                \\        if "follow_redirects" not in kwargs:
                \\            kwargs["follow_redirects"] = True
                \\        if "timeout" not in kwargs:
                \\            kwargs["timeout"] = None
                \\        return _orig_AsyncClient(*args, **kwargs)
                \\    httpx.AsyncClient = _patched_AsyncClient
                \\    _orig_Client = getattr(httpx, "Client", None)
                \\    if _orig_Client:
                \\        def _patched_Client(*args, **kwargs):
                \\            if "follow_redirects" not in kwargs:
                \\                kwargs["follow_redirects"] = True
                \\            if "timeout" not in kwargs:
                \\                kwargs["timeout"] = None
                \\            return _orig_Client(*args, **kwargs)
                \\        httpx.Client = _patched_Client
                \\except Exception:
                \\    pass
                \\
                \\_tls = threading.local()
                \\def _sundapy_eval_coro(obj):
                \\    if asyncio.iscoroutine(obj) or (hasattr(obj, "__class__") and obj.__class__.__name__ == "coroutine"):
                \\        loop = getattr(_tls, "loop", None)
                \\        if loop is None or loop.is_closed():
                \\            loop = asyncio.new_event_loop()
                \\            asyncio.set_event_loop(loop)
                \\            _tls.loop = loop
                \\        return loop.run_until_complete(obj)
                \\    elif inspect.isasyncgen(obj):
                \\        loop = getattr(_tls, "loop", None)
                \\        if loop is None or loop.is_closed():
                \\            loop = asyncio.new_event_loop()
                \\            asyncio.set_event_loop(loop)
                \\            _tls.loop = loop
                \\        async def _drain(gen):
                \\            items = []
                \\            try:
                \\                async for item in gen:
                \\                    items.append(item)
                \\            except Exception as e:
                \\                import sys
                \\                print(f"[sundapy_drain_warning]: {e}", file=sys.stderr)
                \\            return items
                \\        return loop.run_until_complete(_drain(obj))
                \\    return obj
                \\builtins._sundapy_eval_coro = _sundapy_eval_coro
                \\
            );
            sym._main_thread_state = sym.fn_PyEval_SaveThread();
        }
    }

    pub fn deinit() void {
        if (sym.lib != null) {
            if (sym._main_thread_state != null) {
                sym.fn_PyEval_RestoreThread(sym._main_thread_state);
                sym._main_thread_state = null;
            }
            _ = sym.fn_Py_FinalizeEx();
        }
    }

    pub fn importModule(name: [*c]const u8) !Dynamic {
        const _gstate = sym.fn_PyGILState_Ensure();
        defer sym.fn_PyGILState_Release(_gstate);
        const py_name = sym.fn_PyUnicode_DecodeFSDefault(name);
        defer sym.fn_Py_DecRef(py_name);

        const module = sym.fn_PyImport_Import(py_name);
        if (module == null) {
            sym.fn_PyErr_Print();
            return error.ImportError;
        }

        return Dynamic{ .value = .{ .py_obj_type = module } };
    }

    pub fn getAttribute(obj: *anyopaque, attr: []const u8) !Dynamic {
        const _gstate = sym.fn_PyGILState_Ensure();
        defer sym.fn_PyGILState_Release(_gstate);
        if (sym.lib == null) return error.PythonNotLoaded;

        var attr_c: [256]u8 = undefined;
        if (attr.len >= 256) return error.AttributeTooLong;
        @memcpy(attr_c[0..attr.len], attr);
        attr_c[attr.len] = 0;

        const method_obj = sym.fn_PyObject_GetAttrString(obj, @ptrCast(&attr_c));
        if (method_obj == null) {
            sym.fn_PyErr_Clear();
            // If obj is a module/package, attr might be a submodule (e.g. PIL.Image)
            const mod_name_obj = sym.fn_PyObject_GetAttrString(obj, "__name__");
            if (mod_name_obj) |m_obj| {
                defer sym.fn_Py_DecRef(m_obj);
                var size: isize = 0;
                const mod_name_ptr = sym.fn_PyUnicode_AsUTF8AndSize(m_obj, &size);
                if (mod_name_ptr != null and size > 0) {
                    const mod_name = mod_name_ptr[0..@intCast(size)];
                    var full_name_buf: [512]u8 = undefined;
                    if (mod_name.len + 1 + attr.len < 512) {
                        @memcpy(full_name_buf[0..mod_name.len], mod_name);
                        full_name_buf[mod_name.len] = '.';
                        @memcpy(full_name_buf[mod_name.len + 1 .. mod_name.len + 1 + attr.len], attr);
                        full_name_buf[mod_name.len + 1 + attr.len] = 0;
                        const sub_py_name = sym.fn_PyUnicode_DecodeFSDefault(@ptrCast(&full_name_buf));
                        defer sym.fn_Py_DecRef(sub_py_name);
                        const sub_mod = sym.fn_PyImport_Import(sub_py_name);
                        if (sub_mod) |sm| {
                            return Dynamic{ .value = .{ .py_obj_type = evalCoro(sm) } };
                        } else {
                            sym.fn_PyErr_Clear();
                        }
                    }
                }
            } else {
                sym.fn_PyErr_Clear();
            }
            return error.AttributeNotFound;
        }

        return Dynamic{ .value = .{ .py_obj_type = evalCoro(method_obj.?) } };
    }

    pub fn setAttribute(obj: *anyopaque, attr: []const u8, val: Dynamic) !void {
        const _gstate = sym.fn_PyGILState_Ensure();
        defer sym.fn_PyGILState_Release(_gstate);
        if (sym.lib == null) return error.PythonNotLoaded;

        if (sym.fn_PyObject_SetAttrString) |pySetAttr| {
            var attr_c: [256]u8 = undefined;
            if (attr.len >= 256) return error.AttributeTooLong;
            @memcpy(attr_c[0..attr.len], attr);
            attr_c[attr.len] = 0;

            const py_val = try conv.dynamicToPyObject(val);
            defer sym.fn_Py_DecRef(py_val);
            if (pySetAttr(obj, @ptrCast(&attr_c), py_val) < 0) {
                sym.fn_PyErr_Clear();
                return error.PythonError;
            }
        }
    }

    pub fn evalCoro(obj: *anyopaque) *anyopaque {
        const builtins_name = sym.fn_PyUnicode_FromStringAndSize("builtins", 8);
        const builtins_mod = sym.fn_PyImport_Import(builtins_name.?);
        sym.fn_Py_DecRef(builtins_name.?);
        if (builtins_mod == null) return obj;

        const eval_fn = sym.fn_PyObject_GetAttrString(builtins_mod.?, "_sundapy_eval_coro");
        sym.fn_Py_DecRef(builtins_mod.?);
        if (eval_fn == null) return obj;

        const args_tuple = sym.fn_PyTuple_New(1);
        if (args_tuple == null) {
            sym.fn_Py_DecRef(eval_fn.?);
            return obj;
        }

        sym.fn_Py_IncRef(obj);
        _ = sym.fn_PyTuple_SetItem(args_tuple.?, 0, obj);

        const res = sym.fn_PyObject_CallObject(eval_fn.?, args_tuple.?);
        sym.fn_Py_DecRef(eval_fn.?);
        sym.fn_Py_DecRef(args_tuple.?);

        if (res == null) {
            sym.fn_PyErr_Print();
            if (sym.fn_PyList_New(0)) |empty_list| {
                return empty_list;
            }
            return obj;
        }

        return res.?;
    }

    pub fn callObject(func: *anyopaque, alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) !Dynamic {
        const _gstate = sym.fn_PyGILState_Ensure();
        defer sym.fn_PyGILState_Release(_gstate);
        const args_tuple: ?*anyopaque = sym.fn_PyTuple_New(@intCast(args.len));
        if (args_tuple == null) return error.PythonError;

        for (args, 0..) |arg, i| {
            const py_arg = conv.dynamicToPyObject(arg) orelse (if (sym.py_none) |n| blk: {
                sym.fn_Py_IncRef(n);
                break :blk n;
            } else continue);
            _ = sym.fn_PyTuple_SetItem(args_tuple.?, @intCast(i), py_arg);
        }

        var kwargs_dict: ?*anyopaque = null;
        if (kwargs) |kw| {
            if (kw.value == .dict_type) {
                kwargs_dict = sym.fn_PyDict_New();
                var it = kw.value.dict_type.map.iterator();
                while (it.next()) |entry| {
                    const key_dyn = entry.value_ptr.key;
                    const k_str = if (key_dyn.value == .str_type) key_dyn.value.str_type else key_dyn.builtin_str(alloc).value.str_type;
                    const v_obj = conv.dynamicToPyObject(entry.value_ptr.value);
                    if (v_obj) |v| {
                        var c_str = alloc.alloc(u8, k_str.len + 1) catch continue;
                        defer alloc.free(c_str);
                        @memcpy(c_str[0..k_str.len], k_str);
                        c_str[k_str.len] = 0;
                        _ = sym.fn_PyDict_SetItemString(kwargs_dict.?, c_str.ptr, v);
                        sym.fn_Py_DecRef(v);
                    }
                }

            }
        }

        var res: ?*anyopaque = null;
        if (kwargs_dict != null) {
            res = sym.fn_PyObject_Call(func, args_tuple.?, kwargs_dict);
        } else {
            res = sym.fn_PyObject_CallObject(func, args_tuple.?);
        }

        if (args_tuple) |t| {
            sym.fn_Py_DecRef(t);
        }
        if (kwargs_dict) |d| {
            sym.fn_Py_DecRef(d);
        }
        if (res == null) {
            sym.fn_PyErr_Print();
            return error.PythonError;
        }
        return Dynamic{ .value = .{ .py_obj_type = evalCoro(res.?) } };
    }

    pub const dynamicToPyObject = conv.dynamicToPyObject;
    pub const getLength = conv.getLength;
    pub const getItem = conv.getItem;
    pub const compare = conv.compare;
    pub const isTrue = conv.isTrue;
    pub const getString = conv.getString;
    pub const getDynamicItem = conv.getDynamicItem;
    pub const setDynamicItem = conv.setDynamicItem;
    pub const delDynamicItem = conv.delDynamicItem;
    pub const getDynamicSlice = conv.getDynamicSlice;
    pub const doMath = conv.doMath;
    pub const doMathReverse = conv.doMathReverse;
};

