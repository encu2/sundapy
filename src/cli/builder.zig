const std = @import("std");

pub fn getSundafetchPath(allocator: std.mem.Allocator, io: std.Io) []const u8 {
    const cwd = std.Io.Dir.cwd();
    if (std.process.executableDirPathAlloc(io, allocator)) |exe_dir| {
        defer allocator.free(exe_dir);
        const candidate = std.fmt.allocPrint(allocator, "{s}/sundafetch", .{exe_dir}) catch return "sundafetch";
        if (cwd.access(io, candidate, .{})) |_| {
            return candidate;
        } else |_| {
            allocator.free(candidate);
        }
    } else |_| {}
    if (cwd.access(io, "zig-out/bin/sundafetch", .{})) |_| {
        return "zig-out/bin/sundafetch";
    } else |_| {}
    return "sundafetch";
}

pub fn printHelp() void {
    std.debug.print(
        \\SundaPy - A Python to Zig transpiler and runtime
        \\
        \\Usage: sundapy [options] [command] <script.py>
        \\
        \\Options:
        \\  -h, --help              Show this help message and exit
        \\  --build, build          Build a standalone executable instead of running directly
        \\  -o, --outname <name>    Specify custom output binary name (implies --build)
        \\  --fast, --release-fast  Compile with maximum optimizations (ReleaseFast / -O3)
        \\  --debug                 Compile with runtime safety checks and debug info (ReleaseSafe)
        \\  -y                      Bypass hash cache and force full recompilation
        \\  --no-panic              Disable crash panic logs
        \\
        \\Commands:
        \\  build <script.py>       Build a standalone executable
        \\  init                    Initialize a new SundaPy project with default hierarchy & VSCode helper
        \\  fetch <pkg>             Download and install a package via sundafetch into .cache/pyLibrary
        \\
        \\Examples:
        \\  sundapy init
        \\  sundapy main.py
        \\  sundapy --fast main.py
        \\  sundapy build main.py -o my_binary
        \\  sundapy fetch --build requests
        \\
    , .{});
}

pub fn extractEmbeddedDatatype(allocator: std.mem.Allocator, io: std.Io) void {
    const cwd = std.Io.Dir.cwd();
    const embedded = @import("../embedded_datatype.zig");
    for (embedded.files) |entry| {
        const rel_path = entry[0];
        const data = entry[1];
        const full_path = std.fmt.allocPrint(allocator, ".cache/src/datatype/{s}", .{rel_path}) catch unreachable;
        defer allocator.free(full_path);

        if (std.fs.path.dirname(full_path)) |dir_path| {
            cwd.createDirPath(io, dir_path) catch {};
        }
        cwd.writeFile(io, .{ .sub_path = full_path, .data = data }) catch |write_err| {
            std.debug.print("Failed to write embedded file {s}: {any}\n", .{ full_path, write_err });
        };
    }
}

pub fn buildExecutable(
    allocator: std.mem.Allocator,
    io: std.Io,
    zig_bin: []const u8,
    stem: []const u8,
    cached_bin_path: []const u8,
    is_debug: bool,
    is_release_fast: bool,
    is_no_panic: bool,
) !void {
    const cwd = std.Io.Dir.cwd();

    var entry_content_str = std.ArrayList(u8).empty;
    defer entry_content_str.deinit(allocator);

    const part1 = try std.fmt.allocPrint(allocator, "const std = @import(\"std\");\nconst script = @import(\"{s}.zig\");\n", .{stem});
    defer allocator.free(part1);
    try entry_content_str.appendSlice(allocator, part1);

    if (is_no_panic) {
        try entry_content_str.appendSlice(allocator, "pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn { _=msg; _=error_return_trace; _=ret_addr; while (true) {} }\n");
    }

    try entry_content_str.appendSlice(allocator, "pub fn main() !void {\n    try script.__sundapy_module_init();\n}\n");
    try cwd.writeFile(io, .{ .sub_path = ".cache/src/__entry.zig", .data = entry_content_str.items });

    const emit_bin_arg = try std.fmt.allocPrint(allocator, "-femit-bin={s}", .{cached_bin_path});
    defer allocator.free(emit_bin_arg);

    extractEmbeddedDatatype(allocator, io);

    var zig_cmd = std.ArrayList([]const u8).empty;
    defer zig_cmd.deinit(allocator);

    try zig_cmd.appendSlice(allocator, &[_][]const u8{
        zig_bin,
        "build-exe",
        ".cache/src/__entry.zig",
        "-O",
        if (is_debug) "ReleaseSafe" else if (is_release_fast) "ReleaseFast" else "ReleaseSmall",
    });

    try zig_cmd.appendSlice(allocator, &[_][]const u8{ "-lc", "-I", "." });

    const compiler = @import("../core/compiler.zig");
    for (compiler.global_link_libs.items) |lib| {
        const link_arg = try std.fmt.allocPrint(allocator, "-l{s}", .{lib});
        try zig_cmd.append(allocator, link_arg);
    }
    for (compiler.global_c_source_files.items) |c_file| {
        try zig_cmd.append(allocator, c_file);
        if (std.fs.path.dirname(c_file)) |c_dir| {
            const inc_arg = try std.fmt.allocPrint(allocator, "-I{s}", .{c_dir});
            try zig_cmd.append(allocator, inc_arg);
        }
    }

    if (!is_debug) {
        try zig_cmd.appendSlice(allocator, &[_][]const u8{"-fstrip"});
    }
    try zig_cmd.appendSlice(allocator, &[_][]const u8{
        "--cache-dir",
        ".cache/zig_cache",
        "--global-cache-dir",
        ".cache/zig_global_cache",
        emit_bin_arg,
    });

    const compile_res = try std.process.run(allocator, io, .{
        .argv = zig_cmd.items,
    });

    if (compile_res.term != .exited or compile_res.term.exited != 0) {
        std.debug.print("Compilation failed!\n{s}\n", .{compile_res.stderr});
        std.process.exit(1);
    }

    if (!is_debug) {
        _ = std.process.run(allocator, io, .{
            .argv = &[_][]const u8{ "strip", cached_bin_path },
        }) catch {};
    }
}
