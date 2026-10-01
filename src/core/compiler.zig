const std = @import("std");

pub var global_missing_modules: std.ArrayList([]const u8) = .empty;
pub var global_missing_initialized: bool = false;
pub var global_missing_mutex: std.Io.Mutex = .init;

pub fn addMissingModule(allocator: std.mem.Allocator, io: std.Io, mod: []const u8) !void {
    try global_missing_mutex.lock(io);
    defer global_missing_mutex.unlock(io);
    
    if (!global_missing_initialized) return;
    
    for (global_missing_modules.items) |item| {
        if (std.mem.eql(u8, item, mod)) return;
    }
    const dup = try allocator.dupe(u8, mod);
    try global_missing_modules.append(allocator, dup);
}

fn findSoFile(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8, mod_slash: []const u8) !?[]const u8 {
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

fn getSystemPythonVersion(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8) !?[]const u8 {
    var dir = std.Io.Dir.openDirAbsolute(io, base_dir, .{}) catch return null;
    defer dir.close(io);
    var it = dir.iterate();
    var highest_minor: u32 = 0;
    var best_ver: ?[]const u8 = null;
    
    while (true) {
        const entry_opt = it.next(io) catch break;
        if (entry_opt == null) break;
        const entry = entry_opt.?;
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.name, "python3.")) {
            const minor_str = entry.name[8..];
            const minor = std.fmt.parseInt(u32, minor_str, 10) catch continue;
            if (minor >= highest_minor) {
                highest_minor = minor;
                if (best_ver) |v| allocator.free(v);
                best_ver = try allocator.dupe(u8, entry.name);
            }
        }
    }
    return best_ver;
}


