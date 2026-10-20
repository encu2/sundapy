const std = @import("std");
const env_mod = @import("env.zig");
const detect_dist = @import("detect_dist.zig");

pub const EntryPoint = detect_dist.EntryPoint;
pub const detectDistInfo = detect_dist.detectDistInfo;
pub const detectProjectName = detect_dist.detectProjectName;

pub fn detectPyproject(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8, preferred_bin: ?[]const u8) !?EntryPoint {
    const cwd = std.Io.Dir.cwd();
    const toml_path = try std.fmt.allocPrint(allocator, "{s}/pyproject.toml", .{dir_path});
    defer allocator.free(toml_path);

    const content = cwd.readFileAlloc(io, toml_path, allocator, @enumFromInt(2 * 1024 * 1024)) catch return null;
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var in_scripts = false;
    var first_entry: ?EntryPoint = null;

    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[') {
            in_scripts = std.mem.eql(u8, line, "[project.scripts]") or
                std.mem.eql(u8, line, "[project.gui-scripts]") or
                std.mem.eql(u8, line, "[tool.poetry.scripts]") or
                std.mem.eql(u8, line, "[tool.flit.scripts]");
            continue;
        }

        if (in_scripts) {
            if (std.mem.indexOfScalar(u8, line, '=')) |eq_idx| {
                const raw_bin = std.mem.trim(u8, line[0..eq_idx], " \t\"'");
                const raw_target = std.mem.trim(u8, line[eq_idx + 1 ..], " \t\"'");
                if (raw_bin.len == 0 or raw_target.len == 0) continue;

                var mod_path: []const u8 = raw_target;
                var callable: ?[]const u8 = null;
                if (std.mem.indexOfScalar(u8, raw_target, ':')) |colon_idx| {
                    mod_path = std.mem.trim(u8, raw_target[0..colon_idx], " \t\"'");
                    var raw_c = std.mem.trim(u8, raw_target[colon_idx + 1 ..], " \t\"'");
                    if (std.mem.endsWith(u8, raw_c, "()")) raw_c = raw_c[0 .. raw_c.len - 2];
                    if (raw_c.len > 0) callable = allocator.dupe(u8, raw_c) catch null;
                }

                const bin_name = allocator.dupe(u8, raw_bin) catch continue;
                const mod_dup = allocator.dupe(u8, mod_path) catch continue;

                const entry = EntryPoint{
                    .bin_name = bin_name,
                    .module_path = mod_dup,
                    .callable = callable,
                    .direct_script = null,
                };
                if (preferred_bin) |pb| {
                    const pb_base = std.fs.path.basename(pb);
                    if (std.ascii.eqlIgnoreCase(raw_bin, pb) or std.ascii.eqlIgnoreCase(raw_bin, pb_base)) return entry;
                }
                if (first_entry == null) first_entry = entry;
            }
        }
    }
    return first_entry;
}

pub fn detectSetupCfg(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8, preferred_bin: ?[]const u8) !?EntryPoint {
    const cwd = std.Io.Dir.cwd();
    const cfg_path = try std.fmt.allocPrint(allocator, "{s}/setup.cfg", .{dir_path});
    defer allocator.free(cfg_path);

    const content = cwd.readFileAlloc(io, cfg_path, allocator, @enumFromInt(2 * 1024 * 1024)) catch return null;
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var in_ep = false;
    var in_console = false;
    var first_entry: ?EntryPoint = null;

    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[') {
            in_ep = std.mem.eql(u8, line, "[options.entry_points]") or std.mem.eql(u8, line, "[entry_points]");
            in_console = false;
            continue;
        }

        if (in_ep) {
            if (std.mem.startsWith(u8, line, "console_scripts") or std.mem.startsWith(u8, line, "gui_scripts")) {
                in_console = true;
                continue;
            }
            if (in_console) {
                if (std.mem.indexOfScalar(u8, line, '=')) |eq_idx| {
                    const raw_bin = std.mem.trim(u8, line[0..eq_idx], " \t\"'");
                    const raw_target = std.mem.trim(u8, line[eq_idx + 1 ..], " \t\"'");
                    if (raw_bin.len == 0 or raw_target.len == 0) continue;

                    var mod_path: []const u8 = raw_target;
                    var callable: ?[]const u8 = null;
                    if (std.mem.indexOfScalar(u8, raw_target, ':')) |colon_idx| {
                        mod_path = std.mem.trim(u8, raw_target[0..colon_idx], " \t\"'");
                        var raw_c = std.mem.trim(u8, raw_target[colon_idx + 1 ..], " \t\"'");
                        if (std.mem.endsWith(u8, raw_c, "()")) raw_c = raw_c[0 .. raw_c.len - 2];
                        if (raw_c.len > 0) callable = allocator.dupe(u8, raw_c) catch null;
                    }

                    const bin_name = allocator.dupe(u8, raw_bin) catch continue;
                    const mod_dup = allocator.dupe(u8, mod_path) catch continue;
                    const entry = EntryPoint{
                        .bin_name = bin_name,
                        .module_path = mod_dup,
                        .callable = callable,
                        .direct_script = null,
                    };
                    if (preferred_bin) |pb| {
                        const pb_base = std.fs.path.basename(pb);
                        if (std.ascii.eqlIgnoreCase(raw_bin, pb) or std.ascii.eqlIgnoreCase(raw_bin, pb_base)) return entry;
                    }
                    if (first_entry == null) first_entry = entry;
                }
            }
        }
    }
    return first_entry;
}

