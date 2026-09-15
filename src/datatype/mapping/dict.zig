const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const Dict = struct {
    map: *std.StringHashMap(Dynamic),
    lock_state: *std.atomic.Value(bool),
    last_attr: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) !Dict {
        const map_ptr = try allocator.create(std.StringHashMap(Dynamic));
        map_ptr.* = std.StringHashMap(Dynamic).init(allocator);
        const lock_ptr = try allocator.create(std.atomic.Value(bool));
        lock_ptr.* = std.atomic.Value(bool).init(false);
        return Dict{ .map = map_ptr, .lock_state = lock_ptr };
    }
    
    // We rely on ArenaAllocator, so deinit is essentially a no-op, but we keep it for consistency
    pub fn deinit(self: *Dict) void {
        self.map.deinit();
    }

    pub fn lock(self: Dict) void {
        while (self.lock_state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: Dict) void {
        self.lock_state.store(false, .release);
    }
    
    pub fn put(self: Dict, key: Dynamic, value: Dynamic) !void {
        self.lock();
        defer self.unlock();
        const key_str = switch (key.value) {
            .str_type => |s| try self.map.allocator.dupe(u8, s),
            .i64_type => |i| try std.fmt.allocPrint(self.map.allocator, "{d}", .{i}),
            .bool_type => |b| try self.map.allocator.dupe(u8, if (b) "True" else "False"),
            else => return error.TypeError,
        };
        try self.map.put(key_str, value);
    }
    
    pub fn get(self: Dict, key: Dynamic) ?Dynamic {
        self.lock();
        defer self.unlock();
        var buf: [32]u8 = undefined;
        const key_str = switch (key.value) {
            .str_type => |s| s,
            .i64_type => |i| std.fmt.bufPrint(&buf, "{d}", .{i}) catch return null,
            .bool_type => |b| if (b) "True" else "False",
            else => return null,
        };
        return self.map.get(key_str);
    }
    
    pub fn count(self: Dict) usize {
        self.lock();
        defer self.unlock();
        return self.map.count();
    }

    pub fn remove(self: Dict, key: Dynamic) bool {
        self.lock();
        defer self.unlock();
        var buf: [32]u8 = undefined;
        const key_str = switch (key.value) {
            .str_type => |s| s,
            .i64_type => |i| std.fmt.bufPrint(&buf, "{d}", .{i}) catch return false,
            .bool_type => |b| if (b) "True" else "False",
            else => return false,
        };
        return self.map.remove(key_str);
    }
};

