const std = @import("std");
const Dynamic = @import("dynamic.zig").Dynamic;
const types = @import("ffi_types.zig");

extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;

pub fn rawAlloc(bytes: usize) ?*anyopaque {
    return malloc(bytes);
}

pub fn rawFree(ptr: ?*anyopaque) void {
    if (ptr) |p| free(p);
}

pub fn rawMemcpy(dst: *anyopaque, src: *anyopaque, size: usize) void {
    const d: [*]u8 = @ptrCast(dst);
    const s: [*]const u8 = @ptrCast(src);
    @memcpy(d[0..size], s[0..size]);
}

pub fn makeCString(allocator: std.mem.Allocator, s: []const u8) ![*:0]const u8 {
    const buf = try allocator.allocSentinel(u8, s.len, 0);
    @memcpy(buf[0..s.len], s);
    return buf.ptr;
}

pub fn readMemory(ptr: *anyopaque, type_id: u8) Dynamic {
    switch (type_id) {
        types.TYPE_I8 => {
            const p: *i8 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_I16 => {
            const p: *i16 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_I32 => {
            const p: *i32 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_I64 => {
            const p: *i64 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(p.*);
        },
        types.TYPE_U8 => {
            const p: *u8 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_U16 => {
            const p: *u16 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_U32 => {
            const p: *u32 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, p.*));
        },
        types.TYPE_U64 => {
            const p: *u64 = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, @bitCast(p.*)));
        },
        types.TYPE_F32 => {
            const p: *f32 = @ptrCast(@alignCast(ptr));
            return Dynamic.initFloat(@as(f64, p.*));
        },
        types.TYPE_F64 => {
            const p: *f64 = @ptrCast(@alignCast(ptr));
            return Dynamic.initFloat(p.*);
        },
        types.TYPE_BOOL => {
            const p: *bool = @ptrCast(@alignCast(ptr));
            return Dynamic.initBool(p.*);
        },
        types.TYPE_C_STR => {
            const p: *[*:0]const u8 = @ptrCast(@alignCast(ptr));
            return Dynamic.initStr(std.mem.span(p.*));
        },
        types.TYPE_PTR => {
            const p: **anyopaque = @ptrCast(@alignCast(ptr));
            return Dynamic.initInt(@as(i64, @bitCast(@intFromPtr(p.*))));
        },
        else => return Dynamic.initNone(),
    }
}

pub fn writeMemory(ptr: *anyopaque, type_id: u8, val: Dynamic) void {
    switch (type_id) {
        types.TYPE_I8 => {
            const p: *i8 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_I16 => {
            const p: *i16 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_I32 => {
            const p: *i32 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_I64 => {
            const p: *i64 = @ptrCast(@alignCast(ptr));
            p.* = val.asInt();
        },
        types.TYPE_U8 => {
            const p: *u8 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_U16 => {
            const p: *u16 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_U32 => {
            const p: *u32 = @ptrCast(@alignCast(ptr));
            p.* = @intCast(val.asInt());
        },
        types.TYPE_U64 => {
            const p: *u64 = @ptrCast(@alignCast(ptr));
            p.* = @bitCast(val.asInt());
        },
        types.TYPE_F32 => {
            const p: *f32 = @ptrCast(@alignCast(ptr));
            p.* = @floatCast(val.asFloat());
        },
        types.TYPE_F64 => {
            const p: *f64 = @ptrCast(@alignCast(ptr));
            p.* = val.asFloat();
        },
        types.TYPE_BOOL => {
            const p: *bool = @ptrCast(@alignCast(ptr));
            p.* = val.toBool();
        },
        types.TYPE_PTR => {
            const p: **anyopaque = @ptrCast(@alignCast(ptr));
            p.* = @ptrFromInt(@as(usize, @intCast(val.asInt())));
        },
        else => {},
    }
}
