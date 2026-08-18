const std = @import("std");

pub const CacheManager = struct {
    allocator: std.mem.Allocator,
    cache_dir: []const u8 = ".cache",

    pub fn init(allocator: std.mem.Allocator) CacheManager {
        return .{ .allocator = allocator };
    }

    /// Creates the .cache/ directory structure if it doesn't exist
    pub fn ensureCacheDirs(self: CacheManager, allocator: std.mem.Allocator, io: std.Io) !void {
        _ = self;
        _ = try std.process.run(allocator, io, .{
            .argv = &[_][]const u8{"mkdir", "-p", ".cache/src", ".cache/bin", ".cache/ast", ".cache/pyLibrary"},
        });
    }

    /// Computes a simple hash of the given file content (SHA256 could be used in production)
    pub fn computeHash(self: CacheManager, content: []const u8) u64 {
        _ = self;
        return std.hash.Wyhash.hash(0, content);
    }

    /// Checks if the hash matches the one stored in .cache/hashes.txt
    pub fn isCacheValid(self: CacheManager, io: std.Io, file_path: []const u8, current_hash: u64) !bool {
        const cwd = std.Io.Dir.cwd();
        
        const content = cwd.readFileAlloc(io, ".cache/hashes.txt", self.allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
            if (err == error.FileNotFound) return false;
            return err;
        };
        defer self.allocator.free(content);

        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            var it = std.mem.splitScalar(u8, line, '=');
            const path = it.next() orelse continue;
            const hash_str = it.next() orelse continue;
            
            if (std.mem.eql(u8, path, file_path)) {
                const stored_hash = std.fmt.parseInt(u64, hash_str, 10) catch continue;
                return stored_hash == current_hash;
            }
        }
        return false;
    }

    /// Updates the hash for a specific file in .cache/hashes.txt
    pub fn updateCacheHash(self: CacheManager, io: std.Io, file_path: []const u8, new_hash: u64) !void {
        const cwd = std.Io.Dir.cwd();
        
        var map = std.StringHashMap(u64).init(self.allocator);
        defer map.deinit();

        if (cwd.readFileAlloc(io, ".cache/hashes.txt", self.allocator, @enumFromInt(10 * 1024 * 1024))) |content| {
            defer self.allocator.free(content);
            var iter = std.mem.splitScalar(u8, content, '\n');
            while (iter.next()) |line| {
                if (line.len == 0) continue;
                var it = std.mem.splitScalar(u8, line, '=');
                const path = it.next() orelse continue;
                const hash_str = it.next() orelse continue;
                const stored_hash = std.fmt.parseInt(u64, hash_str, 10) catch continue;
                
                const path_dup = try self.allocator.dupe(u8, path);
                try map.put(path_dup, stored_hash);
            }
        } else |err| {
            if (err != error.FileNotFound) return err;
        }

        // Add or update the current file's hash
        const file_path_dup = try self.allocator.dupe(u8, file_path);
        try map.put(file_path_dup, new_hash);

        // Build the string to write
        var out_str: []u8 = &[_]u8{};
        var map_it = map.iterator();
        while (map_it.next()) |entry| {
            const line = try std.fmt.allocPrint(self.allocator, "{s}={d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            const old_str = out_str;
            out_str = try std.mem.concat(self.allocator, u8, &[_][]const u8{ old_str, line });
            if (old_str.len > 0) self.allocator.free(old_str);
            self.allocator.free(line);
            self.allocator.free(entry.key_ptr.*); // Free the duplicated keys
        }

        try cwd.writeFile(io, .{ .sub_path = ".cache/hashes.txt", .data = out_str });
        if (out_str.len > 0) self.allocator.free(out_str);
    }
};
