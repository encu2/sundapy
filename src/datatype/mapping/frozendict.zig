const std = @import("std");
const Dynamic = @import("../dynamic.zig").Dynamic;

pub const FrozenEntry = struct {
    hash: u64,
    key: []const u8,
    val: Dynamic,
};

pub const FrozenDict = struct {
    entries: []const FrozenEntry,
    cached_hash: u64,

    pub fn init(allocator: std.mem.Allocator, keys: []const []const u8, values: []const Dynamic) !FrozenDict {
        const n_items = @min(keys.len, values.len);
        var entries = try allocator.alloc(FrozenEntry, n_items);
        var h: u64 = 0x811c9dc5; // FNV/Wyhash accumulator

        for (0..n_items) |i| {
            const key_hash = std.hash.Wyhash.hash(0, keys[i]);
            entries[i] = .{
                .hash = key_hash,
                .key = keys[i],
                .val = values[i],
            };
            h ^= key_hash;
            h = h *% 0x1000193;
        }

        return FrozenDict{
            .entries = entries,
            .cached_hash = h,
        };
    }

    pub fn get(self: FrozenDict, key: []const u8) ?Dynamic {
        const target_hash = std.hash.Wyhash.hash(0, key);
        for (self.entries) |entry| {
            if (entry.hash == target_hash and std.mem.eql(u8, entry.key, key)) {
                return entry.val;
            }
        }
        return null;
    }

    pub fn contains(self: FrozenDict, key: []const u8) bool {
        return self.get(key) != null;
    }

    pub fn count(self: FrozenDict) usize {
        return self.entries.len;
    }

    pub fn hash(self: FrozenDict) u64 {
        return self.cached_hash;
    }

    pub fn eql(self: FrozenDict, other: FrozenDict) bool {
        if (self.cached_hash != other.cached_hash) return false;
        if (self.entries.len != other.entries.len) return false;
        for (self.entries) |entry| {
            if (other.get(entry.key)) |oval| {
                if (!entry.val.eq(oval).toBool()) return false;
            } else {
                return false;
            }
        }
        return true;
    }
};
