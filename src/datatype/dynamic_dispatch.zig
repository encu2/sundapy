const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const DynType = dynamic.DynType;

extern fn fopen(filename: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
extern fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: *anyopaque) usize;
extern fn fwrite(ptr: [*]const u8, size: usize, nmemb: usize, stream: *anyopaque) usize;
extern fn fclose(stream: *anyopaque) c_int;
extern fn fseek(stream: *anyopaque, offset: c_long, whence: c_int) c_int;

pub fn builtin_getattr(self: Dynamic, attr_name: []const u8) Dynamic {
    return self.getAbiAttribute(attr_name);
}

pub fn getAbiAttribute(self: Dynamic, attr: []const u8) Dynamic {
    if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            const PikaPython = @import("python_abi.zig").PikaPython;
            return PikaPython.getAttribute(obj, attr) catch Dynamic{ .value = .{ .none_type = {} } };
        }
    } else if (self.value == .task_type and self.value.task_type != null) {
        const resolved = self.awaitResult();
        if (resolved.value != .task_type) {
            return resolved.getAbiAttribute(attr);
        }
    } else if (self.value == .list_type or self.value == .range_type) {
        if (std.mem.eql(u8, attr, "__iter__") or std.mem.eql(u8, attr, "__aiter__")) {
            return self;
        }
    } else if (self.value == .dict_type) {
        if (self.value.dict_type.get(Dynamic.initStr(attr))) |val| {
            return val;
        }
        var d = self;
        d.value.dict_type.last_attr = attr;
        if (std.mem.eql(u8, attr, "values") or 
            std.mem.eql(u8, attr, "update") or 
            std.mem.eql(u8, attr, "items") or 
            std.mem.eql(u8, attr, "keys") or 
            std.mem.eql(u8, attr, "get") or 
            std.mem.eql(u8, attr, "pop") or 
            std.mem.eql(u8, attr, "read") or 
            std.mem.eql(u8, attr, "write") or 
            std.mem.eql(u8, attr, "close") or 
            std.mem.eql(u8, attr, "__aenter__") or 
            std.mem.eql(u8, attr, "__aexit__") or 
            std.mem.eql(u8, attr, "__enter__") or 
            std.mem.eql(u8, attr, "__exit__")) {
            return d;
        }

        return Dynamic.initNone();
    } else if (self.value == .gpu_buffer_type) {
        return @import("gpu_types.zig").bufferGetAttribute(self.value.gpu_buffer_type, attr);
    }
    return Dynamic{ .value = .{ .none_type = {} } };
}

