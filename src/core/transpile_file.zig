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

pub fn transpileFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, visited: *SharedVisited, threads: *std.ArrayList(std.Thread), is_root: bool, mod_name: ?[]const u8, is_speculative: bool) !void {
    if (try visited.containsAndPut(io, file_path)) return;

    const cwd = std.Io.Dir.cwd();
    const script_content = cwd.readFileAlloc(io, file_path, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        if (!is_speculative) std.debug.print("Could not read imported file: {s} (error: {any})\n", .{file_path, err});
        return err;
    };
    defer allocator.free(script_content);
    
    var lexer = @import("../lexer/lexer.zig").Lexer.init(allocator, script_content);
    defer lexer.deinit();

    var parser = if (is_speculative)
        @import("../parser/parser.zig").Parser.initQuiet(allocator, &lexer)
    else
        @import("../parser/parser.zig").Parser.init(allocator, &lexer);
    var program = parser.parseProgram() catch |err| {
        if (!is_root) return err;
        std.debug.print("Syntax error during parsing {s}: {}\n", .{file_path, err});
        std.process.exit(1);
    };
    defer program.deinit(allocator);

    const is_pkg = std.mem.endsWith(u8, file_path, "__init__.py");
    var transpiler = @import("../transpiler/transpiler.zig").Transpiler.init(allocator, is_root, if (mod_name) |m| m else "", is_pkg);
    defer transpiler.deinit();

    const zig_code = transpiler.transpile(program) catch |err| {
        if (!is_root) return err;
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
    
    if (transpiler.has_async_def) {
        _ = try compiler.ensureNativeStdlib(allocator, io, "asyncio", "asyncio");
    }

    const dir_path = std.fs.path.dirname(file_path) orelse ".";
    for (transpiler.imported_modules.items) |mod| {
        var clean_mod = mod;
        var leading_dots: usize = 0;
        while (leading_dots < clean_mod.len and clean_mod[leading_dots] == '.') {
            leading_dots += 1;
        }
        if (leading_dots > 0 and leading_dots < clean_mod.len and clean_mod[leading_dots] == '/') {
            leading_dots += 1;
        }
        var raw_mod = clean_mod[leading_dots..];
        const is_zig_ext = std.mem.endsWith(u8, raw_mod, ".zig");
        if (is_zig_ext) {
            raw_mod = raw_mod[0 .. raw_mod.len - 4];
        }
        
        var mod_slash: []u8 = undefined;
        var resolved_dir: []const u8 = undefined;

        if (leading_dots > 0) {
            const clean_mod_slash = try std.mem.replaceOwned(u8, allocator, raw_mod, ".", "/");
            defer allocator.free(clean_mod_slash);
            
            var curr_dir: []const u8 = std.fs.path.dirname(file_path) orelse ".";
            var up = leading_dots - 1;
            while (up > 0) : (up -= 1) {
                if (std.fs.path.dirname(curr_dir)) |parent| {
                    curr_dir = parent;
                }
            }
            
            if (raw_mod.len > 0) {
                resolved_dir = curr_dir;
                mod_slash = try std.fmt.allocPrint(allocator, "{s}", .{clean_mod_slash});
            } else {
                resolved_dir = curr_dir;
                mod_slash = try allocator.dupe(u8, "__init__");
            }
        } else {
            resolved_dir = dir_path;
            mod_slash = try std.mem.replaceOwned(u8, allocator, raw_mod, ".", "/");
        }
        defer allocator.free(mod_slash);

        var target_mod_name: []const u8 = mod;
        var free_target_mod = false;
        if (leading_dots > 0) {
            if (is_root or mod_name == null or mod_name.?.len == 0) {
                std.debug.print("ImportError: attempted relative import with no known parent package\n", .{});
                return error.RelativeImportNoParentPackage;
            }
            var target_dest_dir = if (is_pkg) stem_slash else (std.fs.path.dirname(stem_slash) orelse "");
            var up_dest = leading_dots - 1;
            while (up_dest > 0) : (up_dest -= 1) {
                target_dest_dir = std.fs.path.dirname(target_dest_dir) orelse "";
            }
            if (up_dest > 0 or target_dest_dir.len == 0) {
                std.debug.print("ValueError: attempted relative import beyond top-level package\n", .{});
                return error.RelativeImportBeyondTopLevel;
            }
            const dest_stem = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ target_dest_dir, mod_slash });
            defer allocator.free(dest_stem);
            const dots_name = try allocator.dupe(u8, dest_stem);
            for (dots_name) |*c| { if (c.* == '/') c.* = '.'; }
            target_mod_name = dots_name;
            free_target_mod = true;
        }
        defer if (free_target_mod) allocator.free(target_mod_name);

        if (std.mem.endsWith(u8, mod, ".h") or std.mem.endsWith(u8, mod, ".c")) {
            const comp = @import("compiler.zig");
            if (std.mem.endsWith(u8, mod, ".c")) {
                if (cwd.access(io, mod, .{})) |_| {
                    try comp.addCSourceFile(allocator, mod);
                } else |_| {
                    const c_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ resolved_dir, mod });
                    try comp.addCSourceFile(allocator, c_path);
                }
            } else if (std.mem.endsWith(u8, mod, ".h")) {
                const mod_no_ext = mod[0 .. mod.len - 2];
                const c_cand1 = try std.fmt.allocPrint(allocator, "{s}.c", .{mod_no_ext});
                defer allocator.free(c_cand1);
                if (cwd.access(io, c_cand1, .{})) |_| {
                    try comp.addCSourceFile(allocator, c_cand1);
                } else |_| {
                    const c_cand2 = try std.fmt.allocPrint(allocator, "{s}/{s}.c", .{ resolved_dir, mod_no_ext });
                    defer allocator.free(c_cand2);
                    if (cwd.access(io, c_cand2, .{})) |_| {
                        try comp.addCSourceFile(allocator, c_cand2);
                    } else |_| {}
                }
            }
            if (comp.global_link_libs.items.len == 0) {
                if (std.mem.indexOf(u8, mod, "raylib") != null) {
                    try comp.addLinkLib(allocator, "raylib");
                } else if (std.mem.indexOf(u8, mod, "math.h") != null) {
                    try comp.addLinkLib(allocator, "m");
                }
            }
            continue;
        }

        var found_zig_src: ?[]const u8 = null;
        var zig_candidates: [6][]const u8 = undefined;
        var zig_cands_len: usize = 0;
        if (is_zig_ext) {
            zig_candidates[zig_cands_len] = mod; zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ resolved_dir, mod }); zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ resolved_dir, mod_slash }); zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}.zig", .{ mod_slash }); zig_cands_len += 1;
        } else {
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ resolved_dir, mod_slash }); zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ resolved_dir, mod }); zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}.zig", .{ mod_slash }); zig_cands_len += 1;
            zig_candidates[zig_cands_len] = try std.fmt.allocPrint(allocator, "{s}.zig", .{ mod }); zig_cands_len += 1;
        }

        for (zig_candidates[0..zig_cands_len]) |cand| {
            if (cwd.access(io, cand, .{})) |_| {
                found_zig_src = cand;
                break;
            } else |_| {}
        }

        if (found_zig_src) |z_src| {
            const dest_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{mod_slash});
            defer allocator.free(dest_path);
            if (std.fs.path.dirname(dest_path)) |dir| {
                cwd.createDirPath(io, dir) catch {};
            }
            if (cwd.readFileAlloc(io, z_src, allocator, @enumFromInt(10 * 1024 * 1024))) |zig_content| {
                defer allocator.free(zig_content);
                cwd.writeFile(io, .{ .sub_path = dest_path, .data = zig_content }) catch {};
            } else |_| {}
            for (zig_candidates[0..zig_cands_len]) |c| {
                if (c.ptr != mod.ptr) allocator.free(c);
            }
            continue;
        }

        for (zig_candidates[0..zig_cands_len]) |c| {
            if (c.ptr != mod.ptr) allocator.free(c);
        }

        if (leading_dots == 0 and try compiler.ensureNativeStdlib(allocator, io, raw_mod, mod_slash)) {
            continue;
        } else {
            const mod_file = try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{resolved_dir, mod_slash});
            defer allocator.free(mod_file);
            if (cwd.access(io, mod_file, .{})) |_| {
                try transpileFile(allocator, io, mod_file, visited, threads, false, target_mod_name, is_speculative);
            } else |_| {
                const init_file = try std.fmt.allocPrint(allocator, "{s}/{s}/__init__.py", .{resolved_dir, mod_slash});
                defer allocator.free(init_file);
                if (cwd.access(io, init_file, .{})) {
                    try transpileFile(allocator, io, init_file, visited, threads, false, target_mod_name, is_speculative);
                } else |_| {
                    const cache_py = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.py", .{mod_slash});
                    defer allocator.free(cache_py);
                    const cache_init = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/__init__.py", .{mod_slash});
                    defer allocator.free(cache_init);

                    const in_cache_py = if (cwd.access(io, cache_py, .{})) true else |_| false;
                    const in_cache_init = if (cwd.access(io, cache_init, .{})) true else |_| false;

                    if (in_cache_py or in_cache_init) {
                        const has_so = compiler.packageContainsSo(allocator, io, ".cache/pyLibrary", mod_slash);
                        if (has_so) {
                            // Binary C-Extension detected -> bridge via Python C-ABI
                            try bridgeViaPythonAbi(allocator, io, mod, mod_slash);
                        } else {
                            // Pure Python package in .cache/pyLibrary -> attempt native Zig transpilation first!
                            const pure_file = if (in_cache_py) cache_py else cache_init;
                            std.debug.print("Found pure Python library '{s}' in .cache/pyLibrary, attempting native Zig transpilation...\n", .{mod});
                            transpileFile(allocator, io, pure_file, visited, threads, false, mod, true) catch |err| {
                                std.debug.print("Native transpilation for '{s}' encountered {any}, falling back to Python ABI bridge...\n", .{ mod, err });
                                try bridgeViaPythonAbi(allocator, io, mod, mod_slash);
                            };
                        }
                    } else {
                        const sys_ver = try compiler.getSystemPythonVersion(allocator, io, "/usr/lib") orelse "python3.14";

                        const site_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}/site-packages", .{sys_ver});
                        defer allocator.free(site_dir);
                        const sys_dir = try std.fmt.allocPrint(allocator, "/usr/lib/{s}", .{sys_ver});
                        defer allocator.free(sys_dir);

                        const local_site_dir = try std.fmt.allocPrint(allocator, "/home/encu/.local/lib/{s}/site-packages", .{sys_ver});
                        defer allocator.free(local_site_dir);
                        const checks = [_][]const u8{
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
                                if (std.Io.Dir.accessAbsolute(io, c, .{})) |_| {
                                    found_external = true;
                                    break;
                                } else |_| {}
                            }
                        }

                        if (found_external) {
                            try bridgeViaPythonAbi(allocator, io, mod, mod_slash);
                        } else {
                            try compiler.addMissingModule(allocator, io, mod);
                            return;
                        }
                    }
                }
            }
        }
    }
}

