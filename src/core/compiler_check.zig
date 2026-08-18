const std = @import("std");

pub const ZigEnvError = error{
    ZigNotFound,
    InvalidVersion,
};

/// Verifies the presence of Zig 0.16.0 in PATH, 
/// or falls back to .cache/zig-bin-dev/zig.
/// Returns the path to the valid Zig executable or an error.
pub fn resolveZigCompiler(allocator: std.mem.Allocator, io: std.Io) ![]const u8 {
    // 1. Try checking global PATH first
    if (checkVersion(allocator, io, "zig")) {
        return "zig";
    }

    // 2. Fallback to local cache binary
    const local_zig = ".cache/zig-bin-dev/zig";
    if (checkVersion(allocator, io, local_zig)) {
        return local_zig;
    }

    // If we reach here, neither PATH nor cache has the correct Zig version
    std.debug.print("Error: Zig compiler 0.16.0 is required but not found.\n", .{});
    std.debug.print("Please install Zig 0.16.0 globally, or ensure it exists at {s}\n", .{local_zig});
    return ZigEnvError.ZigNotFound;
}

fn checkVersion(allocator: std.mem.Allocator, io: std.Io, zig_path: []const u8) bool {
    const res = std.process.run(allocator, io, .{
        .argv = &[_][]const u8{zig_path, "version"},
    }) catch return false;
    
    if (res.term != .exited or res.term.exited != 0) return false;
    
    // We expect "0.16.0" (or similar dev version starting with 0.16)
    return std.mem.startsWith(u8, res.stdout, "0.16.");
}