pub fn detectSetupPy(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8, preferred_bin: ?[]const u8) !?EntryPoint {
    const cwd = std.Io.Dir.cwd();
    const setup_path = try std.fmt.allocPrint(allocator, "{s}/setup.py", .{dir_path});
    defer allocator.free(setup_path);

    const content = cwd.readFileAlloc(io, setup_path, allocator, @enumFromInt(2 * 1024 * 1024)) catch return null;
    defer allocator.free(content);

    var cursor: usize = 0;
    while (cursor < content.len) {
        const quote_char: u8 = blk: {
            const single = std.mem.indexOfScalarPos(u8, content, cursor, '\'');
            const double = std.mem.indexOfScalarPos(u8, content, cursor, '"');
            if (single == null and double == null) return null;
            if (single != null and double != null) {
                if (single.? < double.?) {
                    cursor = single.?;
                    break :blk '\'';
                } else {
                    cursor = double.?;
                    break :blk '"';
                }
            } else if (single != null) {
                cursor = single.?;
                break :blk '\'';
            } else {
                cursor = double.?;
                break :blk '"';
            }
        };

        const end_quote = std.mem.indexOfScalarPos(u8, content, cursor + 1, quote_char) orelse break;
        const candidate = content[cursor + 1 .. end_quote];
        cursor = end_quote + 1;

        if (std.mem.indexOfScalar(u8, candidate, '=') != null and std.mem.indexOfScalar(u8, candidate, ':') != null) {
            const eq_idx = std.mem.indexOfScalar(u8, candidate, '=').?;
            const colon_idx = std.mem.indexOfScalar(u8, candidate, ':').?;
            if (colon_idx > eq_idx) {
                const raw_bin = std.mem.trim(u8, candidate[0..eq_idx], " \t");
                const mod_path = std.mem.trim(u8, candidate[eq_idx + 1 .. colon_idx], " \t");
                var raw_c = std.mem.trim(u8, candidate[colon_idx + 1 ..], " \t");
                if (std.mem.endsWith(u8, raw_c, "()")) raw_c = raw_c[0 .. raw_c.len - 2];
                if (raw_bin.len > 0 and mod_path.len > 0) {
                    const bin_name = allocator.dupe(u8, raw_bin) catch continue;
                    const mod_dup = allocator.dupe(u8, mod_path) catch continue;
                    const callable = if (raw_c.len > 0) allocator.dupe(u8, raw_c) catch null else null;
                    const entry = EntryPoint{
                        .bin_name = bin_name,
                        .module_path = mod_dup,
                        .callable = callable,
                        .direct_script = null,
                    };
                    if (preferred_bin) |pb| {
                        const pb_base = std.fs.path.basename(pb);
                        if (std.ascii.eqlIgnoreCase(raw_bin, pb) or std.ascii.eqlIgnoreCase(raw_bin, pb_base)) return entry;
                    }
                    return entry;
                }
            }
        }
    }
    return null;
}

