const std = @import("std");
const embedded_stdlib = @import("embedded_stdlib");

pub fn isNativeStdlib(raw_mod: []const u8) bool {
    const mod = if (std.mem.endsWith(u8, raw_mod, ".zig")) raw_mod[0 .. raw_mod.len - 4] else raw_mod;
    const core_stdlibs = [_][]const u8{
        "math",
        "time",
        "socket",
        "threading",
        "_thread",
        "asyncio",
        "requests",
        "ffi",
        "screenGUI",
        "GUIEngine",
        "gpu",
    };
    for (core_stdlibs) |m| {
        if (std.mem.eql(u8, mod, m)) return true;
    }
    for (embedded_stdlib.files) |entry| {
        const fname = entry[0];
        if (std.mem.endsWith(u8, fname, ".zig")) {
            const stem = fname[0 .. fname.len - 4];
            if (std.mem.eql(u8, mod, stem)) return true;
        }
    }
    return false;
}

pub fn shouldExtractForModule(raw_mod: []const u8, file_name: []const u8) bool {
    const mod = if (std.mem.endsWith(u8, raw_mod, ".zig")) raw_mod[0 .. raw_mod.len - 4] else raw_mod;
    if (std.mem.eql(u8, mod, "math") or std.mem.eql(u8, mod, "math_integer")) {
        return std.mem.eql(u8, file_name, "math.zig") or std.mem.eql(u8, file_name, "math_integer.zig");
    }
    if (std.mem.eql(u8, mod, "threading") or std.mem.eql(u8, mod, "_thread")) {
        return std.mem.eql(u8, file_name, "threading.zig") or std.mem.eql(u8, file_name, "_thread.zig");
    }
    if (std.mem.eql(u8, mod, "screenGUI") or std.mem.startsWith(u8, mod, "screen_")) {
        return std.mem.eql(u8, file_name, "screenGUI.zig") or std.mem.startsWith(u8, file_name, "screen_");
    }
    if (std.mem.eql(u8, mod, "GUIEngine") or std.mem.startsWith(u8, mod, "gui_") or
        std.mem.eql(u8, mod, "gpu") or std.mem.startsWith(u8, mod, "gpu_"))
    {
        return std.mem.eql(u8, file_name, "GUIEngine.zig") or
            std.mem.startsWith(u8, file_name, "gui_") or
            std.mem.eql(u8, file_name, "gpu.zig") or
            std.mem.startsWith(u8, file_name, "gpu_");
    }
    if (file_name.len == mod.len + 4 and
        std.mem.startsWith(u8, file_name, mod) and
        std.mem.endsWith(u8, file_name, ".zig"))
    {
        return true;
    }
    return false;
}

pub fn provisionStdlib(allocator: std.mem.Allocator, io: std.Io, mod: []const u8) !bool {
    if (!isNativeStdlib(mod)) return false;

    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, ".cache/src") catch {};

    var extracted_count: usize = 0;
    for (embedded_stdlib.files) |entry| {
        const rel_name = entry[0];
        const data = entry[1];
        if (shouldExtractForModule(mod, rel_name)) {
            const dest_path = try std.fmt.allocPrint(allocator, ".cache/src/{s}", .{rel_name});
            defer allocator.free(dest_path);
            if (std.fs.path.dirname(dest_path)) |parent_dir| {
                cwd.createDirPath(io, parent_dir) catch {};
            }
            try cwd.writeFile(io, .{ .sub_path = dest_path, .data = data });
            extracted_count += 1;
        }
    }
    return extracted_count > 0;
}
