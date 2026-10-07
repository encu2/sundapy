const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const types = @import("ffi_types.zig");
const dynlib = @import("ffi_dynlib.zig");
const binding = @import("ffi_binding.zig");
const raw_mem = @import("ffi_raw_mem.zig");

pub const FfiMethodData = struct {
    parent: *anyopaque,
    method_name: []const u8,
};

pub const FfiObj = union(enum) {
    dynlib: *dynlib.DynLibHandle,
    bound_fn: *binding.BoundFunction,
    struct_desc: *binding.FfiStructDesc,
    struct_inst: *binding.FfiStructInstance,
    method: FfiMethodData,

    pub fn toDynamic(self: *FfiObj) Dynamic {
        return Dynamic{ .value = .{ .ffi_obj_type = @ptrCast(self) } };
    }
};

pub fn ffiGetAttribute(ptr: *anyopaque, attr: []const u8) Dynamic {
    const obj: *FfiObj = @ptrCast(@alignCast(ptr));
    const alloc = std.heap.c_allocator;

    switch (obj.*) {
        .dynlib => |handle| {
            if (std.mem.eql(u8, attr, "get_symbol") or
                std.mem.eql(u8, attr, "call_raw") or
                std.mem.eql(u8, attr, "bind") or
                std.mem.eql(u8, attr, "close"))
            {
                const meth = alloc.create(FfiObj) catch return Dynamic.initNone();
                meth.* = .{ .method = .{ .parent = ptr, .method_name = attr } };
                return meth.toDynamic();
            }

            // Direct symbol lookup on library object: lib.symbol_name
            const sym = handle.getSymbol(attr) catch return Dynamic.initNone();
            const bf = alloc.create(binding.BoundFunction) catch return Dynamic.initNone();
            const argtypes = alloc.alloc(u8, 0) catch return Dynamic.initNone();
            bf.* = .{
                .fn_ptr = sym,
                .name = attr,
                .restype = types.TYPE_I64,
                .argtypes = argtypes,
            };
            const fn_obj = alloc.create(FfiObj) catch return Dynamic.initNone();
            fn_obj.* = .{ .bound_fn = bf };
            return fn_obj.toDynamic();
        },
        .struct_desc => |desc| {
            if (std.mem.eql(u8, attr, "sizeof")) {
                return Dynamic.initInt(@intCast(desc.total_size));
            } else if (std.mem.eql(u8, attr, "alignment")) {
                return Dynamic.initInt(@intCast(desc.alignment));
            }
            return Dynamic.initNone();
        },
        .struct_inst => |inst| {
            if (std.mem.eql(u8, attr, "_addr") or std.mem.eql(u8, attr, "_ptr")) {
                return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(inst.data))));
            } else if (std.mem.eql(u8, attr, "sizeof")) {
                return Dynamic.initInt(@intCast(inst.desc.total_size));
            }
            if (inst.getField(attr)) |val| {
                return val;
            }
            return Dynamic.initNone();
        },
        else => return Dynamic.initNone(),
    }
}

pub fn ffiCall(ptr: *anyopaque, alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = kwargs;
    const obj: *FfiObj = @ptrCast(@alignCast(ptr));

    switch (obj.*) {
        .bound_fn => |bf| {
            return bf.call(alloc, args);
        },
        .struct_desc => |desc| {
            const raw_mem_buf = try alloc.alloc(u8, desc.total_size);
            @memset(raw_mem_buf, 0);

            const inst = try alloc.create(binding.FfiStructInstance);
            inst.* = .{
                .desc = desc,
                .data = raw_mem_buf.ptr,
                .owns_memory = true,
            };

            for (args, 0..) |arg, idx| {
                if (idx < desc.fields.len) {
                    _ = inst.setField(desc.fields[idx].name, arg);
                }
            }

            const inst_obj = try alloc.create(FfiObj);
            inst_obj.* = .{ .struct_inst = inst };
            return inst_obj.toDynamic();
        },
        .method => |meth| {
            const parent_obj: *FfiObj = @ptrCast(@alignCast(meth.parent));
            switch (parent_obj.*) {
                .dynlib => |handle| {
                    if (std.mem.eql(u8, meth.method_name, "get_symbol")) {
                        if (args.len == 0) return Dynamic.initNone();
                        const sym_name = args[0].builtin_str(alloc).value.str_type;
                        const sym = try handle.getSymbol(sym_name);
                        return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(sym))));
                    } else if (std.mem.eql(u8, meth.method_name, "call_raw")) {
                        if (args.len == 0) return Dynamic.initNone();
                        const fn_ptr: *anyopaque = @ptrFromInt(@as(usize, @bitCast(args[0].asInt())));
                        return dynlib.DynLibHandle.callRaw(fn_ptr, args[1..]);
                    } else if (std.mem.eql(u8, meth.method_name, "bind")) {
                        if (args.len < 1) return Dynamic.initNone();
                        const sym_name = args[0].builtin_str(alloc).value.str_type;
                        const sym = try handle.getSymbol(sym_name);

                        const restype_id: u8 = if (args.len > 1) types.parseTypeId(args[1]) else types.TYPE_VOID;
                        var argtypes = std.ArrayList(u8).empty;
                        if (args.len > 2) {
                            const at = args[2];
                            switch (at.value) {
                                .list_type => |l| {
                                    for (l.items.items) |item| {
                                        try argtypes.append(alloc, types.parseTypeId(item));
                                    }
                                },
                                .tuple_type => |t| {
                                    for (t.items) |item| {
                                        try argtypes.append(alloc, types.parseTypeId(item));
                                    }
                                },
                                else => {
                                    try argtypes.append(alloc, types.parseTypeId(at));
                                },
                            }
                        }

                        const bf = try alloc.create(binding.BoundFunction);
                        bf.* = .{
                            .fn_ptr = sym,
                            .name = sym_name,
                            .restype = restype_id,
                            .argtypes = argtypes.items,
                        };
                        const fn_obj = try alloc.create(FfiObj);
                        fn_obj.* = .{ .bound_fn = bf };
                        return fn_obj.toDynamic();
                    } else if (std.mem.eql(u8, meth.method_name, "close")) {
                        handle.close();
                        return Dynamic.initNone();
                    }
                },
                else => return Dynamic.initNone(),
            }
            return Dynamic.initNone();
        },
        else => return Dynamic.initNone(),
    }
}

pub fn ffiSetAttribute(ptr: *anyopaque, attr: []const u8, val: Dynamic) bool {
    const obj: *FfiObj = @ptrCast(@alignCast(ptr));
    switch (obj.*) {
        .struct_inst => |inst| {
            return inst.setField(attr, val);
        },
        else => return false,
    }
}
