const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;
const types = @import("ffi_types.zig");
const dynlib = @import("ffi_dynlib.zig");
const raw_mem = @import("ffi_raw_mem.zig");

pub const BoundFunction = struct {
    fn_ptr: *anyopaque,
    name: []const u8,
    restype: u8,
    argtypes: []const u8,

    pub fn call(self: *const BoundFunction, allocator: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
        if (args.len != self.argtypes.len) {
            return error.InvalidArgumentCount;
        }

        var has_float_arg = false;
        for (self.argtypes) |tid| {
            if (tid == types.TYPE_F32 or tid == types.TYPE_F64) {
                has_float_arg = true;
                break;
            }
        }

        if (has_float_arg) {
            return self.callWithFloats(args);
        }

        // Standard integer / pointer registers
        var uargs: [8]usize = [_]usize{0} ** 8;
        for (args, 0..) |arg, idx| {
            if (idx >= 8) break;
            const tid = self.argtypes[idx];
            switch (tid) {
                types.TYPE_I8, types.TYPE_I16, types.TYPE_I32, types.TYPE_I64,
                types.TYPE_U8, types.TYPE_U16, types.TYPE_U32, types.TYPE_U64 => {
                    uargs[idx] = @as(usize, @bitCast(arg.asInt()));
                },
                types.TYPE_BOOL => {
                    uargs[idx] = if (arg.toBool()) 1 else 0;
                },
                types.TYPE_C_STR => {
                    switch (arg.value) {
                        .str_type => |s| {
                            const c_str = try raw_mem.makeCString(allocator, s);
                            uargs[idx] = @intFromPtr(c_str);
                        },
                        .i64_type => |p| {
                            uargs[idx] = @as(usize, @bitCast(p));
                        },
                        else => uargs[idx] = 0,
                    }
                },
                types.TYPE_PTR => {
                    uargs[idx] = @as(usize, @bitCast(arg.asInt()));
                },
                else => {
                    uargs[idx] = @as(usize, @bitCast(arg.asInt()));
                },
            }
        }

        return self.dispatchIntRegisters(args.len, &uargs);
    }

    fn dispatchIntRegisters(self: *const BoundFunction, argc: usize, uargs: *const [8]usize) anyerror!Dynamic {
        if (self.restype == types.TYPE_VOID) {
            switch (argc) {
                0 => { const f: *const fn () callconv(.c) void = @ptrCast(self.fn_ptr); f(); },
                1 => { const f: *const fn (usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0]); },
                2 => { const f: *const fn (usize, usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0], uargs[1]); },
                3 => { const f: *const fn (usize, usize, usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0], uargs[1], uargs[2]); },
                4 => { const f: *const fn (usize, usize, usize, usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0], uargs[1], uargs[2], uargs[3]); },
                5 => { const f: *const fn (usize, usize, usize, usize, usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0], uargs[1], uargs[2], uargs[3], uargs[4]); },
                6 => { const f: *const fn (usize, usize, usize, usize, usize, usize) callconv(.c) void = @ptrCast(self.fn_ptr); f(uargs[0], uargs[1], uargs[2], uargs[3], uargs[4], uargs[5]); },
                else => return error.TooManyArguments,
            }
            return Dynamic.initNone();
        }

        if (self.restype == types.TYPE_F64 or self.restype == types.TYPE_F32) {
            const ret: f64 = switch (argc) {
                0 => @as(*const fn () callconv(.c) f64, @ptrCast(self.fn_ptr))(),
                1 => @as(*const fn (usize) callconv(.c) f64, @ptrCast(self.fn_ptr))(uargs[0]),
                2 => @as(*const fn (usize, usize) callconv(.c) f64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1]),
                3 => @as(*const fn (usize, usize, usize) callconv(.c) f64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2]),
                4 => @as(*const fn (usize, usize, usize, usize) callconv(.c) f64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2], uargs[3]),
                else => return error.TooManyArguments,
            };
            return Dynamic.initFloat(ret);
        }

        const raw_ret: i64 = switch (argc) {
            0 => @as(*const fn () callconv(.c) i64, @ptrCast(self.fn_ptr))(),
            1 => @as(*const fn (usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0]),
            2 => @as(*const fn (usize, usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1]),
            3 => @as(*const fn (usize, usize, usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2]),
            4 => @as(*const fn (usize, usize, usize, usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2], uargs[3]),
            5 => @as(*const fn (usize, usize, usize, usize, usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2], uargs[3], uargs[4]),
            6 => @as(*const fn (usize, usize, usize, usize, usize, usize) callconv(.c) i64, @ptrCast(self.fn_ptr))(uargs[0], uargs[1], uargs[2], uargs[3], uargs[4], uargs[5]),
            else => return error.TooManyArguments,
        };

        return switch (self.restype) {
            types.TYPE_BOOL => Dynamic.initBool(raw_ret != 0),
            types.TYPE_C_STR => blk: {
                if (raw_ret == 0) break :blk Dynamic.initNone();
                const p: [*:0]const u8 = @ptrFromInt(@as(usize, @bitCast(raw_ret)));
                break :blk Dynamic.initStr(std.mem.span(p));
            },
            else => Dynamic.initInt(raw_ret),
        };
    }

    fn callWithFloats(self: *const BoundFunction, args: []const Dynamic) anyerror!Dynamic {
        if (args.len == 1) {
            const f0 = args[0].asFloat();
            if (self.restype == types.TYPE_F64 or self.restype == types.TYPE_F32) {
                const f: *const fn (f64) callconv(.c) f64 = @ptrCast(self.fn_ptr);
                return Dynamic.initFloat(f(f0));
            } else if (self.restype == types.TYPE_VOID) {
                const f: *const fn (f64) callconv(.c) void = @ptrCast(self.fn_ptr);
                f(f0);
                return Dynamic.initNone();
            } else {
                const f: *const fn (f64) callconv(.c) i64 = @ptrCast(self.fn_ptr);
                return Dynamic.initInt(f(f0));
            }
        } else if (args.len == 2) {
            const f0 = args[0].asFloat();
            const f1 = args[1].asFloat();
            if (self.restype == types.TYPE_F64 or self.restype == types.TYPE_F32) {
                const f: *const fn (f64, f64) callconv(.c) f64 = @ptrCast(self.fn_ptr);
                return Dynamic.initFloat(f(f0, f1));
            } else if (self.restype == types.TYPE_VOID) {
                const f: *const fn (f64, f64) callconv(.c) void = @ptrCast(self.fn_ptr);
                f(f0, f1);
                return Dynamic.initNone();
            } else {
                const f: *const fn (f64, f64) callconv(.c) i64 = @ptrCast(self.fn_ptr);
                return Dynamic.initInt(f(f0, f1));
            }
        }
        return error.UnsupportedFloatSignature;
    }
};

