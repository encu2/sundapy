const std = @import("std");
const zip_mod = @import("zip.zig");
const env_mod = @import("env.zig");
const security = @import("security.zig");

fn cleanDirTree(io: std.Io, dir: std.Io.Dir) void {
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind == .directory) {
            if (dir.openDir(io, entry.name, .{ .iterate = true })) |sub_val| {
                var sub = sub_val;
                defer sub.close(io);
                cleanDirTree(io, sub);
            } else |_| {}
            dir.deleteDir(io, entry.name) catch {};
        } else {
            dir.deleteFile(io, entry.name) catch {};
        }
    }
}

fn cleanDir(io: std.Io, dir_path: []const u8) void {
    const cwd = std.Io.Dir.cwd();
    if (cwd.openDir(io, dir_path, .{ .iterate = true })) |dir_val| {
        var dir = dir_val;
        defer dir.close(io);
        cleanDirTree(io, dir);
    } else |_| {}
}

fn buildWheelWithPip(
    allocator: std.mem.Allocator,
    io: std.Io,
    target: []const u8,
    environ_map: ?*const std.process.Environ.Map,
    tmp_wheel_dir: []const u8,
) !?[]const u8 {
    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, tmp_wheel_dir) catch {};
    cleanDir(io, tmp_wheel_dir);

    var resolved_target = target;
    var allocated_target: ?[]const u8 = null;
    defer if (allocated_target) |at| allocator.free(at);

    if (std.mem.startsWith(u8, target, "~/")) {
        const home_opt: ?[]const u8 = if (environ_map) |em| em.get("HOME") else null;
        if (home_opt) |home| {
            allocated_target = std.fmt.allocPrint(allocator, "{s}{s}", .{ home, target[1..] }) catch null;
            if (allocated_target) |at| resolved_target = at;
        }
    }

    var res = std.process.run(allocator, io, .{
        .argv = &[_][]const u8{
            "python3", "-m", "pip", "wheel", "--no-deps", "--no-cache-dir", "--no-build-isolation", "-w", tmp_wheel_dir, resolved_target,
        },
        .environ_map = environ_map,
    }) catch null;

    if (res == null or res.?.term != .exited or res.?.term.exited != 0) {
        if (res) |r| {
            allocator.free(r.stdout);
            allocator.free(r.stderr);
        }
        res = std.process.run(allocator, io, .{
            .argv = &[_][]const u8{
                "python3", "-m", "pip", "wheel", "--no-deps", "--no-cache-dir", "-w", tmp_wheel_dir, resolved_target,
            },
            .environ_map = environ_map,
        }) catch null;
    }

    const final_res = res orelse {
        std.debug.print("  [!] Failed to invoke host Python wheel builder.\n", .{});
        return null;
    };
    defer allocator.free(final_res.stdout);
    defer allocator.free(final_res.stderr);

    if (final_res.term != .exited or final_res.term.exited != 0) {
        std.debug.print("  [!] Host Python failed to build wheel for '{s}'.\n", .{target});
        if (final_res.stderr.len > 0) {
            std.debug.print("  [!] Build stderr: {s}\n", .{final_res.stderr});
        }
        return null;
    }

    var dir = cwd.openDir(io, tmp_wheel_dir, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    var it = dir.iterate();
    var found_whl: ?[]const u8 = null;
    while (it.next(io) catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".whl")) {
            found_whl = try allocator.dupe(u8, entry.name);
            break;
        }
    }

    return found_whl;
}

pub fn buildAndInstallSdist(
    allocator: std.mem.Allocator,
    io: std.Io,
    pkg: []const u8,
    environ_map: ?*const std.process.Environ.Map,
) !bool {
    if (!security.validatePackageName(pkg)) {
        std.debug.print("Error: Invalid or insecure package name: '{s}'\n", .{pkg});
        return false;
    }

    std.debug.print("  [*] No prebuilt wheel found on PyPI for '{s}' (only source distribution available).\n", .{pkg});
    std.debug.print("  [*] Attempting to build wheel via host Python...\n", .{});

    const tmp_wheel_dir = ".cache/pyLibrary/.tmp_wheel";
    const whl_name = (try buildWheelWithPip(allocator, io, pkg, environ_map, tmp_wheel_dir)) orelse return false;
    defer allocator.free(whl_name);

    const whl_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_wheel_dir, whl_name });
    defer allocator.free(whl_path);

    std.debug.print("  [+] Successfully built wheel: {s}\n", .{whl_name});
    std.debug.print("  [+] Extracting {s} into .cache/pyLibrary/...\n", .{whl_name});
    try zip_mod.extractZipFile(io, whl_path, ".cache/pyLibrary");

    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, whl_path) catch {};
    cleanDir(io, tmp_wheel_dir);
    cwd.deleteDir(io, tmp_wheel_dir) catch {};

    return true;
}

