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
        \\  sundafetch <path/to/project>
        \\  sundafetch -r <requirements.txt>
        \\  sundafetch <requirements.txt>
        \\
        \\Options:
        \\  -r, --requirement <file>  Install from the given requirements file
        \\  -e, --editable <path>     Install local project from directory path
        \\  -h, --help                Show this help message and exit
        \\
        \\All packages are installed strictly into .cache/pyLibrary/ (isolated from global).
        \\
    , .{});
}


pub fn canonicalMatch(entry_stem: []const u8, norm_pkg: []const u8) bool {
    if (entry_stem.len < norm_pkg.len) return false;
    for (norm_pkg, 0..) |c, i| {
        const e = entry_stem[i];
        const c_norm = if (c == '-' or c == '.') '_' else std.ascii.toLower(c);
        const e_norm = if (e == '-' or e == '.') '_' else std.ascii.toLower(e);
        if (c_norm != e_norm) return false;
    }
    if (entry_stem.len > norm_pkg.len) {
        const next_c = entry_stem[norm_pkg.len];
        if (next_c != '-' and next_c != '_') return false;
    }
    return true;
}

pub fn isMarkerSupported(marker: []const u8, os: []const u8) bool {
    const trimmed = std.mem.trim(u8, marker, " \t\r\n");
    if (trimmed.len == 0) return true;
    if (std.mem.indexOf(u8, trimmed, "extra") != null) return false;

    if (std.mem.eql(u8, os, "linux")) {
        if (std.mem.indexOf(u8, trimmed, "'win32'") != null or
            std.mem.indexOf(u8, trimmed, "\"win32\"") != null or
            std.mem.indexOf(u8, trimmed, "'darwin'") != null or
            std.mem.indexOf(u8, trimmed, "\"darwin\"") != null)
        {
            return false;
        }
    } else if (std.mem.eql(u8, os, "macosx") or std.mem.eql(u8, os, "darwin")) {
        if (std.mem.indexOf(u8, trimmed, "'win32'") != null or
            std.mem.indexOf(u8, trimmed, "\"win32\"") != null or
            std.mem.indexOf(u8, trimmed, "'linux'") != null or
            std.mem.indexOf(u8, trimmed, "\"linux\"") != null)
        {
            return false;
        }
    }
    return true;
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

    if (std.mem.startsWith(u8, s, "-e ")) {
        s = std.mem.trim(u8, s[3..], " \t\r\n");
    } else if (std.mem.startsWith(u8, s, "-e=")) {
        s = std.mem.trim(u8, s[3..], " \t\r\n");
    } else if (std.mem.startsWith(u8, s, "--editable ")) {
        s = std.mem.trim(u8, s[11..], " \t\r\n");
    } else if (std.mem.startsWith(u8, s, "--editable=")) {
        s = std.mem.trim(u8, s[11..], " \t\r\n");
    }

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
    if (std.mem.indexOfScalar(u8, s, '(')) |paren_idx| {
        s = s[0..paren_idx];
    }

    var cut_len: usize = s.len;
    for (s, 0..) |c, i| {
        if (c == '=' or c == '>' or c == '<' or c == '~' or c == '!' or c == ';' or c == '@' or c == '(') {
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

    const dir_part = std.fs.path.dirname(file_path);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |raw_line| {
        const trimmed = std.mem.trim(u8, raw_line, " \t\r\n");
        if (std.mem.startsWith(u8, trimmed, "-r ") or std.mem.startsWith(u8, trimmed, "-r=")) {
            const nested_raw = if (std.mem.startsWith(u8, trimmed, "-r="))
                std.mem.trim(u8, trimmed[3..], " \t")
            else
                std.mem.trim(u8, trimmed[3..], " \t");
            const resolved_path = if (dir_part != null and !std.mem.startsWith(u8, nested_raw, "/"))
                try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_part.?, nested_raw })
            else
                nested_raw;
            try parseRequirementsFile(allocator, io, resolved_path, packages);
        } else if (std.mem.startsWith(u8, trimmed, "--requirement ") or std.mem.startsWith(u8, trimmed, "--requirement=")) {
            const nested_raw = if (std.mem.startsWith(u8, trimmed, "--requirement="))
                std.mem.trim(u8, trimmed[14..], " \t")
            else
                std.mem.trim(u8, trimmed[14..], " \t");
            const resolved_path = if (dir_part != null and !std.mem.startsWith(u8, nested_raw, "/"))
                try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_part.?, nested_raw })
            else
                nested_raw;
            try parseRequirementsFile(allocator, io, resolved_path, packages);
        } else if (std.mem.startsWith(u8, trimmed, "-e ") or std.mem.startsWith(u8, trimmed, "-e=")) {
            const nested = if (std.mem.startsWith(u8, trimmed, "-e="))
                std.mem.trim(u8, trimmed[3..], " \t")
            else
                std.mem.trim(u8, trimmed[3..], " \t");
            const resolved_path = if (dir_part != null and (std.mem.startsWith(u8, nested, "./") or std.mem.startsWith(u8, nested, "../") or std.mem.eql(u8, nested, ".")))
                try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_part.?, nested })
            else
                nested;
            try appendUnique(allocator, packages, resolved_path);
        } else if (std.mem.startsWith(u8, trimmed, "--editable ") or std.mem.startsWith(u8, trimmed, "--editable=")) {
            const nested = if (std.mem.startsWith(u8, trimmed, "--editable="))
                std.mem.trim(u8, trimmed[11..], " \t")
            else
                std.mem.trim(u8, trimmed[11..], " \t");
            const resolved_path = if (dir_part != null and (std.mem.startsWith(u8, nested, "./") or std.mem.startsWith(u8, nested, "../") or std.mem.eql(u8, nested, ".")))
                try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_part.?, nested })
            else
                nested;
            try appendUnique(allocator, packages, resolved_path);
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

