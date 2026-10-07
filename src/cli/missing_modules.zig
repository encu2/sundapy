const std = @import("std");
const builder = @import("builder.zig");

pub fn handleMissingModules(
    allocator: std.mem.Allocator,
    io: std.Io,
    compiler: anytype,
    auto_yes: *bool,
) bool {
    std.debug.print("\n[SUNDAPY] Missing External Libraries Detected:\n", .{});
    for (compiler.global_missing_modules.items) |mod| {
        std.debug.print("  - {s}\n", .{mod});
    }
    std.debug.print("\nThese modules were not found in local directories, .cache/pyLibrary, or system Python.\n", .{});

    var proceed_fetch = false;
    if (auto_yes.*) {
        std.debug.print("Auto-fetching due to -y flag...\n", .{});
        proceed_fetch = true;
    } else {
        std.debug.print("Would you like to automatically fetch them using 'sundafetch'? [Y/n]: ", .{});

        var buf: [16]u8 = undefined;
        const bytes_read = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
        if (bytes_read > 0) {
            const line = std.mem.trim(u8, buf[0..bytes_read], " \r\n");
            if (line.len == 0 or line[0] == 'y' or line[0] == 'Y') {
                proceed_fetch = true;
                auto_yes.* = true;
            }
        }
    }

    if (proceed_fetch) {
        var all_success = true;
        const sundafetch_bin = builder.getSundafetchPath(allocator, io);
        for (compiler.global_missing_modules.items) |mod| {
            std.debug.print("Fetching '{s}' via sundafetch...\n", .{mod});
            const fetch_cmd = &[_][]const u8{ sundafetch_bin, mod };
            const res = std.process.run(allocator, io, .{ .argv = fetch_cmd }) catch null;
            var fetch_failed = false;
            if (res == null or res.?.term != .exited or res.?.term.exited != 0) {
                fetch_failed = true;
            } else if (res.?.stderr.len > 0) {
                if (std.mem.indexOf(u8, res.?.stderr, "Error fetching") != null or
                    std.mem.indexOf(u8, res.?.stderr, "Failed to fetch metadata") != null)
                {
                    fetch_failed = true;
                }
            }
            if (res) |r| {
                if (r.stdout.len > 0) std.debug.print("{s}", .{r.stdout});
                if (r.stderr.len > 0) std.debug.print("{s}", .{r.stderr});
            }

            if (!fetch_failed) {
                std.debug.print("Successfully fetched '{s}'.\n", .{mod});
            } else {
                std.debug.print("Failed to fetch '{s}'. Marking as failed and continuing...\n", .{mod});
                if (!compiler.global_failed_modules.contains(mod)) {
                    if (allocator.dupe(u8, mod)) |mod_dup| {
                        compiler.global_failed_modules.put(allocator, mod_dup, true) catch {};
                    } else |_| {}
                }
                all_success = false;
            }
        }
        std.debug.print("\nResuming compilation automatically...\n\n", .{});
        return all_success;
    }

    std.debug.print("\nOperation cancelled. You can install them manually by running:\n", .{});
    for (compiler.global_missing_modules.items) |mod| {
        std.debug.print("  sundafetch {s}\n", .{mod});
    }
    std.debug.print("\n", .{});
    std.process.exit(1);
}
