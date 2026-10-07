const std = @import("std");
const Dynamic = @import("datatype/dynamic.zig").Dynamic;
const types = @import("datatype/ffi_types.zig");
const dynlib = @import("datatype/ffi_dynlib.zig");
const binding = @import("datatype/ffi_binding.zig");
const raw_mem = @import("datatype/ffi_raw_mem.zig");
const ffi_disp = @import("datatype/ffi_dispatch.zig");

pub const @"void": i64 = types.TYPE_VOID;
pub const @"i8": i64 = types.TYPE_I8;
pub const @"i16": i64 = types.TYPE_I16;
pub const @"i32": i64 = types.TYPE_I32;
pub const @"i64": i64 = types.TYPE_I64;
pub const @"u8": i64 = types.TYPE_U8;
pub const @"u16": i64 = types.TYPE_U16;
pub const @"u32": i64 = types.TYPE_U32;
pub const @"u64": i64 = types.TYPE_U64;
pub const @"f32": i64 = types.TYPE_F32;
pub const @"f64": i64 = types.TYPE_F64;
pub const @"bool": i64 = types.TYPE_BOOL;
pub const c_str_type: i64 = types.TYPE_C_STR;
pub const ptr: i64 = types.TYPE_PTR;
pub const @"struct": i64 = types.TYPE_STRUCT;

pub const RTLD_LOCAL: i64 = dynlib.RTLD_LOCAL;
pub const RTLD_LAZY: i64 = dynlib.RTLD_LAZY;
pub const RTLD_NOW: i64 = dynlib.RTLD_NOW;
pub const RTLD_GLOBAL: i64 = dynlib.RTLD_GLOBAL;

pub fn open(path: Dynamic) anyerror!Dynamic {
    const s = path.builtin_str(std.heap.c_allocator).value.str_type;
    const handle = try dynlib.open(std.heap.c_allocator, s, 0);
    const lib_obj = try std.heap.c_allocator.create(ffi_disp.FfiObj);
    lib_obj.* = .{ .dynlib = handle };
    return lib_obj.toDynamic();
}
pub fn load(path: Dynamic) anyerror!Dynamic {
    return open(path);
}

pub fn alloc(size: Dynamic) anyerror!Dynamic {
    const sz: usize = @intCast(size.asInt());
    const mem = raw_mem.rawAlloc(sz);
    if (mem == null) return Dynamic.initInt(0);
    return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(mem.?))));
}

pub fn free(ptr_val: Dynamic) anyerror!Dynamic {
    const p: usize = @as(usize, @bitCast(ptr_val.asInt()));
    if (p != 0) {
        raw_mem.rawFree(@ptrFromInt(p));
    }
    return Dynamic.initNone();
}

pub fn memcpy(dst: Dynamic, src: Dynamic, size: Dynamic) anyerror!Dynamic {
    raw_mem.rawMemcpy(@ptrFromInt(@as(usize, @bitCast(dst.asInt()))), @ptrFromInt(@as(usize, @bitCast(src.asInt()))), @intCast(size.asInt()));
    return Dynamic.initNone();
}

pub fn c_str(val: Dynamic) anyerror!Dynamic {
    const s = val.builtin_str(std.heap.c_allocator).value.str_type;
    const p = try raw_mem.makeCString(std.heap.c_allocator, s);
    return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(p))));
}

pub fn cast(addr_val: Dynamic, type_val: Dynamic) anyerror!Dynamic {
    const addr: usize = @as(usize, @bitCast(addr_val.asInt()));
    const tid = types.parseTypeId(type_val);
    return raw_mem.readMemory(@ptrFromInt(addr), tid);
}

pub fn sizeof(val: Dynamic) anyerror!Dynamic {
    if (val.value == .ffi_obj_type) {
        const obj: *ffi_disp.FfiObj = @ptrCast(@alignCast(val.value.ffi_obj_type));
        switch (obj.*) {
            .struct_desc => |desc| return Dynamic.initInt(@intCast(desc.total_size)),
            .struct_inst => |inst| return Dynamic.initInt(@intCast(inst.desc.total_size)),
            else => {},
        }
    }
    const tid = types.parseTypeId(val);
    return Dynamic.initInt(@intCast(types.typeSize(tid)));
}

pub fn addressof(val: Dynamic) anyerror!Dynamic {
    if (val.value == .ffi_obj_type) {
        const obj: *ffi_disp.FfiObj = @ptrCast(@alignCast(val.value.ffi_obj_type));
        switch (obj.*) {
            .struct_inst => |inst| return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(inst.data)))),
            else => {},
        }
    }
    return Dynamic.initInt(0);
}

