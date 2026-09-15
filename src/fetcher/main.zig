const std = @import("std");
const builtin = @import("builtin");

const PypiUrl = struct {
    filename: []const u8,
    url: []const u8,
    packagetype: []const u8,
};

const PypiInfo = struct {
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    requires_dist: ?[][]const u8 = null,
};

const PypiResponse = struct {
    urls: []PypiUrl = &.{},
    info: ?PypiInfo = null,
};

const TargetEnv = struct {
    py_tag: []const u8,
    abi_tag: []const u8,
    py_ver_num: u32,
    is_free_threaded: bool,
    arch: []const u8,
    os: []const u8,
};

pub fn main(ctx: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var args_iter = try std.process.Args.Iterator.initAllocator(ctx.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // skip executable

    var raw_packages = std.ArrayList([]const u8).empty;
    defer raw_packages.deinit(allocator);

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--requirement")) {
            if (args_iter.next()) |req_file| {
                try parseRequirementsFile(allocator, io, req_file, &raw_packages);
            } else {
                std.debug.print("Error: -r/--requirement requires a file path\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.endsWith(u8, arg, ".txt")) {
            // Automatically treat any argument ending in .txt as a requirement file
            try parseRequirementsFile(allocator, io, arg, &raw_packages);
        } else if (std.mem.startsWith(u8, arg, "-")) {
            // Ignore other flags
        } else {
            // Direct package name or specifier
            if (parseRequirementLine(arg)) |pkg_name| {
                try appendUnique(allocator, &raw_packages, pkg_name);
            }
        }
    }

    if (raw_packages.items.len == 0) {
        printHelp();
        std.process.exit(1);
    }

    // Ensure .cache/pyLibrary exists strictly locally
    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, ".cache/pyLibrary") catch {};

    const target_env = detectTargetEnv(allocator, io);
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
        const canonical = try canonicalPkgName(allocator, pkg);
        if (!visited_map.contains(canonical)) {
            try visited_map.put(canonical, true);
            try queue.append(allocator, canonical);
        }
    }

    var idx: usize = 0;
    while (idx < queue.items.len) : (idx += 1) {
        const pkg = queue.items[idx];
        const new_deps = try fetchAndInstallPackage(allocator, io, &bundle, pkg, target_env);
        for (new_deps) |dep| {
            const canonical_dep = try canonicalPkgName(allocator, dep);
            if (!visited_map.contains(canonical_dep) and !isPackageInstalled(io, canonical_dep)) {
                try visited_map.put(canonical_dep, true);
                try queue.append(allocator, canonical_dep);
            }
        }
    }

    std.debug.print("\n[sundafetch] All packages installed into .cache/pyLibrary successfully.\n", .{});
}

fn printHelp() void {
    std.debug.print(
        \\sundafetch - High-performance zero-dependency PyPI package fetcher & installer
        \\
        \\Usage:
        \\  sundafetch <package> [<package2> ...]
        \\  sundafetch -r <requirements.txt>
        \\  sundafetch <requirements.txt>
        \\
        \\Options:
        \\  -r, --requirement <file>  Install from the given requirements file
        \\  -h, --help                Show this help message and exit
        \\
        \\All packages are installed strictly into .cache/pyLibrary/ (isolated from global).
        \\
    , .{});
}

fn canonicalPkgName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
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

fn appendUnique(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), item: []const u8) !void {
    for (list.items) |existing| {
        if (std.ascii.eqlIgnoreCase(existing, item)) return;
    }
    try list.append(allocator, try allocator.dupe(u8, item));
}

