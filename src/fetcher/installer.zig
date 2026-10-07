const std = @import("std");
const types = @import("types.zig");
const env_mod = @import("env.zig");
const zip_mod = @import("zip.zig");
const TargetEnv = types.TargetEnv;
const PypiResponse = types.PypiResponse;

pub fn fetchAndInstallPackage(
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

    std.debug.print("  [+] Extracting {s} into .cache/pyLibrary/...\n", .{selected_filename});
    try zip_mod.extractZipFile(io, tmp_path, ".cache/pyLibrary");
    cwd.deleteFile(io, tmp_path) catch {};

    const has_so = zip_mod.checkExtractedHasSo(allocator, io, ".cache/pyLibrary", pkg);
    if (has_so) {
        std.debug.print("  [+] ABI Requirement: Python C-ABI required (.so binary extension detected)\n", .{});
    } else {
        std.debug.print("  [+] ABI Requirement: Zero Python C-ABI (Pure Python, native Zig transpilation target)\n", .{});
    }
    std.debug.print("  [+] Installed '{s}' successfully.\n", .{pkg});

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

pub fn parseDependencySpec(allocator: std.mem.Allocator, spec: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, spec, "extra ==") != null) return null;
    if (env_mod.parseRequirementLine(spec)) |pkg_name| {
        return allocator.dupe(u8, pkg_name) catch null;
    }
    return null;
}

pub fn scoreWheel(filename: []const u8, env: TargetEnv) u32 {
    if (!std.mem.endsWith(u8, filename, ".whl")) return 0;
    const stem = filename[0 .. filename.len - 4];

    var it = std.mem.splitBackwardsScalar(u8, stem, '-');
    const plat_tag = it.next() orelse return 0;
    const abi_tag = it.next() orelse return 0;
    const py_tag = it.next() orelse return 0;

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

    if (std.mem.indexOf(u8, plat_tag, "musllinux") != null) {
        return 0;
    }

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
