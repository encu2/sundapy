const std = @import("std");
const Dynamic = @import("datatype/dynamic.zig").Dynamic;

pub const Thread = struct {
    target: Dynamic = undefined,
    args: Dynamic = undefined,
    thread: ?std.Thread = null,
    
    pub fn __init__(self: *Thread, target: Dynamic, args: Dynamic) anyerror!Dynamic {
        self.target = target;
        self.args = args;
        return Dynamic.initNone();
    }
    
    pub fn start(self: *Thread) anyerror!Dynamic {
        self.thread = try std.Thread.spawn(.{}, struct {
            fn worker(t: Dynamic, a: Dynamic) !void {
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();
                const alloc = arena.allocator();
                
                if (a.value == .list_type and a.value.list_type.items.items.len > 0) {
                    var args_arr = [_]Dynamic{a.value.list_type.items.items[0]};
                    _ = try t.builtin_call(alloc, &args_arr, null);
                } else {
                    var args_arr = [_]Dynamic{};
                    _ = try t.builtin_call(alloc, &args_arr, null);
                }
            }
        }.worker, .{ self.target, self.args });
        return Dynamic.initNone();
    }
    
    pub fn join(self: *Thread) anyerror!Dynamic {
        if (self.thread) |*t| {
            t.join();
            self.thread = null;
        }
        return Dynamic.initNone();
    }
};

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