pub fn create_struct_slice(al: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = kwargs;
    if (args.len < 2) return error.MissingArgument;
    const name = try al.dupe(u8, args[0].builtin_str(al).value.str_type);

    var field_defs = std.ArrayList(struct { []const u8, u8 }).empty;
    defer field_defs.deinit(al);

    const f_list = args[1];
    switch (f_list.value) {
        .list_type => |l| {
            for (l.items.items) |item| {
                if (item.value == .tuple_type and item.value.tuple_type.items.len >= 2) {
                    const fname = try al.dupe(u8, item.value.tuple_type.items[0].builtin_str(al).value.str_type);
                    const ftid = types.parseTypeId(item.value.tuple_type.items[1]);
                    try field_defs.append(al, .{ fname, ftid });
                } else if (item.value == .list_type and item.value.list_type.items.items.len >= 2) {
                    const fname = try al.dupe(u8, item.value.list_type.items.items[0].builtin_str(al).value.str_type);
                    const ftid = types.parseTypeId(item.value.list_type.items.items[1]);
                    try field_defs.append(al, .{ fname, ftid });
                }
            }
        },
        else => {},
    }

    const desc = try binding.FfiStructDesc.init(al, name, field_defs.items);
    const desc_obj = try al.create(ffi_disp.FfiObj);
    desc_obj.* = .{ .struct_desc = desc };
    return desc_obj.toDynamic();
}

pub const Struct = struct {
    pub fn __init__(self: *Struct) anyerror!Dynamic {
        _ = self;
        return Dynamic.initNone();
    }
};

pub fn builtin_getattr(attr: []const u8) Dynamic {
    if (std.mem.eql(u8, attr, "open") or std.mem.eql(u8, attr, "load")) return Dynamic{ .value = .{ .func_type_1 = open } };
    if (std.mem.eql(u8, attr, "alloc")) return Dynamic{ .value = .{ .func_type_1 = alloc } };
    if (std.mem.eql(u8, attr, "free")) return Dynamic{ .value = .{ .func_type_1 = free } };
    if (std.mem.eql(u8, attr, "memcpy")) return Dynamic{ .value = .{ .func_type_3 = memcpy } };
    if (std.mem.eql(u8, attr, "c_str")) return Dynamic{ .value = .{ .func_type_1 = c_str } };
    if (std.mem.eql(u8, attr, "cast")) return Dynamic{ .value = .{ .func_type_2 = cast } };
    if (std.mem.eql(u8, attr, "sizeof")) return Dynamic{ .value = .{ .func_type_1 = sizeof } };
    if (std.mem.eql(u8, attr, "addressof")) return Dynamic{ .value = .{ .func_type_1 = addressof } };
    if (std.mem.eql(u8, attr, "create_struct")) return Dynamic{ .value = .{ .func_type_slice = create_struct_slice } };

    if (std.mem.eql(u8, attr, "void")) return Dynamic.initInt(@"void");
    if (std.mem.eql(u8, attr, "i8")) return Dynamic.initInt(@"i8");
    if (std.mem.eql(u8, attr, "i16")) return Dynamic.initInt(@"i16");
    if (std.mem.eql(u8, attr, "i32")) return Dynamic.initInt(@"i32");
    if (std.mem.eql(u8, attr, "i64")) return Dynamic.initInt(@"i64");
    if (std.mem.eql(u8, attr, "u8")) return Dynamic.initInt(@"u8");
    if (std.mem.eql(u8, attr, "u16")) return Dynamic.initInt(@"u16");
    if (std.mem.eql(u8, attr, "u32")) return Dynamic.initInt(@"u32");
    if (std.mem.eql(u8, attr, "u64")) return Dynamic.initInt(@"u64");
    if (std.mem.eql(u8, attr, "f32")) return Dynamic.initInt(@"f32");
    if (std.mem.eql(u8, attr, "f64")) return Dynamic.initInt(@"f64");
    if (std.mem.eql(u8, attr, "bool")) return Dynamic.initInt(@"bool");
    if (std.mem.eql(u8, attr, "c_str_type")) return Dynamic.initInt(c_str_type);
    if (std.mem.eql(u8, attr, "ptr")) return Dynamic.initInt(ptr);
    if (std.mem.eql(u8, attr, "struct")) return Dynamic.initInt(@"struct");

    if (std.mem.eql(u8, attr, "RTLD_LOCAL")) return Dynamic.initInt(RTLD_LOCAL);
    if (std.mem.eql(u8, attr, "RTLD_LAZY")) return Dynamic.initInt(RTLD_LAZY);
    if (std.mem.eql(u8, attr, "RTLD_NOW")) return Dynamic.initInt(RTLD_NOW);
    if (std.mem.eql(u8, attr, "RTLD_GLOBAL")) return Dynamic.initInt(RTLD_GLOBAL);

    return Dynamic.initNone();
}

pub fn __sundapy_module_init() !void {}