fn parseRequirementLine(line: []const u8) ?[]const u8 {
    var s = std.mem.trim(u8, line, " \t\r\n");
    if (s.len == 0 or s[0] == '#') return null;

    if (std.mem.indexOfScalar(u8, s, '#')) |idx| {
        s = std.mem.trim(u8, s[0..idx], " \t\r\n");
    }
    if (s.len == 0) return null;

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

    var cut_len: usize = s.len;
    for (s, 0..) |c, i| {
        if (c == '=' or c == '>' or c == '<' or c == '~' or c == '!' or c == ';' or c == '@') {
            cut_len = i;
            break;
        }
    }
    s = std.mem.trim(u8, s[0..cut_len], " \t\r\n");
    if (s.len == 0) return null;
    return s;
}

fn parseRequirementsFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8, packages: *std.ArrayList([]const u8)) !void {
    const cwd = std.Io.Dir.cwd();
    const content = cwd.readFileAlloc(io, file_path, allocator, @enumFromInt(10 * 1024 * 1024)) catch |err| {
        std.debug.print("Failed to read requirements file '{s}': {any}\n", .{ file_path, err });
        return err;
    };
    defer allocator.free(content);

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |raw_line| {
        const trimmed = std.mem.trim(u8, raw_line, " \t\r\n");
        if (std.mem.startsWith(u8, trimmed, "-r ")) {
            const nested = std.mem.trim(u8, trimmed[3..], " \t");
            try parseRequirementsFile(allocator, io, nested, packages);
        } else if (std.mem.startsWith(u8, trimmed, "--requirement ")) {
            const nested = std.mem.trim(u8, trimmed[14..], " \t");
            try parseRequirementsFile(allocator, io, nested, packages);
        } else if (parseRequirementLine(raw_line)) |pkg_name| {
            try appendUnique(allocator, packages, pkg_name);
        }
    }
}

fn detectTargetEnv(allocator: std.mem.Allocator, io: std.Io) TargetEnv {
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

fn isPackageInstalled(io: std.Io, pkg: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, ".cache/pyLibrary", .{ .iterate = true }) catch return false;
    defer dir.close(io);

    // Normalize name
    var norm_buf: [128]u8 = undefined;
    const norm = if (pkg.len < 128) blk: {
        @memcpy(norm_buf[0..pkg.len], pkg);
        for (norm_buf[0..pkg.len]) |*c| {
            if (c.* == '-') c.* = '_';
        }
        break :blk norm_buf[0..pkg.len];
    } else pkg;

    // Check directory pkg, or pkg.py, or pkg-*.dist-info
    var check1_buf: [256]u8 = undefined;
    const p1 = std.fmt.bufPrint(&check1_buf, "{s}", .{norm}) catch return false;
    if (dir.access(io, p1, .{})) |_| return true else |_| {}

    var check2_buf: [256]u8 = undefined;
    const p2 = std.fmt.bufPrint(&check2_buf, "{s}.py", .{norm}) catch return false;
    if (dir.access(io, p2, .{})) |_| return true else |_| {}

    return false;
}

