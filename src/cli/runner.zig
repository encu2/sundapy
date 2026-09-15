const std = @import("std");
const core = @import("../core/compiler.zig");
const cache = @import("../core/cache.zig");
const embedded_datatype = @import("../embedded_datatype.zig");
pub fn main(ctx: std.process.Init) !void {
    // FORCE COMPILE CHECKS FOR ALL MODULES
    _ = @import("../datatype/dynamic.zig");
    _ = @import("../datatype/primitive/index.zig");
    _ = @import("../datatype/numeric/index.zig");
    _ = @import("../lexer/lexer.zig");
    _ = @import("../parser/parser.zig");
    _ = @import("../core/cache.zig");
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.Args.Iterator.initAllocator(ctx.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // skip executable

    var is_build_mode = false;
    var is_debug = false;
    var is_no_panic = false;
    var is_fetch_mode = false;
    var script_path: ?[]const u8 = null;
    var auto_yes = false;
    var fetch_args: std.ArrayList([]const u8) = .empty;
    defer fetch_args.deinit(allocator);

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--debug")) {
            is_debug = true;
        }
        if (std.mem.eql(u8, arg, "--build")) {
            is_build_mode = true;
        }
        if (std.mem.eql(u8, arg, "--no-panic")) {
            is_no_panic = true;
            std.debug.print("WARNING: --no-panic is enabled. No error logs will be printed on crash.\n", .{});
        } else if (false) {
            is_build_mode = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-y")) {
            auto_yes = true;
        } else if (std.mem.eql(u8, arg, "fetch")) {
            is_fetch_mode = true;
            while (args_iter.next()) |fetch_arg| {
                try fetch_args.append(allocator, fetch_arg);
            }
            break;
        } else {
            script_path = arg;
            // continue looking for flags like -y if placed after script
        }
    }

    if (is_fetch_mode) {
        var threaded = std.Io.Threaded.init(allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        var cache_mgr = @import("../core/cache.zig").CacheManager.init(allocator);
        try cache_mgr.ensureCacheDirs(allocator, io);

        var uv_args: std.ArrayList([]const u8) = .empty;
        try uv_args.appendSlice(allocator, &[_][]const u8{"/home/encu/.local/bin/uv", "pip", "install", "--target", ".cache/pyLibrary"});
        try uv_args.appendSlice(allocator, fetch_args.items);

        std.debug.print("Fetching packages via uv...\n", .{});
        const uv_res = try std.process.run(allocator, io, .{
            .argv = uv_args.items,
        });

        if (uv_res.term != .exited or uv_res.term.exited != 0) {
            std.debug.print("Fetch failed!\n{s}\n", .{uv_res.stderr});
            std.process.exit(1);
        } else {
            std.debug.print("Fetch complete!\n{s}\n", .{uv_res.stdout});
            std.process.exit(0);
        }
    }

    const final_script = script_path orelse {
        printHelp();
        std.process.exit(1);
    };

    // 2. Initialize Io and Cache Manager
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const compiler_check = @import("../core/compiler_check.zig");

    // 1. Resolve and Validate Zig Compiler (0.16.0 required)
    const zig_bin = compiler_check.resolveZigCompiler(allocator, io) catch {
        std.process.exit(1);
    };

    var cache_mgr = @import("../core/cache.zig").CacheManager.init(allocator);
    try cache_mgr.ensureCacheDirs(allocator, io);

    // 3. Read Script and Compute Hash
    const cwd = std.Io.Dir.cwd();
    const script_content = cwd.readFileAlloc(io, final_script, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Error reading script '{s}': {}\n", .{ final_script, err });
        std.process.exit(1);
    };
    defer allocator.free(script_content);
    const current_hash = cache_mgr.computeHash(script_content);

    // 4. Derive names
    const basename = std.fs.path.basename(final_script);
    const stem = if (std.mem.lastIndexOfScalar(u8, basename, '.')) |idx| basename[0..idx] else basename;
    const zig_src_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{stem});
    defer allocator.free(zig_src_path);
    const cached_bin_path = try std.fmt.allocPrint(allocator, ".cache/bin/{s}_{x}", .{ stem, current_hash });
    defer allocator.free(cached_bin_path);

    var needs_compile = is_build_mode;
    if (!is_build_mode) {
        if (try cache_mgr.isCacheValid(io, final_script, current_hash)) {
            // Check if binary actually exists
            if (cwd.access(io, cached_bin_path, .{})) |_| {
                needs_compile = false;
            } else |_| {
                needs_compile = true;
            }
        } else {
            needs_compile = true;
        }
    }

    if (needs_compile) {
        // [AST and Transpiler Phase]
        std.debug.print("Compiling {s}...\n", .{final_script});
        
        const compiler = @import("../core/compiler.zig");
        
        var compile_attempts: usize = 0;
        while (compile_attempts < 5) : (compile_attempts += 1) {
            var visited = compiler.SharedVisited.init(allocator);
            defer visited.deinit();

            var threads: std.ArrayList(std.Thread) = .empty;
            defer threads.deinit(allocator);
            
            compiler.global_uses_dynamic = false;
            compiler.global_uses_c_abi = false;
            compiler.is_no_panic = is_no_panic;
            compiler.global_missing_modules = .empty;
            compiler.global_missing_initialized = true;
            defer {
                for (compiler.global_missing_modules.items) |item| {
                    allocator.free(item);
                }
                compiler.global_missing_modules.deinit(allocator);
                compiler.global_missing_initialized = false;
            }

            try compiler.transpileFile(allocator, io, final_script, &visited, &threads, true, null);
            
            for (threads.items) |t| {
                t.join();
            }

            if (compiler.global_missing_modules.items.len > 0) {
                std.debug.print("\n[SUNDAPY] Missing External Libraries Detected:\n", .{});
                for (compiler.global_missing_modules.items) |mod| {
                    std.debug.print("  - {s}\n", .{mod});
                }
                std.debug.print("\nThese modules were not found in local directories, .cache/pyLibrary, or system Python.\n", .{});
                
                var proceed_fetch = false;
                if (auto_yes) {
                    std.debug.print("Auto-fetching due to -y flag...\n", .{});
                    proceed_fetch = true;
                } else {
                    std.debug.print("Would you like to automatically fetch them using 'sundafetch'? [Y/n]: ", .{});
                    
                    var buf: [16]u8 = undefined;
                    const bytes_read = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
                    if (bytes_read > 0) {
                        const line = std.mem.trim(u8, buf[0..bytes_read], " \r\n");
                        if (line.len == 0 or line[0] == 'y' or line[0] == 'Y') {
                            proceed_fetch = true;
                            auto_yes = true;
                        }
                    }
                }
                
                if (proceed_fetch) {
                    var all_success = true;
                    for (compiler.global_missing_modules.items) |mod| {
                        std.debug.print("Fetching '{s}'...\n", .{mod});
                        var fetch_failed = false;
                        
                        // 1. Try fetching via uv pip install --target .cache/pyLibrary <mod>
                        const uv_args = &[_][]const u8{ "/home/encu/.local/bin/uv", "pip", "install", "--target", ".cache/pyLibrary", mod };
                        const uv_res = std.process.run(allocator, io, .{ .argv = uv_args }) catch null;
                        if (uv_res != null and uv_res.?.term == .exited and uv_res.?.term.exited == 0) {
                            fetch_failed = false;
                        } else {
                            // 2. Fallback to sundafetch if uv is not available
                            const exe_dir = std.process.executableDirPathAlloc(io, allocator) catch ".";
                            defer if (!std.mem.eql(u8, exe_dir, ".")) allocator.free(exe_dir);
                            const cmd_str = try std.fmt.allocPrint(allocator, "{s}/sundafetch {s}", .{exe_dir, mod});
                            defer allocator.free(cmd_str);
                            const cmd = &[_][]const u8{ "sh", "-c", cmd_str };
                            const res = std.process.run(allocator, io, .{ .argv = cmd }) catch null;
                            if (res == null or res.?.term != .exited or res.?.term.exited != 0) {
                                fetch_failed = true;
                            } else if (res != null and res.?.stderr.len > 0) {
                                if (std.mem.indexOf(u8, res.?.stderr, "Error fetching") != null or 
                                    std.mem.indexOf(u8, res.?.stderr, "Failed to fetch metadata") != null) {
                                    fetch_failed = true;
                                }
                            }
                        }

                        if (!fetch_failed) {
                            std.debug.print("Successfully fetched '{s}'.\n", .{mod});
                        } else {
                            std.debug.print("Failed to fetch '{s}'. Marking as failed and continuing...\n", .{mod});
                            if (!compiler.global_failed_modules.contains(mod)) {
                                if (allocator.dupe(u8, mod)) |mod_dup| {
                                    compiler.global_failed_modules.put(allocator, mod_dup, true) catch {};
                                } else |_| {}
                            }
                            all_success = false;
                        }
                    }
                    std.debug.print("\nResuming compilation automatically...\n\n", .{});
                    if (!all_success) break;
                    continue;
                }
                
                std.debug.print("\nOperation cancelled. You can install them manually by running:\n", .{});
                for (compiler.global_missing_modules.items) |mod| {
                    std.debug.print("  sundafetch {s}\n", .{mod});
                }
                std.debug.print("\n", .{});
                std.process.exit(1);
            }
            
            // If we reach here, there are no missing modules!
            break;
        }

        // [Compilation Phase]
        
        var entry_content_str = std.ArrayList(u8).empty;
        defer entry_content_str.deinit(allocator);
        
        const part1 = try std.fmt.allocPrint(allocator, "const std = @import(\"std\");\nconst script = @import(\"{s}.zig\");\n", .{stem});
        defer allocator.free(part1);
        try entry_content_str.appendSlice(allocator, part1);
        
        if (compiler.is_no_panic) {
            try entry_content_str.appendSlice(allocator, "pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn { _=msg; _=error_return_trace; _=ret_addr; while (true) {} }\n");
        }
        
        try entry_content_str.appendSlice(allocator, "pub fn main() !void {\n    try script.__sundapy_module_init();\n}\n");
        
        try cwd.writeFile(io, .{ .sub_path = ".cache/src/__entry.zig", .data = entry_content_str.items });

        const emit_bin_arg = try std.fmt.allocPrint(allocator, "-femit-bin={s}", .{cached_bin_path});
        defer allocator.free(emit_bin_arg);

        const root_arg = ".cache/src/__entry.zig";


        // Extract embedded datatype dir to cache so relative imports work
        const embedded = @import("../embedded_datatype.zig");
        inline for (embedded.files) |entry| {
            const rel_path = entry[0];
            const data = entry[1];
            const full_path = std.fmt.allocPrint(allocator, ".cache/src/datatype/{s}", .{rel_path}) catch unreachable;
            defer allocator.free(full_path);
            
            if (std.fs.path.dirname(full_path)) |dir_path| {
                cwd.createDirPath(io, dir_path) catch {};
            }
            cwd.writeFile(io, .{ .sub_path = full_path, .data = data }) catch |write_err| {
                std.debug.print("Failed to write embedded file {s}: {any}\n", .{full_path, write_err});
            };
        }
        
        var zig_cmd = std.ArrayList([]const u8).empty;
        defer zig_cmd.deinit(allocator);
        
        try zig_cmd.appendSlice(allocator, &[_][]const u8{
            zig_bin, "build-exe", root_arg,
            "-O", if (is_debug) "ReleaseSafe" else "ReleaseSmall",
        });

        try zig_cmd.appendSlice(allocator, &[_][]const u8{"-lc"});
        
        if (!is_debug) {
            try zig_cmd.appendSlice(allocator, &[_][]const u8{ "-fstrip" });
        }
        try zig_cmd.appendSlice(allocator, &[_][]const u8{
            "--cache-dir", ".cache/zig_cache",
            "--global-cache-dir", ".cache/zig_global_cache",
            emit_bin_arg,
        });


        const compile_res = try std.process.run(allocator, io, .{
            .argv = zig_cmd.items,
        });

        if (compile_res.term != .exited or compile_res.term.exited != 0) {
            std.debug.print("Compilation failed!\n{s}\n", .{compile_res.stderr});
            std.process.exit(1);
        }

        // Workaround for Zig 0.16.0 cache bug ignoring -fstrip: explicitly strip the binary
        if (!is_debug) {
            _ = std.process.run(allocator, io, .{
                .argv = &[_][]const u8{ "strip", cached_bin_path },
            }) catch {};
        }

        // Update Hash if successfully compiled
        try cache_mgr.updateCacheHash(io, final_script, current_hash);
    }

    // 5. Execution or Build output
    if (is_build_mode) {
        // Move/Copy binary to CWD
        const dest_path = try std.fmt.allocPrint(allocator, "{s}", .{stem});
        defer allocator.free(dest_path);
        
        const cp_res = try std.process.run(allocator, io, .{
            .argv = &[_][]const u8{"cp", cached_bin_path, dest_path},
        });
        if (cp_res.term != .exited or cp_res.term.exited != 0) {
            std.debug.print("Failed to copy binary out!\n{s}\n", .{cp_res.stderr});
            std.process.exit(1);
        }
        std.debug.print("BUILD MODE: Compilation complete. Binary '{s}' has been generated in current directory.\n", .{dest_path});
    } else {
        // Run mode: Execute silently
        const run_cmd = &[_][]const u8{cached_bin_path};
        const run_res = try std.process.run(allocator, io, .{
            .argv = run_cmd,
        });
        
        if (run_res.term != .exited or run_res.term.exited != 0) {
            std.debug.print("Execution failed: {any}\nstdout: {s}\nstderr: {s}\n", .{run_res.term, run_res.stdout, run_res.stderr});
            std.process.exit(1);
        } else {
            // Print output directly
            if (run_res.stdout.len > 0) std.debug.print("{s}", .{run_res.stdout});
            if (run_res.stderr.len > 0) std.debug.print("{s}", .{run_res.stderr});
        }
    }
}

// ponytail: simple print block for help. No need for complex argparse libs yet (YAGNI).
fn printHelp() void {
    std.debug.print(
        \\SundaPy - A Python to Zig transpiler and runtime
        \\
        \\Usage: sundapy [options] [command] <script.py>
        \\
        \\Options:
        \\  -h, --help    Show this help message and exit
        \\  --build       Build a standalone executable from the Python script instead of running it directly\n        \\  --fast        Run in fast development mode (bypasses LLVM optimization for 6x faster compile)
        \\
        \\Commands:
        \\  fetch <pkg>   Download and install a package via uv into .cache/pyLibrary
        \\
        \\Examples:
        \\  sundapy main.py
        \\  sundapy --build main.py
        \\  sundapy fetch requests
        \\
    , .{});
}
