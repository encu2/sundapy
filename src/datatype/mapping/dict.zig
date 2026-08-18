const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const Dict = struct {
    map: *std.StringHashMap(Dynamic),

    pub fn init(allocator: std.mem.Allocator) !Dict {
        const map_ptr = try allocator.create(std.StringHashMap(Dynamic));
        map_ptr.* = std.StringHashMap(Dynamic).init(allocator);
        return Dict{ .map = map_ptr };
    }
    
    // We rely on ArenaAllocator, so deinit is essentially a no-op, but we keep it for consistency
    pub fn deinit(self: *Dict) void {
        self.map.deinit();
        // we don't destroy map_ptr since it's arena allocated (or we assume it is)
    }
    
    pub fn put(self: Dict, key: Dynamic, value: Dynamic) !void {
        if (key.value != .str_type) return error.TypeError;
        try self.map.put(key.value.str_type, value);
    }
    
    pub fn get(self: Dict, key: Dynamic) ?Dynamic {
        if (key.value != .str_type) return null;
        return self.map.get(key.value.str_type);
    }
    
    pub fn count(self: Dict) usize {
        return self.map.count();
    }
};
