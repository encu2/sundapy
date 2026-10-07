const std = @import("std");

const TemplateEntry = struct {
    rel_path: []const u8,
    data: []const u8,
    skip_if_exists: bool,
};

const templates = [_]TemplateEntry{
    .{ .rel_path = "main.py", .data = @embedFile("templates/main.py"), .skip_if_exists = true },
    .{ .rel_path = "SUNDAPY_GUIDE.md", .data = @embedFile("templates/SUNDAPY_GUIDE.md"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/settings.json", .data = @embedFile("templates/vscode/settings.json"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/tasks.json", .data = @embedFile("templates/vscode/tasks.json"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/sundapy.code-snippets", .data = @embedFile("templates/vscode/sundapy.code-snippets"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/__builtins__.pyi", .data = @embedFile("templates/typings/__builtins__.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/gpu.pyi", .data = @embedFile("templates/typings/gpu.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/screenGUI.pyi", .data = @embedFile("templates/typings/screenGUI.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/GUIEngine.pyi", .data = @embedFile("templates/typings/GUIEngine.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/time.pyi", .data = @embedFile("templates/typings/time.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/socket.pyi", .data = @embedFile("templates/typings/socket.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/threading.pyi", .data = @embedFile("templates/typings/threading.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/asyncio.pyi", .data = @embedFile("templates/typings/asyncio.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/requests.pyi", .data = @embedFile("templates/typings/requests.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/math.pyi", .data = @embedFile("templates/typings/math.pyi"), .skip_if_exists = false },
    .{ .rel_path = ".vscode/typings/ffi.pyi", .data = @embedFile("templates/typings/ffi.pyi"), .skip_if_exists = false },
};

pub fn runInit(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = allocator;
    const cwd = std.Io.Dir.cwd();

    std.debug.print("\nInitializing new SundaPy project with VSCode helper...\n\n", .{});

    // 1. Ensure required subdirectories exist
    cwd.createDirPath(io, ".vscode") catch {};
    cwd.createDirPath(io, ".vscode/typings") catch {};

    var files_created: usize = 0;
    var files_skipped: usize = 0;

    // 2. Write embedded template files
    for (templates) |entry| {
        if (entry.skip_if_exists) {
            if (cwd.access(io, entry.rel_path, .{})) |_| {
                std.debug.print("  [SKIP]  {s} already exists\n", .{entry.rel_path});
                files_skipped += 1;
                continue;
            } else |_| {}
        }

        cwd.writeFile(io, .{
            .sub_path = entry.rel_path,
            .data = entry.data,
        }) catch |err| {
            std.debug.print("  [ERROR] Failed to write {s}: {any}\n", .{ entry.rel_path, err });
            return err;
        };

        std.debug.print("  [OK]    Created {s}\n", .{entry.rel_path});
        files_created += 1;
    }

    std.debug.print("\n=============================================================\n", .{});
    std.debug.print("✔ SundaPy Project Initialized Successfully!\n", .{});
    std.debug.print("  - Files Created : {d}\n", .{files_created});
    if (files_skipped > 0) {
        std.debug.print("  - Files Preserved : {d}\n", .{files_skipped});
    }
    std.debug.print("  - VSCode IntelliSense & Type Stubs: READY (.vscode/typings/)\n", .{});
    std.debug.print("=============================================================\n\n", .{});
    std.debug.print("Next Steps:\n", .{});
    std.debug.print("  1. Run your code        : sundapy main.py\n", .{});
    std.debug.print("  2. Open in VSCode       : code .\n", .{});
    std.debug.print("  3. Read Documentation   : View SUNDAPY_GUIDE.md\n\n", .{});
}
