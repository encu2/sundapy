const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

var frames_store: [120]Dynamic = undefined;

pub fn set_frame(index: anytype, frame: anytype) anyerror!Dynamic {
    const idx_dyn = Dynamic.fromAny(index);
    const i = @as(usize, @intCast(idx_dyn.value.i64_type));
    frames_store[i] = Dynamic.fromAny(frame);
    return Dynamic.initNone();
}

pub fn get_frame(index: anytype) anyerror!Dynamic {
    const idx_dyn = Dynamic.fromAny(index);
    const i = @as(usize, @intCast(idx_dyn.value.i64_type));
    return frames_store[i];
}

pub fn start_new_thread(func: anytype, args: anytype) anyerror!Dynamic {
    _ = try std.Thread.spawn(.{}, struct {
        fn worker(f: @TypeOf(func), a: @TypeOf(args)) !void {
            const T = @TypeOf(f);
            if (T == Dynamic) {
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();
                const alloc = arena.allocator();
                if (a.value == .list_type) {
                    _ = try f.builtin_call(alloc, a.value.list_type.items.items, null);
                } else {
                    var args_arr = [_]Dynamic{};
                    _ = try f.builtin_call(alloc, &args_arr, null);
                }
            } else {
                if (@typeInfo(@TypeOf(a)) == .@"struct" and @typeInfo(@TypeOf(a)).@"struct".is_tuple) {
                    _ = @call(.auto, f, a) catch {};
                }
            }
        }
    }.worker, .{ func, args });
    return Dynamic.initNone();
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {
    for (0..120) |i| {
        frames_store[i] = Dynamic.initNone();
    }
}
