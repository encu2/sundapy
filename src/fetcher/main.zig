const std = @import("std");
const types = @import("types.zig");
const env_mod = @import("env.zig");
const installer = @import("installer.zig");
const sdist_mod = @import("sdist.zig");

pub fn main(ctx: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var args_iter = try std.process.Args.Iterator.initAllocator(ctx.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.next();

    var raw_packages = std.ArrayList([]const u8).empty;
    defer raw_packages.deinit(allocator);

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            env_mod.printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--requirement")) {
            if (args_iter.next()) |req_file| {
                try env_mod.parseRequirementsFile(allocator, io, req_file, &raw_packages);
            } else {
                std.debug.print("Error: -r/--requirement requires a file path\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.startsWith(u8, arg, "-r=") or std.mem.startsWith(u8, arg, "--requirement=")) {
            const req_file = if (std.mem.startsWith(u8, arg, "-r=")) arg[3..] else arg["--requirement=".len..];
            try env_mod.parseRequirementsFile(allocator, io, req_file, &raw_packages);
        } else if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--editable")) {
            if (args_iter.next()) |editable_path| {
                try env_mod.appendUnique(allocator, &raw_packages, editable_path);
            } else {
                std.debug.print("Error: -e/--editable requires a path\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.startsWith(u8, arg, "-e=") or std.mem.startsWith(u8, arg, "--editable=")) {
            const editable_path = if (std.mem.startsWith(u8, arg, "-e=")) arg[3..] else arg["--editable=".len..];
            try env_mod.appendUnique(allocator, &raw_packages, editable_path);
        } else if (std.mem.endsWith(u8, arg, ".txt")) {
            try env_mod.parseRequirementsFile(allocator, io, arg, &raw_packages);
        } else if (std.mem.startsWith(u8, arg, "-")) {
            // Ignore other flags
        } else {
            if (env_mod.isLocalProjectPath(io, arg)) {
                try env_mod.appendUnique(allocator, &raw_packages, arg);
            } else if (env_mod.parseRequirementLine(arg)) |pkg_name| {
                try env_mod.appendUnique(allocator, &raw_packages, pkg_name);
            }
        }
    }

    if (raw_packages.items.len == 0) {
        env_mod.printHelp();
        std.process.exit(1);
    }

    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, ".cache/pyLibrary") catch {};

    var target_env = env_mod.detectTargetEnv(allocator, io);
    target_env.environ_map = ctx.environ_map;
    std.debug.print("[sundafetch] Target: {s}-{s} on {s}/{s} (Python {})\n", .{
        target_env.py_tag,
        target_env.abi_tag,
        target_env.os,
        target_env.arch,
        target_env.py_ver_num,
    });

    var bundle = std.crypto.Certificate.Bundle.empty;
    try bundle.rescan(allocator, io, std.Io.Clock.real.now(io));
    defer bundle.deinit(allocator);

    var visited_map = std.StringHashMap(bool).init(allocator);
    defer visited_map.deinit();

    var queue = std.ArrayList([]const u8).empty;
    defer queue.deinit(allocator);

    for (raw_packages.items) |pkg| {
        const canonical = if (env_mod.isLocalProjectPath(io, pkg))
            try allocator.dupe(u8, pkg)
        else
            try env_mod.canonicalPkgName(allocator, pkg);
        if (!visited_map.contains(canonical)) {
            try visited_map.put(canonical, true);
            try queue.append(allocator, canonical);
        }
    }

    var idx: usize = 0;
    while (idx < queue.items.len) : (idx += 1) {
        const pkg = queue.items[idx];
        const new_deps = if (env_mod.isLocalProjectPath(io, pkg)) blk: {
            break :blk try sdist_mod.buildAndInstallLocalProject(allocator, io, pkg, target_env.environ_map);
        } else blk: {
            break :blk try installer.fetchAndInstallPackage(allocator, io, &bundle, pkg, target_env);
        };
        for (new_deps) |dep| {
            const canonical_dep = try env_mod.canonicalPkgName(allocator, dep);
            if (!visited_map.contains(canonical_dep) and !env_mod.isPackageInstalled(io, canonical_dep)) {
                try visited_map.put(canonical_dep, true);
                try queue.append(allocator, canonical_dep);
            }
        }
    }

    std.debug.print("\n[sundafetch] All packages installed into .cache/pyLibrary successfully.\n", .{});
}
