const std = @import("std");
const parser_mod = @import("../parser/parser.zig");
const transpiler_mod = @import("../transpiler/transpiler.zig");
const compiler = @import("compiler.zig");
const SharedVisited = compiler.SharedVisited;
fn isPythonStdlib(mod: []const u8) bool {
    const stdlib_modules = [_][]const u8{
        "os", "sys", "timeit", "functools", "contextvars", "math", "json", "random",
        "re", "datetime", "subprocess", "io", "collections", "itertools", "string", "hashlib",
        "shutil", "tempfile", "pathlib", "logging", "typing", "typing_extensions", "dataclasses",
        "enum", "copy", "inspect", "traceback", "builtins", "weakref", "struct", "gc", "errno",
        "posix", "abc", "types", "uuid", "base64", "csv", "zlib", "sqlite3", "ssl", "urllib",
        "http", "xml", "array", "decimal", "fractions", "bisect", "heapq", "queue", "select",
        "selectors", "signal", "concurrent",
    };
    for (stdlib_modules) |m| {
        if (std.mem.eql(u8, mod, m)) return true;
    }
    return false;
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
        var leading_dots: usize = 0;
        while (leading_dots < mod.len and mod[leading_dots] == '.') {
            leading_dots += 1;
        }
        
        var mod_slash: []u8 = undefined;
        var resolved_dir: []const u8 = undefined;

        if (leading_dots > 0) {
            const clean_mod = mod[leading_dots..];
            const clean_mod_slash = try std.mem.replaceOwned(u8, allocator, clean_mod, ".", "/");
            defer allocator.free(clean_mod_slash);
            
            var curr_dir: []const u8 = std.fs.path.dirname(file_path) orelse ".";
            var up = leading_dots - 1;
            while (up > 0) : (up -= 1) {
                if (std.fs.path.dirname(curr_dir)) |parent| {
                    curr_dir = parent;
                }
            }
            
            if (clean_mod.len > 0) {
                resolved_dir = curr_dir;
                mod_slash = try std.fmt.allocPrint(allocator, "{s}", .{clean_mod_slash});
            } else {
                resolved_dir = curr_dir;
                mod_slash = try allocator.dupe(u8, "__init__");
            }
        } else {
            resolved_dir = dir_path;
            mod_slash = try std.mem.replaceOwned(u8, allocator, mod, ".", "/");
        }
        defer allocator.free(mod_slash);


        const embedded = @import("../embedded_datatype.zig");
        const stdlib_rel_name = try std.fmt.allocPrint(allocator, "sundapy_std/{s}.zig", .{mod});
        defer allocator.free(stdlib_rel_name);
        
        var embedded_stdlib_data: ?[]const u8 = null;
        inline for (embedded.files) |entry| {
            if (std.mem.eql(u8, entry[0], stdlib_rel_name)) {
                embedded_stdlib_data = entry[1];
            }
        }
        
        if (embedded_stdlib_data) |stdlib_code| {
            const dest_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{mod_slash});
            defer allocator.free(dest_path);
            
            if (std.fs.path.dirname(dest_path)) |dir| {
                cwd.createDirPath(io, dir) catch {};
            }
            cwd.writeFile(io, .{ .sub_path = dest_path, .data = stdlib_code }) catch {};
            
            if (std.mem.eql(u8, mod, "requests")) {
                inline for (embedded.files) |entry| {
                    if (std.mem.eql(u8, entry[0], "sundapy_std/socket.zig")) {
                        cwd.writeFile(io, .{ .sub_path = ".cache/src/socket.zig", .data = entry[1] }) catch {};
                    }
                }
            }
        } else {
            const mod_file = try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{resolved_dir, mod_slash});
            
            
            if (cwd.access(io, mod_file, .{})) |_| {
                try transpileFile(allocator, io, mod_file, visited, threads, false, mod);
                  
            } else |_| {
                const init_file = try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{resolved_dir, mod_slash});
                
                if (cwd.access(io, init_file, .{})) {
                    try transpileFile(allocator, io, init_file, visited, threads, false, mod);
                } else |_| {
                    const sys_ver = try compiler.getSystemPythonVersion(allocator, io, "/usr/lib") orelse "python3.14";
                    
                    const site_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}/site-packages", .{sys_ver});
                    defer allocator.free(site_dir);
                    const sys_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}", .{sys_ver});
                    defer allocator.free(sys_dir);
                    
                    const local_site_dir = try std.fmt.allocPrint(allocator, "/home/encu/.local/lib/{s}/site-packages", .{sys_ver});
                    defer allocator.free(local_site_dir);
                    const checks = [_][]const u8{
                        try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.py", .{mod_slash}),
                        try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/__init__.py", .{mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{site_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{site_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.so", .{site_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{sys_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{sys_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.so", .{sys_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{local_site_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{local_site_dir, mod_slash}),
                        try std.fmt.allocPrint(allocator, "{s}/{s}.so", .{local_site_dir, mod_slash}),
                    };
                    defer {
                        for (checks) |c| allocator.free(c);
                    }
                    
                    var found_external = isPythonStdlib(mod);
                    if (!found_external) {
                        for (checks) |c| {
                            if (std.mem.startsWith(u8, c, "/")) {
                                if (std.Io.Dir.accessAbsolute(io, c, .{})) |_| {
                                    found_external = true;
                                    break;
                                } else |_| {}
                            } else {
                                if (std.Io.Dir.cwd().access(io, c, .{})) |_| {
                                    found_external = true;
                                    break;
                                } else |_| {}
                            }
                        }
                    }
                    // Also check if findSoFile finds it in cache just in case
                    if (!found_external) {
                        if (try compiler.findSoFile(allocator, io, ".cache/pyLibrary", mod_slash)) |f| {
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
                        try compiler.addMissingModule(allocator, io, mod);
                        return;
                    }
                }
            }
        }
    }
}
