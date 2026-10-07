const std = @import("std");

// ============================================================================
// High-Performance Persistent Worker Pool with Cache-Line Alignment
// ============================================================================

pub const MAX_WORKERS: usize = 32;
pub const TaskFn = *const fn (?*anyopaque) void;

// 64-byte aligned slot to eliminate false sharing between CPU cores
pub const WorkerSlot = struct {
    has_work: std.atomic.Value(u32) align(64) = std.atomic.Value(u32).init(0),
    task_fn: ?TaskFn = null,
    task_arg: ?*anyopaque = null,
};

extern "c" fn syscall(number: c_long, ...) c_long;

const SYS_futex: c_long = 202;
const FUTEX_WAIT_PRIVATE: c_long = 0 | 128;
const FUTEX_WAKE_PRIVATE: c_long = 1 | 128;

fn futexWait(val_ptr: *const std.atomic.Value(u32), expected: u32) void {
    _ = syscall(SYS_futex, @as(c_long, @intCast(@intFromPtr(val_ptr))), FUTEX_WAIT_PRIVATE, @as(c_long, @intCast(expected)), @as(c_long, 0), @as(c_long, 0), @as(c_long, 0));
}

fn futexWake(val_ptr: *const std.atomic.Value(u32)) void {
    _ = syscall(SYS_futex, @as(c_long, @intCast(@intFromPtr(val_ptr))), FUTEX_WAKE_PRIVATE, @as(c_long, 1), @as(c_long, 0), @as(c_long, 0), @as(c_long, 0));
}

pub const WorkerPool = struct {
    slots: [MAX_WORKERS]WorkerSlot = [_]WorkerSlot{.{}} ** MAX_WORKERS,
    workers: [MAX_WORKERS]?std.Thread = [_]?std.Thread{null} ** MAX_WORKERS,
    num_workers: usize = 0,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
    remaining_tasks: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    is_init: bool = false,

    fn workerLoop(self: *WorkerPool, id: usize) void {
        while (self.running.load(.acquire)) {
            while (self.slots[id].has_work.load(.acquire) == 0) {
                if (!self.running.load(.acquire)) return;
                futexWait(&self.slots[id].has_work, 0);
            }

            if (self.slots[id].task_fn) |func| {
                func(self.slots[id].task_arg);
            }

            self.slots[id].task_fn = null;
            self.slots[id].task_arg = null;
            self.slots[id].has_work.store(0, .release);
            const prev = self.remaining_tasks.fetchSub(1, .release);
            if (prev <= 1) {
                futexWake(&self.remaining_tasks);
            }
        }
    }

    pub fn init(self: *WorkerPool) !void {
        if (self.is_init) return;
        const count = std.Thread.getCpuCount() catch 4;
        self.num_workers = @min(MAX_WORKERS, @max(1, count));
        self.running.store(true, .release);
        self.remaining_tasks.store(0, .release);

        for (0..self.num_workers) |i| {
            self.slots[i].has_work = std.atomic.Value(u32).init(0);
        }

        for (0..self.num_workers) |i| {
            self.workers[i] = try std.Thread.spawn(.{}, workerLoop, .{ self, i });
        }
        self.is_init = true;
    }

    pub fn dispatchBatch(self: *WorkerPool, count: usize, funcs: []const TaskFn, args: []const ?*anyopaque) void {
        const n = @min(count, self.num_workers);
        if (n == 0) return;

        if (n == 1) {
            funcs[0](args[0]);
            return;
        }

        // Set remaining background tasks = n - 1 (main thread executes task n - 1 directly)
        const bg_tasks: u32 = @intCast(n - 1);
        self.remaining_tasks.store(bg_tasks, .release);

        for (0..bg_tasks) |i| {
            self.slots[i].task_fn = funcs[i];
            self.slots[i].task_arg = args[i];
            self.slots[i].has_work.store(1, .release);
            futexWake(&self.slots[i].has_work);
        }

        // Main thread executes the last task immediately, avoiding idle spinning
        funcs[bg_tasks](args[bg_tasks]);

        // Wait for background worker threads
        var spins: usize = 0;
        while (self.remaining_tasks.load(.acquire) > 0) {
            if (spins < 64) {
                std.atomic.spinLoopHint();
                spins += 1;
            } else {
                futexWait(&self.remaining_tasks, self.remaining_tasks.load(.acquire));
            }
        }
    }

    pub fn deinit(self: *WorkerPool) void {
        if (!self.is_init) return;
        self.running.store(false, .release);
        for (0..self.num_workers) |i| {
            self.slots[i].has_work.store(1, .release);
            futexWake(&self.slots[i].has_work);
        }
        for (0..self.num_workers) |i| {
            if (self.workers[i]) |t| {
                t.join();
            }
        }
        self.is_init = false;
    }
};

var global_pool: WorkerPool = .{};
var global_pool_initialized: bool = false;

pub fn getGlobalPool() *WorkerPool {
    if (!global_pool_initialized) {
        global_pool.init() catch {};
        global_pool_initialized = true;
    }
    return &global_pool;
}
