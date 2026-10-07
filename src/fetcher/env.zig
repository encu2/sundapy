const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const TargetEnv = types.TargetEnv;

pub fn printHelp() void {
    std.debug.print(
        \\sundafetch - High-performance zero-dependency PyPI package fetcher & installer
        \\
        \\Usage:
        \\  sundafetch <package> [<package2> ...]
        \\  sundafetch -r <requirements.txt>
        \\  sundafetch <requirements.txt>
        \\
        \\Options:
        \\  -r, --requirement <file>  Install from the given requirements file
        \\  -h, --help                Show this help message and exit
        \\
        \\All packages are installed strictly into .cache/pyLibrary/ (isolated from global).
        \\
    , .{});
}

pub fn canonicalPkgName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const result = try allocator.dupe(u8, name);
    for (result) |*c| {
        if (c.* == '_' or c.* == '.') {
            c.* = '-';
        } else {
            c.* = std.ascii.toLower(c.*);
        }
    }
    return result;
}

pub fn appendUnique(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), item: []const u8) !void {
    for (list.items) |existing| {
        if (std.ascii.eqlIgnoreCase(existing, item)) return;
    }
    try list.append(allocator, try allocator.dupe(u8, item));
}

pub fn parseRequirementLine(line: []const u8) ?[]const u8 {
    var s = std.mem.trim(u8, line, " \t\r\n");
    if (s.len == 0 or s[0] == '#') return null;

    if (std.mem.indexOfScalar(u8, s, '#')) |idx| {
        s = std.mem.trim(u8, s[0..idx], " \t\r\n");
    }
    if (s.len == 0) return null;

    if (std.mem.startsWith(u8, s, "-i ") or
        std.mem.startsWith(u8, s, "--index-url") or
        std.mem.startsWith(u8, s, "--extra-index-url") or
        std.mem.startsWith(u8, s, "-f ") or
        std.mem.startsWith(u8, s, "--find-links"))
    {
        return null;
    }

    if (std.mem.indexOfScalar(u8, s, '[')) |bracket_idx| {
        s = s[0..bracket_idx];
    }

    var cut_len: usize = s.len;
    for (s, 0..) |c, i| {
        if (c == '=' or c == '>' or c == '<' or c == '~' or c == '!' or c == ';' or c == '@') {
            cut_len = i;
            break;
        }
    }
    s = std.mem.trim(u8, s[0..cut_len], " \t\r\n");
    if (s.len == 0) return null;
    return s;
}

pub fn parseRequirementsFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, packages: *std.ArrayList([]const u8)) !void {
    const cwd = std.Io.Dir.cwd();
    const content = cwd.readFileAlloc(io, file_path, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Failed to read requirements file '{s}': {any}\n", .{ file_path, err });
        return err;
    };
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |raw_line| {
        const trimmed = std.mem.trim(u8, raw_line, " \t\r\n");
        if (std.mem.startsWith(u8, trimmed, "-r ")) {
            const nested = std.mem.trim(u8, trimmed[3..], " \t");
            try parseRequirementsFile(allocator, io, nested, packages);
        } else if (std.mem.startsWith(u8, trimmed, "--requirement ")) {
            const nested = std.mem.trim(u8, trimmed[14..], " \t");
            try parseRequirementsFile(allocator, io, nested, packages);
        } else if (parseRequirementLine(raw_line)) |pkg_name| {
            try appendUnique(allocator, packages, pkg_name);
        }
    }
}

pub fn detectTargetEnv(allocator: std.mem.Allocator, io: std.Io) TargetEnv {
    var default_env = TargetEnv{
        .py_tag = "cp314",
        .abi_tag = "cp314",
        .py_ver_num = 314,
        .is_free_threaded = false,
        .arch = if (builtin.cpu.arch == .aarch64) "aarch64" else "x86_64",
        .os = if (builtin.os.tag == .macos) "macosx" else "linux",
    };

    const py_res = std.process.run(allocator, io, .{
        .argv = &[_][]const u8{
            "python3", "-c", "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}', sys.abiflags)",
        },
    }) catch null;

    if (py_res) |res| {
        if (res.term == .exited and res.term.exited == 0) {
            var parts = std.mem.tokenizeAny(u8, res.stdout, " \t\r\n");
            if (parts.next()) |ver_str| {
                if (std.fmt.parseInt(u32, ver_str, 10)) |v| {
                    default_env.py_ver_num = v;
                    default_env.py_tag = std.fmt.allocPrint(allocator, "cp{d}", .{v}) catch "cp314";
                    var is_t = false;
                    if (parts.next()) |flags| {
                        if (std.mem.indexOfScalar(u8, flags, 't') != null) {
                            is_t = true;
                        }
                    }
                    default_env.is_free_threaded = is_t;
                    default_env.abi_tag = if (is_t)
                        (std.fmt.allocPrint(allocator, "cp{d}t", .{v}) catch "cp314t")
                    else
                        default_env.py_tag;
                } else |_| {}
            }
        }
    }
    return default_env;
}

pub fn isPackageInstalled(io: std.Io, pkg: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, ".cache/pyLibrary", .{ .iterate = true }) catch return false;
    defer dir.close(io);

    var norm_buf: [128]u8 = undefined;
    const norm = if (pkg.len < 128) blk: {
        @memcpy(norm_buf[0..pkg.len], pkg);
        for (norm_buf[0..pkg.len]) |*c| {
            if (c.* == '-') c.* = '_';
        }
        break :blk norm_buf[0..pkg.len];
    } else pkg;

    var check1_buf: [256]u8 = undefined;
    const p1 = std.fmt.bufPrint(&check1_buf, "{s}", .{norm}) catch return false;
    if (dir.access(io, p1, .{})) |_| return true else |_| {}

    var check2_buf: [256]u8 = undefined;
    const p2 = std.fmt.bufPrint(&check2_buf, "{s}.py", .{norm}) catch return false;
    if (dir.access(io, p2, .{})) |_| return true else |_| {}

    return false;
}
