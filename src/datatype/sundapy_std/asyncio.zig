const std = @import("std");
const Dynamic = @import("datatype/dynamic.zig").Dynamic;

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
    Wrapper.worker(state, args_copy);
    
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

extern fn usleep(usec: c_uint) c_int;

pub fn sleep(seconds: Dynamic) anyerror!Dynamic {
    if (seconds.value == .i64_type) {
        if (seconds.value.i64_type > 0) {
            _ = usleep(@intCast(@as(u64, @intCast(seconds.value.i64_type)) * 1_000_000));
        }
    } else if (seconds.value == .float_type) {
        if (seconds.value.float_type > 0.0) {
            const usec: c_uint = @intFromFloat(seconds.value.float_type * 1_000_000.0);
            _ = usleep(usec);
        }
    }
    return Dynamic.initNone();
}

pub fn _gather(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = kwargs;
    var results = std.ArrayList(Dynamic).empty;
    for (args) |a| {
        if (a.value == .list_type) {
            for (a.value.list_type.items.items) |item| {
                if (item.value == .task_type and item.value.task_type != null) {
                    const res = awaitTask(item.value.task_type.?);
                    try results.append(alloc, res);
                } else {
                    try results.append(alloc, item);
                }
            }
        } else if (a.value == .task_type and a.value.task_type != null) {
            const res = awaitTask(a.value.task_type.?);
            try results.append(alloc, res);
        } else {
            try results.append(alloc, a);
        }
    }
    return Dynamic.initList(results);
}

pub fn __sundapy_module_init() !void {
    @import("datatype/dynamic.zig").global_await_fn = awaitTask;
}


pub fn dummy_close() anyerror!Dynamic {
    return Dynamic.initNone();
}

pub fn dummy_run_until_complete(coro: Dynamic) anyerror!Dynamic {
    return run(coro);
}

pub fn dummy_loop() anyerror!Dynamic {
    var dict = Dynamic.initDict(std.heap.page_allocator);
    dict.setDynamicItem(Dynamic.initStr("run_until_complete"), @import("datatype/dynamic.zig").toDynamicFunc(dummy_run_until_complete)) catch {};
    dict.setDynamicItem(Dynamic.initStr("close"), @import("datatype/dynamic.zig").toDynamicFunc(dummy_close)) catch {};
    return dict;
}

pub fn get_event_loop() anyerror!Dynamic {
    return dummy_loop();
}

pub fn builtin_getattr(name: []const u8) Dynamic {
    if (std.mem.eql(u8, name, "sleep")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(sleep);
    }
    if (std.mem.eql(u8, name, "gather")) {
        return Dynamic{ .value = .{ .func_type_slice = _gather } };
    }
    if (std.mem.eql(u8, name, "run")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(run);
    }
    if (std.mem.eql(u8, name, "get_event_loop")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(get_event_loop);
    }
    if (std.mem.eql(u8, name, "run_until_complete")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(dummy_run_until_complete);
    }
    if (std.mem.eql(u8, name, "close")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(dummy_close);
    }
    if (std.mem.eql(u8, name, "create_subprocess_shell")) {
        return @import("datatype/dynamic.zig").toDynamicFunc(dummy_create_subprocess_shell);
    }
    if (std.mem.eql(u8, name, "subprocess")) {
        return dummy_subprocess();
    }
    return Dynamic.initNone();
}

pub fn dummy_create_subprocess_shell(cmd: @import("datatype/dynamic.zig").Dynamic) anyerror!Dynamic {
    _ = cmd;
    return Dynamic.initNone();
}

pub fn dummy_subprocess() Dynamic {
    var dict = Dynamic.initDict(std.heap.page_allocator);
    dict.setDynamicItem(Dynamic.initStr("PIPE"), Dynamic.initInt(-1)) catch {};
    return dict;
}