pub fn isLocalProjectPath(io: std.Io, path: []const u8) bool {
    const trimmed = std.mem.trim(u8, path, " \t\r\n");
    if (trimmed.len == 0) return false;
    if (std.mem.eql(u8, trimmed, ".") or std.mem.eql(u8, trimmed, "..")) return true;
    if (std.mem.startsWith(u8, trimmed, "./") or
        std.mem.startsWith(u8, trimmed, "../") or
        std.mem.startsWith(u8, trimmed, "/") or
        std.mem.startsWith(u8, trimmed, "~/") or
        std.mem.eql(u8, trimmed, "~"))
    {
        return true;
    }
    if (std.mem.indexOfScalar(u8, trimmed, '/') != null or
        std.mem.indexOfScalar(u8, trimmed, '\\') != null)
    {
        return true;
    }
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, trimmed, .{}) catch return false;
    defer dir.close(io);
    if (dir.access(io, "pyproject.toml", .{})) |_| return true else |_| {}
    if (dir.access(io, "setup.py", .{})) |_| return true else |_| {}
    if (dir.access(io, "setup.cfg", .{})) |_| return true else |_| {}
    return false;
}

pub fn isPackageInstalled(io: std.Io, pkg: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, ".cache/pyLibrary", .{ .iterate = true }) catch return false;
    defer dir.close(io);

    var norm_buf: [128]u8 = undefined;
    const norm = if (pkg.len < 128) blk: {
        @memcpy(norm_buf[0..pkg.len], pkg);
        for (norm_buf[0..pkg.len]) |*c| {
            if (c.* == '-' or c.* == '.') c.* = '_';
        }
        break :blk norm_buf[0..pkg.len];
    } else pkg;

    var check1_buf: [256]u8 = undefined;
    const p1 = std.fmt.bufPrint(&check1_buf, "{s}", .{norm}) catch return false;
    if (dir.access(io, p1, .{})) |_| return true else |_| {}

    var check2_buf: [256]u8 = undefined;
    const p2 = std.fmt.bufPrint(&check2_buf, "{s}.py", .{norm}) catch return false;
    if (dir.access(io, p2, .{})) |_| return true else |_| {}

    var lower_buf: [128]u8 = undefined;
    const lower_norm = if (norm.len < 128) blk: {
        for (norm, 0..) |c, i| {
            lower_buf[i] = std.ascii.toLower(c);
        }
        break :blk lower_buf[0..norm.len];
    } else norm;

    if (!std.mem.eql(u8, norm, lower_norm)) {
        var check3_buf: [256]u8 = undefined;
        const p3 = std.fmt.bufPrint(&check3_buf, "{s}", .{lower_norm}) catch return false;
        if (dir.access(io, p3, .{})) |_| return true else |_| {}

        var check4_buf: [256]u8 = undefined;
        const p4 = std.fmt.bufPrint(&check4_buf, "{s}.py", .{lower_norm}) catch return false;
        if (dir.access(io, p4, .{})) |_| return true else |_| {}
    }

    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind == .directory) {
            const is_dist_info = std.mem.endsWith(u8, entry.name, ".dist-info");
            const is_egg_info = std.mem.endsWith(u8, entry.name, ".egg-info");
            if (is_dist_info or is_egg_info) {
                if (canonicalMatch(entry.name, norm)) {
                    return true;
                }
            }
        }
    }

    return false;
}