pub fn detectMainPyOrTopScript(
    allocator: std.mem.Allocator,
    io: std.Io,
    target: []const u8,
    pkg_norm: []const u8,
    preferred_bin: ?[]const u8,
) !?EntryPoint {
    const cwd = std.Io.Dir.cwd();
    const is_dir = env_mod.isLocalDirectory(io, target);

    if (std.mem.endsWith(u8, target, ".py") and (cwd.access(io, target, .{}) catch null) != null) {
        const basename = std.fs.path.basename(target);
        const stem = if (std.mem.lastIndexOfScalar(u8, basename, '.')) |i| basename[0..i] else basename;
        return EntryPoint{
            .bin_name = preferred_bin orelse try allocator.dupe(u8, stem),
            .module_path = stem,
            .callable = null,
            .direct_script = target,
        };
    }

    if (is_dir) {
        const candidates = [_][]const u8{
            try std.fmt.allocPrint(allocator, "{s}/__main__.py", .{target}),
            try std.fmt.allocPrint(allocator, "{s}/{s}/__main__.py", .{ target, pkg_norm }),
            try std.fmt.allocPrint(allocator, "{s}/src/{s}/__main__.py", .{ target, pkg_norm }),
            try std.fmt.allocPrint(allocator, "{s}/main.py", .{target}),
            try std.fmt.allocPrint(allocator, "{s}/app.py", .{target}),
            try std.fmt.allocPrint(allocator, "{s}/cli.py", .{target}),
            try std.fmt.allocPrint(allocator, "{s}/run.py", .{target}),
            try std.fmt.allocPrint(allocator, "{s}/{s}.py", .{ target, pkg_norm }),
        };
        for (candidates) |c| {
            defer allocator.free(c);
            if (cwd.access(io, c, .{})) |_| {
                if (std.mem.endsWith(u8, c, "__main__.py")) {
                    return EntryPoint{
                        .bin_name = preferred_bin orelse try allocator.dupe(u8, pkg_norm),
                        .module_path = try std.fmt.allocPrint(allocator, "{s}.__main__", .{pkg_norm}),
                        .callable = null,
                        .direct_script = null,
                    };
                } else {
                    return EntryPoint{
                        .bin_name = preferred_bin orelse try allocator.dupe(u8, pkg_norm),
                        .module_path = pkg_norm,
                        .callable = null,
                        .direct_script = try allocator.dupe(u8, c),
                    };
                }
            } else |_| {}
        }
    }

    const cache_main = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/__main__.py", .{pkg_norm});
    defer allocator.free(cache_main);
    if (cwd.access(io, cache_main, .{})) |_| {
        return EntryPoint{
            .bin_name = preferred_bin orelse try allocator.dupe(u8, pkg_norm),
            .module_path = try std.fmt.allocPrint(allocator, "{s}.__main__", .{pkg_norm}),
            .callable = null,
            .direct_script = null,
        };
    } else |_| {}

    const cache_py = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.py", .{pkg_norm});
    defer allocator.free(cache_py);
    if (cwd.access(io, cache_py, .{})) |_| {
        return EntryPoint{
            .bin_name = preferred_bin orelse try allocator.dupe(u8, pkg_norm),
            .module_path = pkg_norm,
            .callable = null,
            .direct_script = try allocator.dupe(u8, cache_py),
        };
    } else |_| {}

    return null;
}

pub fn detectEntryPoint(
    allocator: std.mem.Allocator,
    io: std.Io,
    target: []const u8,
    preferred_bin: ?[]const u8,
    environ_map: ?*const std.process.Environ.Map,
) !EntryPoint {
    const is_dir = env_mod.isLocalDirectory(io, target);
    const target_stem = if (is_dir) blk: {
        if (detectProjectName(allocator, io, target)) |pname| {
            break :blk pname;
        }
        if (std.mem.eql(u8, target, ".") or std.mem.eql(u8, target, "./")) {
            const pwd_opt = if (environ_map) |em| em.get("PWD") else null;
            if (pwd_opt) |pwd| {
                break :blk try allocator.dupe(u8, std.fs.path.basename(pwd));
            } else {
                break :blk try allocator.dupe(u8, "app");
            }
        }
        break :blk try allocator.dupe(u8, std.fs.path.basename(target));
    } else try allocator.dupe(u8, target);

    const pkg_norm = try env_mod.canonicalPkgName(allocator, target_stem);
    const mod_norm = try allocator.dupe(u8, pkg_norm);
    for (mod_norm) |*c| {
        if (c.* == '-') c.* = '_';
    }

    if (try detectDistInfo(allocator, io, mod_norm, preferred_bin)) |ep| return ep;
    if (try detectDistInfo(allocator, io, pkg_norm, preferred_bin)) |ep| return ep;

    if (is_dir) {
        if (try detectPyproject(allocator, io, target, preferred_bin)) |ep| return ep;
        if (try detectSetupCfg(allocator, io, target, preferred_bin)) |ep| return ep;
        if (try detectSetupPy(allocator, io, target, preferred_bin)) |ep| return ep;
    }

    if (try detectMainPyOrTopScript(allocator, io, target, mod_norm, preferred_bin)) |ep| return ep;

    return EntryPoint{
        .bin_name = preferred_bin orelse target_stem,
        .module_path = mod_norm,
        .callable = "main",
        .direct_script = null,
    };
}