fn bridgeViaPythonAbi(allocator: std.mem.Allocator, io: std.Io, mod: []const u8, mod_slash: []const u8) !void {
    compiler.global_uses_c_abi = true;
    std.debug.print("Found external/binary module '{s}', bridging via Python ABI...\n", .{mod});

    const cwd = std.Io.Dir.cwd();
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
        @memcpy(prefix_buf[prefix_len .. prefix_len + 3], "../");
        prefix_len += 3;
    }
    const prefix = prefix_buf[0..prefix_len];

    const wrapper_code = try std.fmt.allocPrint(allocator,
        \\const std = @import("std");
        \\const dynamic = @import("{s}datatype/dynamic.zig");
        \\const Dynamic = dynamic.Dynamic;
        \\const sundapyBridge = @import("{s}datatype/python_abi.zig").sundapyBridge;
        \\
        \\pub const _is_abi = true;
        \\pub var _module: Dynamic = undefined;
        \\
        \\pub fn __sundapy_module_init() !void {{
        \\    try sundapyBridge.init();
        \\    _module = try sundapyBridge.importModule("{s}");
        \\}}
        \\
        \\pub fn builtin_getattr(attr: []const u8) Dynamic {{
        \\    return _module.getAbiAttribute(attr);
        \\}}
        \\
    , .{ prefix, prefix, mod });
    defer allocator.free(wrapper_code);
    try cwd.writeFile(io, .{ .sub_path = dest_path, .data = wrapper_code });
}
