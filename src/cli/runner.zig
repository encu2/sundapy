const std = @import("std");
const core = @import("../core/compiler.zig");
const cache = @import("../core/cache.zig");
const builder = @import("builder.zig");
const missing = @import("missing_modules.zig");

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
    var is_release_fast = false;
    var is_no_panic = false;
    var is_fetch_mode = false;
    var is_init_mode = false;
    var script_path: ?[]const u8 = null;
    var auto_yes = false;
    var out_name: ?[]const u8 = null;
    var fetch_args: std.ArrayList([]const u8) = .empty;
    defer fetch_args.deinit(allocator);

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--debug")) {
            is_debug = true;
        } else if (std.mem.eql(u8, arg, "--fast") or std.mem.eql(u8, arg, "--release-fast") or std.mem.eql(u8, arg, "-O3")) {
            is_release_fast = true;
        } else if (std.mem.eql(u8, arg, "--build")) {
            is_build_mode = true;
        } else if (std.mem.eql(u8, arg, "--outname")) {
            if (args_iter.next()) |name_arg| {
                out_name = name_arg;
                is_build_mode = true;
            } else {
                std.debug.print("Error: --outname requires an argument\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.startsWith(u8, arg, "--outname=")) {
            out_name = arg["--outname=".len..];
            is_build_mode = true;
        } else if (std.mem.eql(u8, arg, "--no-panic")) {
            is_no_panic = true;
            std.debug.print("WARNING: --no-panic is enabled. No error logs will be printed on crash.\n", .{});
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            builder.printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-y")) {
            auto_yes = true;
        } else if (std.mem.eql(u8, arg, "init")) {
            is_init_mode = true;
            break;
        } else if (std.mem.eql(u8, arg, "fetch")) {
            is_fetch_mode = true;
            while (args_iter.next()) |fetch_arg| {
                try fetch_args.append(allocator, fetch_arg);
            }
            break;
        } else {
            script_path = arg;
        }
    }

    var threaded = std.Io.Threaded.init(allocator, .{ .environ = ctx.minimal.environ });
    defer threaded.deinit();
    const io = threaded.io();

    if (is_init_mode) {
        try @import("init.zig").runInit(allocator, io);
        std.process.exit(0);
    }

    if (is_fetch_mode) {
        var cache_mgr = @import("../core/cache.zig").CacheManager.init(allocator);
        try cache_mgr.ensureCacheDirs(allocator, io);

        const sundafetch_bin = builder.getSundafetchPath(allocator, io);
        var fetch_cmd = std.ArrayList([]const u8).empty;
        try fetch_cmd.append(allocator, sundafetch_bin);
        try fetch_cmd.appendSlice(allocator, fetch_args.items);

        std.debug.print("Fetching packages via sundafetch...\n", .{});
        const res = try std.process.run(allocator, io, .{
            .argv = fetch_cmd.items,
            .environ_map = ctx.environ_map,
        });

        if (res.stdout.len > 0) std.debug.print("{s}", .{res.stdout});
        if (res.stderr.len > 0) std.debug.print("{s}", .{res.stderr});

        if (res.term != .exited or res.term.exited != 0) {
            std.debug.print("Fetch failed!\n", .{});
            std.process.exit(1);
        } else {
            std.process.exit(0);
        }
    }

    const final_script = script_path orelse {
        builder.printHelp();
        std.process.exit(1);
    };

    const compiler_check = @import("../core/compiler_check.zig");
    const zig_bin = compiler_check.resolveZigCompiler(allocator, io) catch {
        std.process.exit(1);
    };

    var cache_mgr = @import("../core/cache.zig").CacheManager.init(allocator);
    try cache_mgr.ensureCacheDirs(allocator, io);
    builder.extractEmbeddedDatatype(allocator, io);

    const cwd = std.Io.Dir.cwd();
    const script_content = cwd.readFileAlloc(io, final_script, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Error reading script '{s}': {}\n", .{ final_script, err });
        std.process.exit(1);
    };
    defer allocator.free(script_content);
    const current_hash = cache_mgr.computeHash(script_content);

    const basename = std.fs.path.basename(final_script);
    const stem = if (std.mem.lastIndexOfScalar(u8, basename, '.')) |idx| basename[0..idx] else basename;
    const mode_str = if (is_debug) "debug" else if (is_release_fast) "fast" else "small";
    const cached_bin_path = try std.fmt.allocPrint(allocator, ".cache/bin/{s}_{s}_{x}", .{ stem, mode_str, current_hash });
    defer allocator.free(cached_bin_path);

    var needs_compile = is_build_mode or auto_yes;
    if (!needs_compile) {
        if (try cache_mgr.isCacheValid(io, final_script, current_hash)) {
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
            compiler.is_release_fast = is_release_fast;
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
                const proceed = missing.handleMissingModules(allocator, io, compiler, &auto_yes, ctx.environ_map);
                if (!proceed) break;
                continue;
            }
            break;
        }

        try builder.buildExecutable(allocator, io, zig_bin, stem, cached_bin_path, is_debug, is_release_fast, is_no_panic);
        try cache_mgr.updateCacheHash(io, final_script, current_hash);

        if (compiler.global_uses_c_abi) {
            std.debug.print("[SUNDAPY] Python C-ABI compatibility layer: ENABLED\n", .{});
        } else {
            std.debug.print("[SUNDAPY] Python C-ABI compatibility layer: NOT REQUIRED (Pure Native Mode)\n", .{});
        }
    }

    if (is_build_mode) {
        const dest_binary = out_name orelse stem;
        const dest_path = try std.fmt.allocPrint(allocator, "{s}", .{dest_binary});
        defer allocator.free(dest_path);

        const cp_res = try std.process.run(allocator, io, .{
            .argv = &[_][]const u8{ "cp", cached_bin_path, dest_path },
        });
        if (cp_res.term != .exited or cp_res.term.exited != 0) {
            std.debug.print("Failed to copy binary out!\n{s}\n", .{cp_res.stderr});
            std.process.exit(1);
        }
        std.debug.print("BUILD MODE: Compilation complete. Binary '{s}' has been generated in current directory.\n", .{dest_path});
    } else {
        const run_cmd = &[_][]const u8{cached_bin_path};
        var child = try std.process.spawn(io, .{
            .argv = run_cmd,
            .stdin = .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
        });
        const term = try child.wait(io);
        if (term != .exited or term.exited != 0) {
            std.process.exit(1);
        }
    }
}