pub fn builtin_call(self: Dynamic, alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    if (self.value == .py_obj_type) {
        if (self.value.py_obj_type) |obj| {
            const PikaPython = @import("python_abi.zig").PikaPython;
            return PikaPython.callObject(obj, alloc, args, kwargs);
        }
    } else if (self.value == .task_type and self.value.task_type != null) {
        const resolved = self.awaitResult();
        if (resolved.value != .task_type) {
            return resolved.builtin_call(alloc, args, kwargs);
        }
    } else if (self.value == .list_type or self.value == .range_type) {
        return self;
    } else if (self.value == .dict_type) {
        const attr = self.value.dict_type.last_attr;
        if (std.mem.eql(u8, attr, "values")) {
            self.value.dict_type.lock();
            defer self.value.dict_type.unlock();
            var list = std.ArrayList(Dynamic).empty;
            var it = self.value.dict_type.map.valueIterator();
            while (it.next()) |v| {
                try list.append(alloc, v.*);
            }
            return Dynamic.initList(list);
        } else if (std.mem.eql(u8, attr, "keys")) {
            self.value.dict_type.lock();
            defer self.value.dict_type.unlock();
            var list = std.ArrayList(Dynamic).empty;
            var it = self.value.dict_type.map.keyIterator();
            while (it.next()) |k| {
                try list.append(alloc, Dynamic.initStr(k.*));
            }
            return Dynamic.initList(list);
        } else if (std.mem.eql(u8, attr, "items")) {
            self.value.dict_type.lock();
            defer self.value.dict_type.unlock();
            var list = std.ArrayList(Dynamic).empty;
            var it = self.value.dict_type.map.iterator();
            while (it.next()) |entry| {
                const pair = [_]Dynamic{ Dynamic.initStr(entry.key_ptr.*), entry.value_ptr.* };
                const tuple = try @import("sequence/list.zig").Tuple.init(alloc, &pair);
                try list.append(alloc, Dynamic{ .value = .{ .tuple_type = tuple } });
            }
            return Dynamic.initList(list);

        } else if (std.mem.eql(u8, attr, "get")) {
            if (args.len > 0) {
                if (self.value.dict_type.get(args[0])) |val| {
                    return val;
                }
            }
            if (args.len > 1) {
                return args[1];
            }
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, attr, "pop")) {
            if (args.len > 0) {
                const k = args[0];
                if (self.value.dict_type.get(k)) |val| {
                    _ = self.value.dict_type.remove(k);
                    return val;
                }
            }
            if (args.len > 1) {
                return args[1];
            }
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, attr, "update")) {

            if (args.len > 0) {
                const arg = args[0];
                if (arg.value == .list_type) {
                    for (arg.value.list_type.items.items) |item| {
                        if (item.value == .list_type and item.value.list_type.items.items.len >= 2) {
                            try self.value.dict_type.put(item.value.list_type.items.items[0], item.value.list_type.items.items[1]);
                        } else if (item.value == .tuple_type and item.value.tuple_type.items.len >= 2) {
                            try self.value.dict_type.put(item.value.tuple_type.items[0], item.value.tuple_type.items[1]);
                        }
                    }
                } else if (arg.value == .dict_type) {
                    arg.value.dict_type.lock();
                    defer arg.value.dict_type.unlock();
                    var it = arg.value.dict_type.map.iterator();
                    while (it.next()) |entry| {
                        try self.value.dict_type.put(Dynamic.initStr(entry.key_ptr.*), entry.value_ptr.*);
                    }
                }
            }
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, attr, "__aenter__") or std.mem.eql(u8, attr, "__enter__")) {
            return self;
        } else if (std.mem.eql(u8, attr, "__aexit__") or std.mem.eql(u8, attr, "__exit__")) {
            return Dynamic.initNone();
        } else if (std.mem.eql(u8, attr, "read")) {
            if (self.value.dict_type.get(Dynamic.initStr("path"))) |path_dyn| {
                if (path_dyn.value == .str_type) {
                    const path = path_dyn.value.str_type;
                    var path_buf: [1024]u8 = undefined;
                    if (path.len >= 1023) return Dynamic.initStr("");
                    @memcpy(path_buf[0..path.len], path);
                    path_buf[path.len] = 0;
                    const f_handle = fopen(@ptrCast(&path_buf), "rb") orelse return Dynamic.initStr("");
                    defer _ = fclose(f_handle);
                    var current_offset: usize = 0;
                    if (self.value.dict_type.get(Dynamic.initStr("offset"))) |off_dyn| {
                        if (off_dyn.value == .i64_type) {
                            current_offset = @intCast(@max(0, off_dyn.value.i64_type));
                        }
                    }
                    _ = fseek(f_handle, @intCast(current_offset), 0);
                    var read_limit: usize = 5120000;
                    if (args.len > 0 and args[0].value == .i64_type) {
                        read_limit = @intCast(@max(0, args[0].value.i64_type));
                    }
                    const buf = try alloc.alloc(u8, read_limit);
                    const mode_dyn = self.value.dict_type.get(Dynamic.initStr("mode"));
                    const is_binary = if (mode_dyn) |m| (m.value == .str_type and std.mem.indexOfScalar(u8, m.value.str_type, 'b') != null) else false;
                    const bytes_read = fread(buf.ptr, 1, read_limit, f_handle);
                    if (bytes_read == 0) return if (is_binary) Dynamic{ .value = .{ .bytes_type = "" } } else Dynamic.initStr("");
                    try self.value.dict_type.put(Dynamic.initStr("offset"), Dynamic.initInt(@intCast(current_offset + bytes_read)));
                    return if (is_binary) Dynamic{ .value = .{ .bytes_type = buf[0..bytes_read] } } else Dynamic.initStr(buf[0..bytes_read]);
                }
            }
            return Dynamic.initStr("");
        } else if (std.mem.eql(u8, attr, "write")) {
            if (self.value.dict_type.get(Dynamic.initStr("path"))) |path_dyn| {
                if (path_dyn.value == .str_type) {
                    const path = path_dyn.value.str_type;
                    var path_buf: [1024]u8 = undefined;
                    if (path.len >= 1023) return Dynamic.initInt(0);
                    @memcpy(path_buf[0..path.len], path);
                    path_buf[path.len] = 0;
                    const mode_dyn = self.value.dict_type.get(Dynamic.initStr("mode"));
                    const is_append = if (mode_dyn) |m| (m.value == .str_type and std.mem.indexOfScalar(u8, m.value.str_type, 'a') != null) else false;
                    const mode_str: [*:0]const u8 = if (is_append) "ab" else "wb";
                    const f_handle = fopen(@ptrCast(&path_buf), mode_str) orelse return Dynamic.initInt(0);
                    defer _ = fclose(f_handle);
                    if (args.len > 0) {
                        const data_slice: ?[]const u8 = switch (args[0].value) {
                            .str_type => |s| s,
                            .bytes_type => |b| b,
                            else => null,
                        };
                        if (data_slice) |ds| {
                            const written = fwrite(ds.ptr, 1, ds.len, f_handle);
                            return Dynamic.initInt(@intCast(written));
                        }
                    }
                }
            }
            return Dynamic.initInt(0);
        } else if (std.mem.eql(u8, attr, "close")) {
            return Dynamic.initNone();
        }
        return Dynamic.initNone();
    } else if (self.value == .func_type_0) {
        return self.value.func_type_0();
    } else if (self.value == .func_type_1) {
        var a0 = if (args.len > 0) args[0] else Dynamic.initNone();
        if (a0.value == .none_type and kwargs != null and kwargs.?.value == .dict_type) {
            var it = kwargs.?.value.dict_type.map.valueIterator();
            if (it.next()) |v| { a0 = v.*; }
        }
        return self.value.func_type_1(a0);
    } else if (self.value == .func_type_2) {
        var a0 = if (args.len > 0) args[0] else Dynamic.initNone();
        var a1 = if (args.len > 1) args[1] else Dynamic.initNone();
        if (kwargs != null and kwargs.?.value == .dict_type) {
            var it = kwargs.?.value.dict_type.map.valueIterator();
            if (a0.value == .none_type) { if (it.next()) |v| { a0 = v.*; } }
            if (a1.value == .none_type) { if (it.next()) |v| { a1 = v.*; } }
        }
        return self.value.func_type_2(a0, a1);
    } else if (self.value == .func_type_3) {
        var a0 = if (args.len > 0) args[0] else Dynamic.initNone();
        var a1 = if (args.len > 1) args[1] else Dynamic.initNone();
        var a2 = if (args.len > 2) args[2] else Dynamic.initNone();
        if (kwargs != null and kwargs.?.value == .dict_type) {
            const kw = kwargs.?.value.dict_type;
            if (kw.get(Dynamic.initStr("index"))) |v| { a0 = v; }
            if (kw.get(Dynamic.initStr("start"))) |v| {
                if (a0.value == .none_type and kw.get(Dynamic.initStr("index")) == null) a0 = v else a1 = v;
            }
            if (kw.get(Dynamic.initStr("distance"))) |v| { a2 = v; }
            if (kw.get(Dynamic.initStr("stop"))) |v| { a1 = v; }
            if (kw.get(Dynamic.initStr("step"))) |v| { a2 = v; }
            var it = kw.map.valueIterator();
            if (a0.value == .none_type) { if (it.next()) |v| { a0 = v.*; } }
            if (a1.value == .none_type) { if (it.next()) |v| { a1 = v.*; } }
            if (a2.value == .none_type) { if (it.next()) |v| { a2 = v.*; } }
        }
        return self.value.func_type_3(a0, a1, a2);
    } else if (self.value == .func_type_4) {
        var a0 = if (args.len > 0) args[0] else Dynamic.initNone();
        var a1 = if (args.len > 1) args[1] else Dynamic.initNone();
        var a2 = if (args.len > 2) args[2] else Dynamic.initNone();
        var a3 = if (args.len > 3) args[3] else Dynamic.initNone();
        if (kwargs != null and kwargs.?.value == .dict_type) {
            var it = kwargs.?.value.dict_type.map.valueIterator();
            if (a0.value == .none_type) { if (it.next()) |v| { a0 = v.*; } }
            if (a1.value == .none_type) { if (it.next()) |v| { a1 = v.*; } }
            if (a2.value == .none_type) { if (it.next()) |v| { a2 = v.*; } }
            if (a3.value == .none_type) { if (it.next()) |v| { a3 = v.*; } }
        }
        return self.value.func_type_4(a0, a1, a2, a3);
    } else if (self.value == .func_type_slice) {
        return self.value.func_type_slice(alloc, args, kwargs);
    } else if (self.value == .gpu_kernel_type) {
        const bound: *const @import("gpu_types.zig").BoundKernel = @ptrCast(@alignCast(self.value.gpu_kernel_type));
        var mut_bound = bound.*;
        return mut_bound.call(alloc, args);
    } else if (self.value == .py_obj_type) {
        return try @import("python_abi.zig").PikaPython.callObject(self.value.py_obj_type.?, alloc, args, kwargs);
    } else if (self.value == .str_type) {
        const s = self.value.str_type;
        if (std.mem.eql(u8, s, "int")) {
            if (args.len == 0) return Dynamic.initInt(0);
            return args[0].builtin_int();
        } else if (std.mem.eql(u8, s, "str")) {
            if (args.len == 0) return Dynamic.initStr("");
            return args[0].builtin_str(alloc);
        } else if (std.mem.eql(u8, s, "float")) {
            if (args.len == 0) return Dynamic.initFloat(0.0);
            return args[0].builtin_float();
        } else if (std.mem.eql(u8, s, "list")) {
            return @import("dynamic/builtins.zig").builtin_list(alloc, if (args.len > 0) args[0] else Dynamic.initNone());
        } else if (std.mem.eql(u8, s, "dict")) {
            return @import("dynamic/builtins.zig").builtin_dict(alloc, if (args.len > 0) args[0] else Dynamic.initNone());
        } else if (std.mem.eql(u8, s, "bool")) {
            if (args.len == 0) return Dynamic.initBool(false);
            return args[0].builtin_bool();
        }
    }
    return error.TypeErrorNotCallable;
}
