const std = @import("std");

pub var global_missing_modules: std.ArrayList([]const u8) = .empty;
pub var global_failed_modules: std.StringHashMapUnmanaged(bool) = .empty;
pub var global_missing_initialized: bool = false;
pub var global_missing_mutex: std.Io.Mutex = .init;

pub fn addMissingModule(allocator: std.mem.Allocator, io: std.Io, mod: []const u8) !void {
    try global_missing_mutex.lock(io);
    defer global_missing_mutex.unlock(io);
    
    if (!global_missing_initialized) return;
    
    if (global_failed_modules.contains(mod)) return;
    for (global_missing_modules.items) |item| {
        if (std.mem.eql(u8, item, mod)) return;
    }
    const dup = try allocator.dupe(u8, mod);
    try global_missing_modules.append(allocator, dup);
}

pub fn findSoFile(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8, mod_slash: []const u8) !?[]const u8 {
    const dir_path = if (std.fs.path.dirname(mod_slash)) |d|
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_dir, d })
    else
        try std.fmt.allocPrint(allocator, "{s}", .{base_dir});
    defer allocator.free(dir_path);

    const basename = if (std.fs.path.basename(mod_slash).len > 0)
        std.fs.path.basename(mod_slash)
    else
        mod_slash;

    const cwd_dir = std.Io.Dir.cwd();
    var dir = cwd_dir.openDir(io, dir_path, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    var iter = dir.iterate();
    while (true) {
        const entry_opt = iter.next(io) catch break;
        if (entry_opt == null) break;
        const entry = entry_opt.?;
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, basename) and (std.mem.endsWith(u8, entry.name, ".so") or std.mem.endsWith(u8, entry.name, ".pyd"))) {
            const result = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            return result;
        }
    }
    return null;
}

pub fn packageContainsSo(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8, mod_slash: []const u8) bool {
    const cwd = std.Io.Dir.cwd();

    // 1. Direct file check: base_dir/mod_slash.so or .pyd
    const direct_so = std.fmt.allocPrint(allocator, "{s}/{s}.so", .{ base_dir, mod_slash }) catch return false;
    defer allocator.free(direct_so);
    if (cwd.access(io, direct_so, .{})) |_| return true else |_| {}

    const direct_pyd = std.fmt.allocPrint(allocator, "{s}/{s}.pyd", .{ base_dir, mod_slash }) catch return false;
    defer allocator.free(direct_pyd);
    if (cwd.access(io, direct_pyd, .{})) |_| return true else |_| {}

    // 2. Package directory recursive scan: base_dir/mod_slash
    const dir_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_dir, mod_slash }) catch return false;
    defer allocator.free(dir_path);

    var dir = cwd.openDir(io, dir_path, .{ .iterate = true }) catch return false;
    defer dir.close(io);

    return scanDirForSo(allocator, io, dir);
}

fn scanDirForSo(allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir) bool {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var stack: std.ArrayList([]const u8) = .empty;

    // 1. Scan root_dir directly
    {
        var iter = root_dir.iterate();
        while (true) {
            const entry_opt = iter.next(io) catch break;
            if (entry_opt == null) break;
            const entry = entry_opt.?;
            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".so") or std.mem.endsWith(u8, entry.name, ".pyd")) {
                    return true;
                }
            } else if (entry.kind == .directory) {
                if (!std.mem.eql(u8, entry.name, "__pycache__") and !std.mem.startsWith(u8, entry.name, ".")) {
                    const sub_path = arena_alloc.dupe(u8, entry.name) catch continue;
                    stack.append(arena_alloc, sub_path) catch continue;
                }
            }
        }
    }

    // 2. Process all subdirectories purely iteratively (zero recursion)
    while (stack.items.len > 0) {
        const rel_path = stack.pop().?;

        var dir = root_dir.openDir(io, rel_path, .{ .iterate = true }) catch continue;
        defer dir.close(io);

        var iter = dir.iterate();
        while (true) {
            const entry_opt = iter.next(io) catch break;
            if (entry_opt == null) break;
            const entry = entry_opt.?;

            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".so") or std.mem.endsWith(u8, entry.name, ".pyd")) {
                    return true;
                }
            } else if (entry.kind == .directory) {
                if (!std.mem.eql(u8, entry.name, "__pycache__") and !std.mem.startsWith(u8, entry.name, ".")) {
                    const sub_path = std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ rel_path, entry.name }) catch continue;
                    stack.append(arena_alloc, sub_path) catch continue;
                }
            }
        }
    }
    return false;
}


pub var global_uses_c_abi: bool = false;
pub var is_no_panic: bool = false;
pub var global_uses_dynamic: bool = false;
pub const SharedVisited = struct {
    map: std.StringHashMap(bool),
    mutex: std.Io.Mutex = .init,
    
    pub fn init(allocator: std.mem.Allocator) SharedVisited {
        return .{ .map = std.StringHashMap(bool).init(allocator) };
    }
    
    pub fn deinit(self: *SharedVisited) void {
        self.map.deinit();
    }
    
    pub fn containsAndPut(self: *SharedVisited, io: std.Io, path: []const u8) !bool {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        if (self.map.contains(path)) return true;
        try self.map.put(path, true);
        return false;
    }
};

pub fn getSystemPythonVersion(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8) !?[]const u8 {
    _ = io;
    _ = base_dir;
    return @as(?[]const u8, try allocator.dupe(u8, "python3.14"));
}





fn transpileFileWorker(allocator_unused: std.mem.Allocator, io: std.Io, file_path: []const u8, visited: *SharedVisited, threads: *std.ArrayList(std.Thread), is_root: bool, mod_name: ?[]const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    _ = allocator_unused;
    const allocator = arena.allocator();
    
    // We must pass the original allocator for visited and threads, but we can't because it's not thread-safe.
    // Let's just use page_allocator for shared state operations!
    
    transpileFile(allocator, io, file_path, visited, threads, is_root, mod_name) catch |err| {
        std.debug.print("Transpilation worker failed for {s}: {any}\n", .{file_path, err});
    };
}
pub const transpileFile = @import("transpile_file.zig").transpileFile;