pub const FfiStructField = struct {
    name: []const u8,
    type_id: u8,
    offset: usize,
};

pub const FfiStructDesc = struct {
    name: []const u8,
    fields: []FfiStructField,
    total_size: usize,
    alignment: usize,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, field_defs: []const struct { []const u8, u8 }) !*FfiStructDesc {
        var fields = try allocator.alloc(FfiStructField, field_defs.len);
        var current_offset: usize = 0;
        var max_align: usize = 1;

        for (field_defs, 0..) |fd, i| {
            const align_size = types.typeAlign(fd[1]);
            if (align_size > max_align) max_align = align_size;
            if (current_offset % align_size != 0) {
                current_offset += (align_size - (current_offset % align_size));
            }
            fields[i] = .{
                .name = fd[0],
                .type_id = fd[1],
                .offset = current_offset,
            };
            current_offset += types.typeSize(fd[1]);
        }

        if (current_offset % max_align != 0) {
            current_offset += (max_align - (current_offset % max_align));
        }

        const desc = try allocator.create(FfiStructDesc);
        desc.* = .{
            .name = name,
            .fields = fields,
            .total_size = current_offset,
            .alignment = max_align,
        };
        return desc;
    }
};

pub const FfiStructInstance = struct {
    desc: *const FfiStructDesc,
    data: [*]u8,
    owns_memory: bool,

    pub fn getField(self: *const FfiStructInstance, name: []const u8) ?Dynamic {
        for (self.desc.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                return raw_mem.readMemory(@ptrCast(self.data + f.offset), f.type_id);
            }
        }
        return null;
    }

    pub fn setField(self: *FfiStructInstance, name: []const u8, val: Dynamic) bool {
        for (self.desc.fields) |f| {
            if (std.mem.eql(u8, f.name, name)) {
                raw_mem.writeMemory(@ptrCast(self.data + f.offset), f.type_id, val);
                return true;
            }
        }
        return false;
    }
};