fn fetchAndInstallPackage(
    allocator: std.mem.Allocator,
    io: std.Io,
    shared_bundle: *std.crypto.Certificate.Bundle,
    pkg: []const u8,
    env: TargetEnv,
) ![][]const u8 {
    std.debug.print("==> Resolving {s} from PyPI...\n", .{pkg});

    var client = std.http.Client{
        .allocator = allocator,
        .io = io,
        .ca_bundle = shared_bundle.*,
        .now = std.Io.Clock.real.now(io),
    };
    defer {
        client.ca_bundle = .empty;
        client.deinit();
    }

    const url = try std.fmt.allocPrint(allocator, "https://pypi.org/pypi/{s}/json/", .{pkg});
    defer allocator.free(url);

    var req = try client.request(.GET, try std.Uri.parse(url), .{
        .headers = .{ .accept_encoding = .{ .override = "gzip" } },
        .redirect_behavior = @enumFromInt(5),
    });
    defer req.deinit();
    try req.sendBodiless();

    var server_header_buffer: [8192]u8 = undefined;
    var res = try req.receiveHead(&server_header_buffer);

    if (@intFromEnum(res.head.status) != 200) {
        std.debug.print("Failed to fetch metadata for {s} (HTTP {})\n", .{ pkg, res.head.status });
        return error.MetadataFetchFailed;
    }

    var transfer_buf: [8192]u8 = undefined;
    const transfer_reader = res.reader(&transfer_buf);

    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var flate = std.compress.flate.Decompress.init(transfer_reader, .gzip, &decompress_buf);

    const body = try flate.reader.allocRemaining(allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(body);

    const parsed = try std.json.parseFromSlice(PypiResponse, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    if (parsed.value.urls.len == 0) {
        std.debug.print("No distribution URLs found for {s}\n", .{pkg});
        return error.NoDistributionFound;
    }

    // Score all wheels and pick the best compatible candidate
    var best_score: u32 = 0;
    var best_url: ?[]const u8 = null;
    var best_filename: ?[]const u8 = null;

    for (parsed.value.urls) |u| {
        if (!std.mem.eql(u8, u.packagetype, "bdist_wheel")) continue;
        const score = scoreWheel(u.filename, env);
        if (score > best_score) {
            best_score = score;
            best_url = u.url;
            best_filename = u.filename;
        }
    }

    const selected_url = best_url orelse {
        std.debug.print("No compatible wheel found for {s} on {s}/{s} ({s})\n", .{
            pkg, env.os, env.arch, env.py_tag,
        });
        return error.NoCompatibleWheelFound;
    };
    const selected_filename = best_filename.?;

    std.debug.print("  [+] Selected wheel: {s} (score: {})\n", .{ selected_filename, best_score });
    std.debug.print("  [+] Downloading from: {s}\n", .{selected_url});

    var dl_req = try client.request(.GET, try std.Uri.parse(selected_url), .{
        .redirect_behavior = @enumFromInt(5),
    });
    defer dl_req.deinit();
    try dl_req.sendBodiless();

    var dl_header_buf: [8192]u8 = undefined;
    var dl_res = try dl_req.receiveHead(&dl_header_buf);

    if (dl_res.head.status != .ok) {
        std.debug.print("Failed to download wheel (HTTP {})\n", .{dl_res.head.status});
        return error.DownloadFailed;
    }

    const cwd = std.Io.Dir.cwd();
    const tmp_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.whl", .{pkg});
    defer allocator.free(tmp_path);

    // Stream download directly to file in 64KB stack chunks (micro-optimized, zero large heap buffers)
    {
        var out_file = try cwd.createFile(io, tmp_path, .{ .truncate = true });
        defer out_file.close(io);

        var file_writer_buf: [65536]u8 = undefined;
        var file_writer = out_file.writer(io, &file_writer_buf);

        var dl_transfer_buf: [65536]u8 = undefined;
        const dl_reader = dl_res.reader(&dl_transfer_buf);

        var total_downloaded: u64 = 0;
        while (true) {
            var chunk_buf: [65536]u8 = undefined;
            const n = try dl_reader.readSliceShort(&chunk_buf);
            if (n == 0) break;
            try file_writer.interface.writeAll(chunk_buf[0..n]);
            total_downloaded += n;
        }
        try file_writer.end();
        std.debug.print("  [+] Streamed {d} bytes directly to disk.\n", .{total_downloaded});
    }

    // Low-level ZIP extraction with automatic overwrite
    std.debug.print("  [+] Extracting {s} into .cache/pyLibrary/...\n", .{selected_filename});
    try extractZipFile(io, tmp_path, ".cache/pyLibrary");

    // Clean up temporary wheel file
    cwd.deleteFile(io, tmp_path) catch {};

    const has_so = checkExtractedHasSo(allocator, io, ".cache/pyLibrary", pkg);
    if (has_so) {
        std.debug.print("  [+] ABI Requirement: Python C-ABI required (.so binary extension detected)\n", .{});
    } else {
        std.debug.print("  [+] ABI Requirement: Zero Python C-ABI (Pure Python, native Zig transpilation target)\n", .{});
    }
    std.debug.print("  [+] Installed '{s}' successfully.\n", .{pkg});

    // Parse dependencies from requires_dist if available
    var deps_list = std.ArrayList([]const u8).empty;
    if (parsed.value.info) |info| {
        if (info.requires_dist) |reqs| {
            for (reqs) |req_str| {
                if (parseDependencySpec(allocator, req_str)) |dep_name| {
                    try deps_list.append(allocator, dep_name);
                }
            }
        }
    }

    return try deps_list.toOwnedSlice(allocator);
}

fn parseDependencySpec(allocator: std.mem.Allocator, spec: []const u8) ?[]const u8 {
    // If requirement has condition with extra ==, skip it (optional feature)
    if (std.mem.indexOf(u8, spec, "extra ==") != null) return null;

    if (parseRequirementLine(spec)) |pkg_name| {
        return allocator.dupe(u8, pkg_name) catch null;
    }
    return null;
}

fn scoreWheel(filename: []const u8, env: TargetEnv) u32 {
    if (!std.mem.endsWith(u8, filename, ".whl")) return 0;
    const stem = filename[0 .. filename.len - 4];

    var it = std.mem.splitBackwardsScalar(u8, stem, '-');
    const plat_tag = it.next() orelse return 0;
    const abi_tag = it.next() orelse return 0;
    const py_tag = it.next() orelse return 0;

    // Reject macOS and Windows when target is Linux
    if (std.mem.eql(u8, env.os, "linux")) {
        if (std.mem.indexOf(u8, plat_tag, "macosx") != null or
            std.mem.indexOf(u8, plat_tag, "darwin") != null or
            std.mem.indexOf(u8, plat_tag, "win32") != null or
            std.mem.indexOf(u8, plat_tag, "win_amd64") != null or
            std.mem.indexOf(u8, plat_tag, "win_arm64") != null)
        {
            return 0;
        }
    }

    // Reject incompatible CPU architectures
    if (std.mem.eql(u8, env.arch, "x86_64")) {
        if (std.mem.indexOf(u8, plat_tag, "aarch64") != null or
            std.mem.indexOf(u8, plat_tag, "armv7l") != null or
            std.mem.indexOf(u8, plat_tag, "i686") != null or
            std.mem.indexOf(u8, plat_tag, "ppc64le") != null or
            std.mem.indexOf(u8, plat_tag, "s390x") != null or
            std.mem.indexOf(u8, plat_tag, "riscv64") != null)
        {
            return 0;
        }
    } else if (std.mem.eql(u8, env.arch, "aarch64")) {
        if (std.mem.indexOf(u8, plat_tag, "x86_64") != null or
            std.mem.indexOf(u8, plat_tag, "i686") != null)
        {
            return 0;
        }
    }

    // Glibc Linux host: reject musllinux
    if (std.mem.indexOf(u8, plat_tag, "musllinux") != null) {
        return 0;
    }

    // Check free-threading ABI match
    const wheel_is_free_threaded = std.mem.endsWith(u8, abi_tag, "t");
    if (wheel_is_free_threaded != env.is_free_threaded) {
        return 0;
    }

    const is_universal = std.mem.eql(u8, plat_tag, "any");
    const is_linux_arch = std.mem.indexOf(u8, plat_tag, env.arch) != null and
        (std.mem.indexOf(u8, plat_tag, "manylinux") != null or std.mem.indexOf(u8, plat_tag, "linux") != null);

    if (!is_universal and !is_linux_arch) {
        return 0;
    }

    var base_score: u32 = 0;

    if (is_universal) {
        if (std.mem.indexOf(u8, py_tag, "py3") != null or
            std.mem.indexOf(u8, py_tag, "py2.py3") != null or
            std.mem.eql(u8, py_tag, env.py_tag))
        {
            base_score = 500;
        } else {
            return 0;
        }
    } else {
        // Native wheel
        if (std.mem.eql(u8, py_tag, env.py_tag) and std.mem.eql(u8, abi_tag, env.abi_tag)) {
            base_score = if (std.mem.indexOf(u8, plat_tag, "manylinux") != null) 1000 else 900;
        } else if (std.mem.eql(u8, abi_tag, "abi3")) {
            if (std.mem.startsWith(u8, py_tag, "cp3")) {
                const ver_num = std.fmt.parseInt(u32, py_tag[3..], 10) catch 999;
                const target_minor = env.py_ver_num % 100;
                if (ver_num <= target_minor) {
                    base_score = if (std.mem.indexOf(u8, plat_tag, "manylinux") != null) 800 else 700;
                } else {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    // Bonus for modern manylinux glibc standards
    if (std.mem.indexOf(u8, plat_tag, "manylinux_2_28") != null) {
        base_score += 28;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux_2_27") != null) {
        base_score += 27;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux_2_17") != null) {
        base_score += 17;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux2014") != null) {
        base_score += 14;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux2010") != null) {
        base_score += 10;
    } else if (std.mem.indexOf(u8, plat_tag, "manylinux1") != null) {
        base_score += 1;
    }

    return base_score;
}

fn extractEntry(
    self: std.zip.Iterator.Entry,
    stream: *std.Io.File.Reader,
    filename_buf: []u8,
    dest: std.Io.Dir,
) !void {
    const io = stream.io;
    if (filename_buf.len < self.filename_len)
        return error.ZipInsufficientBuffer;

    switch (self.compression_method) {
        .store, .deflate => {},
        else => return error.UnsupportedCompressionMethod,
    }

    const filename = filename_buf[0..self.filename_len];
    try stream.seekTo(self.header_zip_offset + @sizeOf(std.zip.CentralDirectoryFileHeader));
    try stream.interface.readSliceAll(filename);

    if (filename.len == 0) return;

    // Entries ending in '/' are directories
    if (filename[filename.len - 1] == '/') {
        try dest.createDirPath(io, filename[0 .. filename.len - 1]);
        return;
    }

    const local_header = blk: {
        try stream.seekTo(self.file_offset);
        break :blk try stream.interface.takeStruct(std.zip.LocalFileHeader, .little);
    };
    if (!std.mem.eql(u8, &local_header.signature, &std.zip.local_file_header_sig))
        return error.ZipBadFileOffset;

    const local_data_header_offset: u64 = @as(u64, local_header.filename_len) + @as(u64, local_header.extra_len);

    const out_file = blk: {
        if (std.fs.path.dirname(filename)) |dirname| {
            try dest.createDirPath(io, dirname);
            var parent_dir = try dest.openDir(io, dirname, .{});
            defer parent_dir.close(io);
            const basename = std.fs.path.basename(filename);
            break :blk try parent_dir.createFile(io, basename, .{ .truncate = true });
        }
        break :blk try dest.createFile(io, filename, .{ .truncate = true });
    };
    defer out_file.close(io);

    var out_file_buffer: [8192]u8 = undefined;
    var file_writer = out_file.writer(io, &out_file_buffer);
    const local_data_file_offset: u64 =
        @as(u64, self.file_offset) +
        @as(u64, @sizeOf(std.zip.LocalFileHeader)) +
        local_data_header_offset;
    try stream.seekTo(local_data_file_offset);

    switch (self.compression_method) {
        .store => {
            stream.interface.streamExact64(&file_writer.interface, self.uncompressed_size) catch |err| switch (err) {
                error.ReadFailed => return stream.err.?,
                error.WriteFailed => return file_writer.err.?,
                error.EndOfStream => return error.ZipDecompressTruncated,
            };
        },
        .deflate => {
            var flate_buffer: [std.compress.flate.max_window_len]u8 = undefined;
            var decompress: std.compress.flate.Decompress = .init(&stream.interface, .raw, &flate_buffer);
            decompress.reader.streamExact64(&file_writer.interface, self.uncompressed_size) catch |err| switch (err) {
                error.ReadFailed => return stream.err.?,
                error.WriteFailed => return file_writer.err orelse decompress.err.?,
                error.EndOfStream => return error.ZipDecompressTruncated,
            };
        },
        else => return error.UnsupportedCompressionMethod,
    }
    try file_writer.end();
}

fn extractZipFile(io: std.Io, zip_path: []const u8, dest_dir_path: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.openFile(io, zip_path, .{});
    defer file.close(io);

    var dest_dir = try cwd.openDir(io, dest_dir_path, .{});
    defer dest_dir.close(io);

    var file_reader_buf: [8192]u8 = undefined;
    var reader = file.reader(io, &file_reader_buf);

    var iter = try std.zip.Iterator.init(&reader);
    var filename_buf: [std.fs.max_path_bytes]u8 = undefined;

    while (try iter.next()) |entry| {
        try extractEntry(entry, &reader, &filename_buf, dest_dir);
    }
}

fn checkExtractedHasSo(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8, pkg: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, base_dir, .{ .iterate = true }) catch return false;
    defer dir.close(io);

    var norm_buf: [128]u8 = undefined;
    const norm = if (pkg.len < 128) blk: {
        @memcpy(norm_buf[0..pkg.len], pkg);
        for (norm_buf[0..pkg.len]) |*c| {
            if (c.* == '-') c.* = '_';
        }
        break :blk norm_buf[0..pkg.len];
    } else pkg;

    var check_buf: [256]u8 = undefined;
    const so_path = std.fmt.bufPrint(&check_buf, "{s}.so", .{norm}) catch return false;
    if (dir.access(io, so_path, .{})) |_| return true else |_| {}

    var pkg_sub = dir.openDir(io, norm, .{ .iterate = true }) catch return false;
    defer pkg_sub.close(io);

    return scanDirForSo(allocator, io, pkg_sub);
}

fn scanDirForSo(allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir) bool {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var stack: std.ArrayList([]const u8) = .empty;

    // 1. Scan root_dir directly
    {
        var iter = root_dir.iterate();
        while (true) {
            const entry_opt = iter.next(io) catch break;
            if (entry_opt == null) break;
            const entry = entry_opt.?;
            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".so") or std.mem.endsWith(u8, entry.name, ".pyd")) {
                    return true;
                }
            } else if (entry.kind == .directory) {
                if (!std.mem.eql(u8, entry.name, "__pycache__") and !std.mem.startsWith(u8, entry.name, ".")) {
                    const sub_path = arena_alloc.dupe(u8, entry.name) catch continue;
                    stack.append(arena_alloc, sub_path) catch continue;
                }
            }
        }
    }

    // 2. Process all subdirectories purely iteratively (zero recursion)
    while (stack.items.len > 0) {
        const rel_path = stack.pop().?;

        var dir = root_dir.openDir(io, rel_path, .{ .iterate = true }) catch continue;
        defer dir.close(io);

        var iter = dir.iterate();
        while (true) {
            const entry_opt = iter.next(io) catch break;
            if (entry_opt == null) break;
            const entry = entry_opt.?;

            if (entry.kind == .file) {
                if (std.mem.endsWith(u8, entry.name, ".so") or std.mem.endsWith(u8, entry.name, ".pyd")) {
                    return true;
                }
            } else if (entry.kind == .directory) {
                if (!std.mem.eql(u8, entry.name, "__pycache__") and !std.mem.startsWith(u8, entry.name, ".")) {
                    const sub_path = std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ rel_path, entry.name }) catch continue;
                    stack.append(arena_alloc, sub_path) catch continue;
                }
            }
        }
    }
    return false;
}


