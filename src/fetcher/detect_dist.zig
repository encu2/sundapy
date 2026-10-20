const std = @import("std");
const env_mod = @import("env.zig");

pub const EntryPoint = struct {
    bin_name: []const u8,
    module_path: []const u8,
    callable: ?[]const u8,
    direct_script: ?[]const u8,
};

pub fn parseEntryPointsFile(allocator: std.mem.Allocator, content: []const u8, preferred_bin: ?[]const u8) ?EntryPoint {
    var line_iter = std.mem.splitScalar(u8, content, '\n');
    var in_scripts = false;
    var first_entry: ?EntryPoint = null;

    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[') {
            in_scripts = std.mem.eql(u8, line, "[console_scripts]") or std.mem.eql(u8, line, "[gui_scripts]");
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
                    if (std.mem.endsWith(u8, raw_c, "()")) {
                        raw_c = raw_c[0 .. raw_c.len - 2];
                    }
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

pub fn detectDistInfo(allocator: std.mem.Allocator, io: std.Io, pkg_norm: []const u8, preferred_bin: ?[]const u8) !?EntryPoint {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, ".cache/pyLibrary", .{ .iterate = true }) catch return null;
    defer dir.close(io);

    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (!std.mem.endsWith(u8, entry.name, ".dist-info") and !std.mem.endsWith(u8, entry.name, ".egg-info")) continue;
        if (!env_mod.canonicalMatch(entry.name, pkg_norm)) continue;

        const ep_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}/entry_points.txt", .{entry.name});
        defer allocator.free(ep_path);

        const content = cwd.readFileAlloc(io, ep_path, allocator, @enumFromInt(1024 * 1024)) catch continue;
        defer allocator.free(content);

        if (parseEntryPointsFile(allocator, content, preferred_bin)) |ep| {
            return ep;
        }
    }
    return null;
}

pub fn detectProjectName(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) ?[]const u8 {
    const cwd = std.Io.Dir.cwd();
    const toml_path = std.fmt.allocPrint(allocator, "{s}/pyproject.toml", .{dir_path}) catch null;
    if (toml_path) |tp| {
        defer allocator.free(tp);
        if (cwd.readFileAlloc(io, tp, allocator, @enumFromInt(512 * 1024))) |content| {
            defer allocator.free(content);
            var it = std.mem.splitScalar(u8, content, '\n');
            var in_name_section = false;
            while (it.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, " \t\r\n");
                if (std.mem.eql(u8, line, "[project]") or
                    std.mem.eql(u8, line, "[tool.poetry]") or
                    std.mem.eql(u8, line, "[tool.flit.metadata]"))
                {
                    in_name_section = true;
                    continue;
                }
                if (line.len > 0 and line[0] == '[') in_name_section = false;
                if (in_name_section and std.mem.startsWith(u8, line, "name")) {
                    if (std.mem.indexOfScalar(u8, line, '=')) |eq| {
                        const name = std.mem.trim(u8, line[eq + 1 ..], " \t\"'");
                        if (name.len > 0) return allocator.dupe(u8, name) catch null;
                    }
                }
            }
        } else |_| {}
    }

    const cfg_path = std.fmt.allocPrint(allocator, "{s}/setup.cfg", .{dir_path}) catch null;
    if (cfg_path) |cp| {
        defer allocator.free(cp);
        if (cwd.readFileAlloc(io, cp, allocator, @enumFromInt(512 * 1024))) |content| {
            defer allocator.free(content);
            var it = std.mem.splitScalar(u8, content, '\n');
            var in_meta = false;
            while (it.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, " \t\r\n");
                if (std.mem.eql(u8, line, "[metadata]")) {
                    in_meta = true;
                    continue;
                }
                if (line.len > 0 and line[0] == '[') in_meta = false;
                if (in_meta and std.mem.startsWith(u8, line, "name")) {
                    if (std.mem.indexOfScalar(u8, line, '=')) |eq| {
                        const name = std.mem.trim(u8, line[eq + 1 ..], " \t\"'");
                        if (name.len > 0) return allocator.dupe(u8, name) catch null;
                    }
                }
            }
        } else |_| {}
    }

    const py_path = std.fmt.allocPrint(allocator, "{s}/setup.py", .{dir_path}) catch null;
    if (py_path) |pp| {
        defer allocator.free(pp);
        if (cwd.readFileAlloc(io, pp, allocator, @enumFromInt(512 * 1024))) |content| {
            defer allocator.free(content);
            var it = std.mem.splitScalar(u8, content, '\n');
            while (it.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, " \t\r\n");
                if (std.mem.startsWith(u8, line, "name")) {
                    if (std.mem.indexOfScalar(u8, line, '=')) |eq| {
                        const name = std.mem.trim(u8, line[eq + 1 ..], " \t\"',");
                        if (name.len > 0 and !std.mem.containsAtLeast(u8, name, 1, " ")) {
                            return allocator.dupe(u8, name) catch null;
                        }
                    }
                }
            }
        } else |_| {}
    }
    return null;
}