pub fn buildAndInstallLocalProject(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    environ_map: ?*const std.process.Environ.Map,
) ![][]const u8 {
    if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null) {
        return error.InvalidLocalProjectPath;
    }

    std.debug.print("==> Installing local project '{s}' into .cache/pyLibrary/...\n", .{path});
    std.debug.print("  [*] Building wheel via host Python...\n", .{});

    const tmp_wheel_dir = ".cache/pyLibrary/.tmp_wheel";
    const whl_name = (try buildWheelWithPip(allocator, io, path, environ_map, tmp_wheel_dir)) orelse {
        return error.LocalProjectBuildFailed;
    };
    defer allocator.free(whl_name);

    const whl_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_wheel_dir, whl_name });
    defer allocator.free(whl_path);

    std.debug.print("  [+] Successfully built wheel: {s}\n", .{whl_name});
    std.debug.print("  [+] Extracting {s} into .cache/pyLibrary/...\n", .{whl_name});
    try zip_mod.extractZipFile(io, whl_path, ".cache/pyLibrary");

    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, whl_path) catch {};
    cleanDir(io, tmp_wheel_dir);
    cwd.deleteDir(io, tmp_wheel_dir) catch {};

    const dist_name = if (std.mem.indexOfScalar(u8, whl_name, '-')) |dash_idx|
        whl_name[0..dash_idx]
    else
        whl_name;

    const has_so = zip_mod.checkExtractedHasSo(allocator, io, ".cache/pyLibrary", dist_name);
    if (has_so) {
        std.debug.print("  [SUNDAPY] Native binary extension (.so) detected in '{s}'.\n", .{dist_name});
    }

    var deps_list = std.ArrayList([]const u8).empty;
    try parseExtractedMetadataDeps(allocator, io, dist_name, &deps_list);

    if (deps_list.items.len > 0) {
        std.debug.print("  [+] Discovered {d} dependencies for '{s}'.\n", .{ deps_list.items.len, dist_name });
    }

    return try deps_list.toOwnedSlice(allocator);
}

pub fn parseExtractedMetadataDeps(
    allocator: std.mem.Allocator,
    io: std.Io,
    pkg: []const u8,
    deps: *std.ArrayList([]const u8),
) !void {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, ".cache/pyLibrary", .{ .iterate = true }) catch return;
    defer dir.close(io);

    var norm_buf: [128]u8 = undefined;
    const norm = if (pkg.len < 128) blk: {
        @memcpy(norm_buf[0..pkg.len], pkg);
        for (norm_buf[0..pkg.len]) |*c| {
            if (c.* == '-' or c.* == '.') c.* = '_';
        }
        break :blk norm_buf[0..pkg.len];
    } else pkg;

    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        const is_dist_info = std.mem.endsWith(u8, entry.name, ".dist-info");
        const is_egg_info = std.mem.endsWith(u8, entry.name, ".egg-info");
        if (!is_dist_info and !is_egg_info) continue;

        if (!env_mod.canonicalMatch(entry.name, norm)) continue;

        if (is_dist_info) {
            const meta_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/METADATA", .{entry.name});
            defer allocator.free(meta_path);
            const content = cwd.readFileAlloc(io, meta_path, allocator, @enumFromInt(2 * 1024 * 1024)) catch continue;
            defer allocator.free(content);

            var line_iter = std.mem.splitScalar(u8, content, '\n');
            while (line_iter.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (std.mem.startsWith(u8, trimmed, "Requires-Dist:")) {
                    const spec = std.mem.trim(u8, trimmed[14..], " \t");
                    if (std.mem.indexOfScalar(u8, spec, ';')) |semi_idx| {
                        const marker = spec[semi_idx + 1 ..];
                        if (!env_mod.isMarkerSupported(marker, "linux")) continue;
                    }
                    if (env_mod.parseRequirementLine(spec)) |dep_name| {
                        try env_mod.appendUnique(allocator, deps, dep_name);
                    }
                }
            }
        } else if (is_egg_info) {
            const req_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/requires.txt", .{entry.name});
            defer allocator.free(req_path);
            const content = cwd.readFileAlloc(io, req_path, allocator, @enumFromInt(2 * 1024 * 1024)) catch continue;
            defer allocator.free(content);

            var line_iter = std.mem.splitScalar(u8, content, '\n');
            var in_extra = false;
            while (line_iter.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (trimmed.len == 0 or trimmed[0] == '#') continue;
                if (trimmed[0] == '[') {
                    if (std.mem.eql(u8, trimmed, "[]")) {
                        in_extra = false;
                    } else {
                        in_extra = true;
                    }
                    continue;
                }
                if (!in_extra) {
                    if (env_mod.parseRequirementLine(trimmed)) |dep_name| {
                        try env_mod.appendUnique(allocator, deps, dep_name);
                    }
                }
            }
        }
    }
}
