const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const DictEntry = struct {
    key: Dynamic,
    value: Dynamic,
};

pub const Dict = struct {
    map: *std.StringHashMap(DictEntry),
    lock_state: *std.atomic.Value(bool),
    last_attr: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) !Dict {
        const map_ptr = try allocator.create(std.StringHashMap(DictEntry));
        map_ptr.* = std.StringHashMap(DictEntry).init(allocator);
        const lock_ptr = try allocator.create(std.atomic.Value(bool));
        lock_ptr.* = std.atomic.Value(bool).init(false);
        return Dict{ .map = map_ptr, .lock_state = lock_ptr };
    }
    
    // We rely on ArenaAllocator, so deinit is essentially a no-op, but we keep it for consistency
    pub fn deinit(self: *Dict) void {
        self.map.deinit();
    }

    pub inline fn lock(self: Dict) void {
        while (self.lock_state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub inline fn unlock(self: Dict) void {
        self.lock_state.store(false, .release);
    }

    pub fn keyToBuf(key: Dynamic, buf: *[128]u8) ?[]const u8 {
        return switch (key.value) {
            .str_type => |s| {
                if (s.len + 1 <= buf.len) {
                    buf[0] = 's';
                    @memcpy(buf[1 .. 1 + s.len], s);
                    return buf[0 .. 1 + s.len];
                }
                return null;
            },
            .i64_type => |i| std.fmt.bufPrint(buf, "i{d}", .{i}) catch null,
            .i32_type => |i| std.fmt.bufPrint(buf, "i{d}", .{i}) catch null,
            .i16_type => |i| std.fmt.bufPrint(buf, "i{d}", .{i}) catch null,
            .i8_type => |i| std.fmt.bufPrint(buf, "i{d}", .{i}) catch null,
            .u64_type => |u| std.fmt.bufPrint(buf, "i{d}", .{u}) catch null,
            .u32_type => |u| std.fmt.bufPrint(buf, "i{d}", .{u}) catch null,
            .u16_type => |u| std.fmt.bufPrint(buf, "i{d}", .{u}) catch null,
            .u8_type => |u| std.fmt.bufPrint(buf, "i{d}", .{u}) catch null,
            .bool_type => |b| if (b) "i1" else "i0",
            .float_type => |f| {
                if (!std.math.isNan(f) and !std.math.isInf(f) and @floor(f) == f and f >= -9223372036854775808.0 and f <= 9223372036854775807.0) {
                    const int_val: i64 = @intFromFloat(f);
                    return std.fmt.bufPrint(buf, "i{d}", .{int_val}) catch null;
                }
                return std.fmt.bufPrint(buf, "f{d}", .{f}) catch null;
            },
            else => null,
        };
    }
    
    pub fn put(self: Dict, key: Dynamic, value: Dynamic) !void {
        self.lock();
        defer self.unlock();
        var buf: [128]u8 = undefined;
        if (keyToBuf(key, &buf)) |key_slice| {
            const key_str = try self.map.allocator.dupe(u8, key_slice);
            try self.map.put(key_str, .{ .key = key, .value = value });
        } else if (key.value == .str_type) {
            const s = key.value.str_type;
            const full_key = try self.map.allocator.alloc(u8, s.len + 1);
            full_key[0] = 's';
            @memcpy(full_key[1..], s);
            try self.map.put(full_key, .{ .key = key, .value = value });
        } else {
            return error.TypeError;
        }
    }
    
    pub fn get(self: Dict, key: Dynamic) ?Dynamic {
        self.lock();
        defer self.unlock();
        var buf: [128]u8 = undefined;
        if (keyToBuf(key, &buf)) |key_str| {
            if (self.map.get(key_str)) |entry| return entry.value;
            return null;
        } else if (key.value == .str_type) {
            const s = key.value.str_type;
            const full_key = self.map.allocator.alloc(u8, s.len + 1) catch return null;
            defer self.map.allocator.free(full_key);
            full_key[0] = 's';
            @memcpy(full_key[1..], s);
            if (self.map.get(full_key)) |entry| return entry.value;
            return null;
        }
        return null;
    }
    
    pub fn count(self: Dict) usize {
        self.lock();
        defer self.unlock();
        return self.map.count();
    }

    pub fn remove(self: Dict, key: Dynamic) bool {
        self.lock();
        defer self.unlock();
        var buf: [128]u8 = undefined;
        if (keyToBuf(key, &buf)) |key_str| {
            return self.map.remove(key_str);
        } else if (key.value == .str_type) {
            const s = key.value.str_type;
            const full_key = self.map.allocator.alloc(u8, s.len + 1) catch return false;
            defer self.map.allocator.free(full_key);
            full_key[0] = 's';
            @memcpy(full_key[1..], s);
            return self.map.remove(full_key);
        }
        return false;
    }
};