pub fn transpileFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, visited: *SharedVisited, threads: *std.ArrayList(std.Thread), is_root: bool, mod_name: ?[]const u8) !void {
    if (try visited.containsAndPut(io, file_path)) return;

    const cwd = std.Io.Dir.cwd();
    const script_content = cwd.readFileAlloc(io, file_path, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Could not read imported file: {s} (error: {any})\n", .{file_path, err});
        return;
    };
    defer allocator.free(script_content);
    
    var lexer = @import("../lexer/lexer.zig").Lexer.init(allocator, script_content);
    defer lexer.deinit();

    var parser = @import("../parser/parser.zig").Parser.init(allocator, &lexer);
    var program = parser.parseProgram() catch |err| {
        std.debug.print("Syntax error during parsing {s}: {}\n", .{file_path, err});
        std.process.exit(1);
    };
    defer program.deinit(allocator);

    var transpiler = @import("../transpiler/transpiler.zig").Transpiler.init(allocator, is_root, if (mod_name) |m| m else "");
    defer transpiler.deinit();

    const zig_code = transpiler.transpile(program) catch |err| {
        std.debug.print("Error during transpilation of {s}: {}\n", .{file_path, err});
        std.process.exit(1);
    };

    var stem = if (std.mem.lastIndexOfScalar(u8, std.fs.path.basename(file_path), '.')) |idx| std.fs.path.basename(file_path)[0..idx] else std.fs.path.basename(file_path);
    if (mod_name) |m| {
        stem = m;
    }
    
    const stem_slash = try allocator.dupe(u8, stem);
    defer allocator.free(stem_slash);
    for (stem_slash) |*c| {
        if (c.* == '.') c.* = '/';
    }

    const zig_src_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{stem_slash});
    defer allocator.free(zig_src_path);
    
    if (std.fs.path.dirname(zig_src_path)) |dir| {
        cwd.createDirPath(io, dir) catch {};
    }

    try cwd.writeFile(io, .{ .sub_path = zig_src_path, .data = zig_code });
    
    const dir_path = std.fs.path.dirname(file_path) orelse ".";
    for (transpiler.imported_modules.items) |mod| {
        const mod_slash = try allocator.dupe(u8, mod);
        defer allocator.free(mod_slash);
        for (mod_slash) |*c| {
            if (c.* == '.') c.* = '/';
        }

        const stdlib_path = try std.fmt.allocPrint(allocator, "src/datatype/sundapy_std/{s}.zig", .{mod});
        defer allocator.free(stdlib_path);
        if (cwd.access(io, stdlib_path, .{})) |_| {
            const dest_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{mod_slash});
            defer allocator.free(dest_path);
            
            if (std.fs.path.dirname(dest_path)) |dir| {
                cwd.createDirPath(io, dir) catch {};
            }
            
            const stdlib_code = cwd.readFileAlloc(io, stdlib_path, allocator, @enumFromInt(10 * 1024 * 1024)) catch continue;
            defer allocator.free(stdlib_code);
            cwd.writeFile(io, .{ .sub_path = dest_path, .data = stdlib_code }) catch {};
            
            if (std.mem.eql(u8, mod, "requests")) {
                const socket_code = cwd.readFileAlloc(io, "src/datatype/sundapy_std/socket.zig", allocator, @enumFromInt(10 * 1024 * 1024)) catch continue;
                defer allocator.free(socket_code);
                cwd.writeFile(io, .{ .sub_path = ".cache/src/socket.zig", .data = socket_code }) catch {};
            }
        } else |_| {
            const mod_file = try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{dir_path, mod_slash});
            defer allocator.free(mod_file);
            
            if (cwd.access(io, mod_file, .{})) |_| {
                const t = try std.Thread.spawn(.{}, transpileFileWorker, .{allocator, io, mod_file, visited, threads, false, mod});
                try threads.append(allocator, t);
            } else |_| {
                const init_file = try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{dir_path, mod_slash});
                defer allocator.free(init_file);
                if (cwd.access(io, init_file, .{})) {
                    const t = try std.Thread.spawn(.{}, transpileFileWorker, .{allocator, io, init_file, visited, threads, false, mod});
                    try threads.append(allocator, t);
                } else |_| {
                    const lib_mod_file = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.py", .{mod_slash});
                    defer allocator.free(lib_mod_file);
                    if (cwd.access(io, lib_mod_file, .{})) {
                        const t = try std.Thread.spawn(.{}, transpileFileWorker, .{allocator, io, lib_mod_file, visited, threads, false, mod});
                        try threads.append(allocator, t);
                    } else |_| {
                        const lib_init_file = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/__init__.py", .{mod_slash});
                        defer allocator.free(lib_init_file);
                        if (cwd.access(io, lib_init_file, .{})) {
                            const t = try std.Thread.spawn(.{}, transpileFileWorker, .{allocator, io, lib_init_file, visited, threads, false, mod});
                            try threads.append(allocator, t);
                        } else |_| {
                            const sys_ver = try getSystemPythonVersion(allocator, io, "/usr/lib") orelse "python3.14";
                            
                            const site_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}/site-packages", .{sys_ver});
                            defer allocator.free(site_dir);
                            const sys_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}", .{sys_ver});
                            defer allocator.free(sys_dir);
                            
                            const checks = [_][]const u8{
                                try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{site_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{site_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, "{s}/{s}.so", .{site_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{sys_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{sys_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, "{s}/{s}.so", .{sys_dir, mod_slash}),
                                try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.py", .{mod_slash}),
                                try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/__init__.py", .{mod_slash}),
                                try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.so", .{mod_slash}),
                            };
                            defer {
                                for (checks) |c| allocator.free(c);
                            }
                            
                            var found_external = false;
                            for (checks) |c| {
                                if (std.Io.Dir.accessAbsolute(io, c, .{})) |_| {
                                    found_external = true;
                                    break;
                                } else |_| {}
                            }
                            // Also check if findSoFile finds it in cache just in case
                            if (!found_external) {
                                if (try findSoFile(allocator, io, ".cache/pyLibrary", mod_slash)) |f| {
                                    defer allocator.free(f);
                                    found_external = true;
                                }
                            }
                            
                            if (found_external) {
                                std.debug.print("Found external/system module '{s}', bridging via Python ABI...\n", .{mod});
                                
                                const dest_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{mod_slash});
                                defer allocator.free(dest_path);
                                if (std.fs.path.dirname(dest_path)) |dir| {
                                    cwd.createDirPath(io, dir) catch {};
                                }
                                
                                var depth: usize = 0;
                                for (mod_slash) |c| {
                                    if (c == '/') depth += 1;
                                }
                                var prefix_buf: [128]u8 = undefined;
                                var prefix_len: usize = 0;
                                var _d: usize = 0;
                                while (_d < depth) : (_d += 1) {
                                    @memcpy(prefix_buf[prefix_len..prefix_len+3], "../");
                                    prefix_len += 3;
                                }
                                const prefix = prefix_buf[0..prefix_len];
                                
                                const wrapper_code = try std.fmt.allocPrint(allocator,
                                    \\const std = @import("std");
                                    \\const dynamic = @import("{s}datatype/dynamic.zig");
                                    \\const Dynamic = dynamic.Dynamic;
                                    \\const PikaPython = @import("{s}datatype/python_abi.zig").PikaPython;
                                    \\
                                    \\pub const _is_abi = true;
                                    \\pub var _module: Dynamic = undefined;
                                    \\
                                    \\pub fn __sundapy_module_init() !void {{
                                    \\    try PikaPython.init();
                                    \\    _module = try PikaPython.importModule("{s}");
                                    \\}}
                                    \\
                                    \\pub fn builtin_getattr(attr: []const u8) Dynamic {{
                                    \\    return _module.getAbiAttribute(attr);
                                    \\}}
                                    \\
                                , .{prefix, prefix, mod});
                                defer allocator.free(wrapper_code);
                                cwd.writeFile(io, .{ .sub_path = dest_path, .data = wrapper_code }) catch {};
                            } else {
                                try addMissingModule(allocator, io, mod);
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
}

fn transpileFileWorker(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, visited: *SharedVisited, threads: *std.ArrayList(std.Thread), is_root: bool, mod_name: ?[]const u8) void {
    transpileFile(allocator, io, file_path, visited, threads, is_root, mod_name) catch |err| {
        std.debug.print("Transpilation worker failed for {s}: {any}\n", .{file_path, err});
    };
}
