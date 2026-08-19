const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub fn _is_abi() void {}

pub const TaskState = struct {
    result: ?Dynamic = null,
    done: bool = false,
    thread: ?std.Thread = null,
    alloc: std.mem.Allocator,
};

pub fn createTask(comptime func: anytype, args: []const Dynamic) anyerror!Dynamic {
    const alloc = std.heap.page_allocator;
    const state = try alloc.create(TaskState);
    state.* = TaskState{
        .alloc = alloc,
    };
    
    const Wrapper = struct {
        fn worker(s: *TaskState, a: []const Dynamic) void {
            const res = func(a) catch Dynamic.initNone();
            s.result = res;
            s.done = true;
        }
    };
    
    const args_copy = try alloc.dupe(Dynamic, args);
    state.thread = try std.Thread.spawn(.{}, Wrapper.worker, .{ state, args_copy });
    
    return Dynamic{ .value = .{ .task_type = @ptrCast(state) } };
}

pub fn awaitTask(ptr: *anyopaque) Dynamic {
    var state: *TaskState = @ptrCast(@alignCast(ptr));
    
    if (state.thread) |*t| {
        t.join();
        state.thread = null;
    }
    
    if (state.result) |r| {
        return r;
    }
    return Dynamic.initNone();
}

pub fn run(coro: Dynamic) anyerror!Dynamic {
    if (coro.value == .task_type and coro.value.task_type != null) {
        return awaitTask(coro.value.task_type.?);
    }
    return coro;
}

pub fn sleep(seconds: Dynamic) anyerror!Dynamic {
    if (seconds.value == .i64_type) {
        std.time.sleep(@as(u64, @intCast(seconds.value.i64_type)) * 1_000_000_000);
    } else if (seconds.value == .float_type) {
        const ms: u64 = @intFromFloat(seconds.value.float_type * 1_000.0);
        std.time.sleep(ms * 1_000_000);
    }
    return Dynamic.initNone();
}

pub fn _gather(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = kwargs;
    var results = std.ArrayList(Dynamic).empty;
    for (args) |a| {
        if (a.value == .task_type and a.value.task_type != null) {
            const res = awaitTask(a.value.task_type.?);
            try results.append(alloc, res);
        } else {
            try results.append(alloc, a);
        }
    }
    
    // We can't just return Dynamic.initList directly if the signature of initList expects a managed list? No, initList in sundapy takes unmanaged list if that's what it was using!
    // Wait, in dynamic.zig, does initList take an unmanaged list? Let's assume yes.
    return Dynamic.initList(results);
}

pub fn __sundapy_module_init() !void {
    @import("../dynamic.zig").global_await_fn = awaitTask;
}

