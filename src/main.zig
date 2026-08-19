const std = @import("std");

fn getTimeNs() isize {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(std.os.linux.CLOCK.MONOTONIC, &ts);
    return ts.sec * 1000000000 + ts.nsec;
}



pub fn main(ctx: std.process.Init) !void {
    // FORCE COMPILE CHECKS FOR ALL MODULES
    _ = @import("datatype/dynamic.zig");
    _ = @import("datatype/primitive/index.zig");
    _ = @import("datatype/numeric/index.zig");
    _ = @import("lexer/lexer.zig");
    _ = @import("parser/parser.zig");
    _ = @import("core/cache.zig");
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.Args.Iterator.initAllocator(ctx.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // skip executable

    var is_build_mode = false;
    var is_no_panic = false;
    var is_fetch_mode = false;
    var script_path: ?[]const u8 = null;
    var auto_yes = false;
    var fetch_args: std.ArrayList([]const u8) = .empty;
    defer fetch_args.deinit(allocator);

    while (args_iter.next()) |arg| {
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

        var cache = @import("core/cache.zig").CacheManager.init(allocator);
        try cache.ensureCacheDirs(allocator, io);

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

    const compiler_check = @import("core/compiler_check.zig");

    // 1. Resolve and Validate Zig Compiler (0.16.0 required)
    const zig_bin = compiler_check.resolveZigCompiler(allocator, io) catch {
        std.process.exit(1);
    };

    var cache = @import("core/cache.zig").CacheManager.init(allocator);
    try cache.ensureCacheDirs(allocator, io);

    // 3. Read Script and Compute Hash
    const cwd = std.Io.Dir.cwd();
    const script_content = cwd.readFileAlloc(io, final_script, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Error reading script '{s}': {}\n", .{ final_script, err });
        std.process.exit(1);
    };
    defer allocator.free(script_content);
    const current_hash = cache.computeHash(script_content);

    // 4. Derive names
    const basename = std.fs.path.basename(final_script);
    const stem = if (std.mem.lastIndexOfScalar(u8, basename, '.')) |idx| basename[0..idx] else basename;
    const zig_src_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}.zig", .{stem});
    defer allocator.free(zig_src_path);
    const cached_bin_path = try std.fmt.allocPrint(allocator, ".cache/bin/{s}", .{stem});
    defer allocator.free(cached_bin_path);

    var needs_compile = is_build_mode;
    if (!is_build_mode) {
        if (try cache.isCacheValid(io, final_script, current_hash)) {
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
        
        const compiler = @import("core/compiler.zig");
        
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
                        }
                    }
                }
                
                if (proceed_fetch) {
                    var all_success = true;
                    for (compiler.global_missing_modules.items) |mod| {
                        std.debug.print("Fetching '{s}'...\n", .{mod});
                        const cmd_str = try std.fmt.allocPrint(allocator, "./zig-out/bin/sundafetch {s}", .{mod});
                        defer allocator.free(cmd_str);
                        const cmd = &[_][]const u8{ "sh", "-c", cmd_str };
                        const res = std.process.run(allocator, io, .{ .argv = cmd }) catch null;
                        if (res != null and res.?.term == .exited and res.?.term.exited == 0) {
                            std.debug.print("Successfully fetched '{s}'.\n", .{mod});
                        } else {
                            std.debug.print("Failed to fetch '{s}'.\n", .{mod});
                            all_success = false;
                        }
                    }
                    if (all_success) {
                        std.debug.print("\nResuming compilation automatically...\n\n", .{});
                        continue;
                    } else {
                        std.debug.print("\nPlease resolve the missing dependencies and re-run sundapy.\n\n", .{});
                        std.process.exit(1);
                    }
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


// Copy datatype dir to cache so relative imports work
        cwd.access(io, ".cache/src/datatype", .{}) catch |err| {
            if (err == error.FileNotFound) {
                const cp_dt_res = try std.process.run(allocator, io, .{
                    .argv = &[_][]const u8{"cp", "-r", "src/datatype", ".cache/src/"},
                });
                if (cp_dt_res.term != .exited or cp_dt_res.term.exited != 0) {
                    std.debug.print("Failed to copy datatype!\n{s}\n", .{cp_dt_res.stderr});
                }
            }
        };
        
        var zig_cmd = std.ArrayList([]const u8).empty;
        defer zig_cmd.deinit(allocator);
        
        try zig_cmd.appendSlice(allocator, &[_][]const u8{
            zig_bin, "build-exe", root_arg,
            "-O", "ReleaseSmall",
        });

        try zig_cmd.appendSlice(allocator, &[_][]const u8{"-lc"});
        
        try zig_cmd.appendSlice(allocator, &[_][]const u8{
            "-fstrip",
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
        _ = std.process.run(allocator, io, .{
            .argv = &[_][]const u8{ "strip", cached_bin_path },
        }) catch {};

        // Update Hash if successfully compiled
        try cache.updateCacheHash(io, final_script, current_hash);
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
            std.debug.print("Execution failed!\n{s}\n", .{run_res.stderr});
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
