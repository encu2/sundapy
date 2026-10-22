const std = @import("std");
const env_mod = @import("env.zig");
const detect_entry = @import("detect_entry.zig");
const security = @import("security.zig");

pub const EntryPoint = detect_entry.EntryPoint;
pub const detectEntryPoint = detect_entry.detectEntryPoint;

pub fn getSundapyPath(allocator: std.mem.Allocator, io: std.Io, environ_map: ?*const std.process.Environ.Map) []const u8 {
    const cwd = std.Io.Dir.cwd();
    if (std.process.executableDirPathAlloc(io, allocator)) |exe_dir| {
        defer allocator.free(exe_dir);
        const candidate = std.fmt.allocPrint(allocator, "{s}/sundapy", .{exe_dir}) catch return "sundapy";
        if (cwd.access(io, candidate, .{})) |_| {
            return candidate;
        } else |_| {
            allocator.free(candidate);
        }
    } else |_| {}
    if (cwd.access(io, "zig-out/bin/sundapy", .{})) |_| {
        return "zig-out/bin/sundapy";
    } else |_| {}
    const home_opt = if (environ_map) |em| em.get("HOME") else null;
    if (home_opt) |home| {
        const local_cand = std.fmt.allocPrint(allocator, "{s}/.local/bin/sundapy", .{home}) catch return "sundapy";
        if (cwd.access(io, local_cand, .{})) |_| {
            return local_cand;
        } else |_| {
            allocator.free(local_cand);
        }
    }
    return "sundapy";
}

pub fn generateAndBuild(
    allocator: std.mem.Allocator,
    io: std.Io,
    target: []const u8,
    out_name: ?[]const u8,
    environ_map: ?*const std.process.Environ.Map,
) !void {
    const entry = try detectEntryPoint(allocator, io, target, out_name, environ_map);
    const final_bin = out_name orelse entry.bin_name;

    std.debug.print("\n[sundafetch] Detected entrypoint for '{s}':\n", .{target});
    std.debug.print("  - Binary name: {s}\n", .{final_bin});
    std.debug.print("  - Module:      {s}\n", .{entry.module_path});
    if (entry.callable) |c| {
        std.debug.print("  - Callable:    {s}\n", .{c});
    }
    if (entry.direct_script) |s| {
        std.debug.print("  - Script file: {s}\n", .{s});
    }

    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, ".cache/src") catch {};

    if (std.fs.path.dirname(final_bin)) |pdir| {
        cwd.createDirPath(io, pdir) catch {};
    }

    const script_to_build: []const u8 = blk: {
        if (entry.direct_script) |ds| {
            break :blk ds;
        } else {
            if (!security.validateIdentifier(entry.module_path)) {
                std.debug.print("Error: Invalid or suspicious module path in entrypoint: '{s}'\n", .{entry.module_path});
                return error.InvalidModuleIdentifier;
            }
            if (entry.callable) |call_fn| {
                if (!security.validateIdentifier(call_fn)) {
                    std.debug.print("Error: Invalid or suspicious callable identifier in entrypoint: '{s}'\n", .{call_fn});
                    return error.InvalidCallableIdentifier;
                }
            }

            const safe_stem = std.fs.path.basename(final_bin);
            const wrapper_path = try std.fmt.allocPrint(allocator, ".cache/entrypoint_{s}.py", .{safe_stem});
            const wrapper_code = if (entry.callable) |call_fn|
                try std.fmt.allocPrint(
                    allocator,
                    \\import {s} as _app
                    \\
                    \\if __name__ == '__main__':
                    \\    _app.{s}()
                    \\
                ,
                    .{ entry.module_path, call_fn },
                )
            else
                try std.fmt.allocPrint(
                    allocator,
                    \\import {s} as _app
                    \\
                ,
                    .{ entry.module_path },
                );

            try cwd.writeFile(io, .{ .sub_path = wrapper_path, .data = wrapper_code });
            break :blk wrapper_path;
        }
    };

    const sundapy_bin = getSundapyPath(allocator, io, environ_map);
    std.debug.print("\n[sundafetch] Building standalone executable using '{s}'...\n", .{sundapy_bin});
    std.debug.print("  Command: {s} build {s} -o {s}\n\n", .{ sundapy_bin, script_to_build, final_bin });

    const build_cmd = [_][]const u8{
        sundapy_bin,
        "build",
        script_to_build,
        "-o",
        final_bin,
    };

    const res = try std.process.run(allocator, io, .{
        .argv = &build_cmd,
        .environ_map = environ_map,
    });
    defer allocator.free(res.stdout);
    defer allocator.free(res.stderr);

    if (res.stdout.len > 0) std.debug.print("{s}", .{res.stdout});
    if (res.stderr.len > 0) std.debug.print("{s}", .{res.stderr});

    if (res.term != .exited or res.term.exited != 0) {
        std.debug.print("[sundafetch] Executable compilation failed (exit code: {any})\n", .{res.term});
        return error.CompilationFailed;
    }

    std.debug.print("\n[sundafetch] SUCCESS: Executable binary '{s}' generated successfully!\n", .{final_bin});
}
