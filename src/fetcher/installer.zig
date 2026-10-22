const std = @import("std");
const types = @import("types.zig");
const env_mod = @import("env.zig");
const zip_mod = @import("zip.zig");
const sdist_mod = @import("sdist.zig");
const security = @import("security.zig");
const wheel_score = @import("wheel_score.zig");

const TargetEnv = types.TargetEnv;
const PypiResponse = types.PypiResponse;
const scoreWheel = wheel_score.scoreWheel;

pub fn fetchAndInstallPackage(
    allocator: std.mem.Allocator,
    io: std.Io,
    shared_bundle: *std.crypto.Certificate.Bundle,
    pkg: []const u8,
    env: TargetEnv,
) ![][]const u8 {
    if (!security.validatePackageName(pkg)) {
        std.debug.print("Error: Invalid or insecure package name: '{s}'\n", .{pkg});
        return error.InvalidPackageName;
    }

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
    var best_sha256: ?[]const u8 = null;
    var best_size: ?u64 = null;

    for (parsed.value.urls) |u| {
        if (u.yanked != null and u.yanked.? == true) continue;
        if (!std.mem.eql(u8, u.packagetype, "bdist_wheel")) continue;
        const score = scoreWheel(u.filename, env);
        if (score > best_score) {
            best_score = score;
            best_url = u.url;
            best_filename = u.filename;
            best_size = u.size;
            best_sha256 = if (u.digests) |d| d.sha256 else null;
        }
    }

    if (best_url == null) {
        const built_ok = sdist_mod.buildAndInstallSdist(allocator, io, pkg, env.environ_map) catch false;
        if (!built_ok) {
            std.debug.print("No compatible wheel found for {s} on {s}/{s} ({s})\n", .{
                pkg, env.os, env.arch, env.py_tag,
            });
            return error.NoCompatibleWheelFound;
        }
    } else {
        const selected_url = best_url.?;
        const selected_filename = best_filename.?;

        if (!security.isSafeHttpsUrl(selected_url)) {
            std.debug.print("Error: Insecure download URL scheme for '{s}': {s}\n", .{ pkg, selected_url });
            return error.InsecureUrlProtocol;
        }

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
        const now_ns = std.Io.Clock.real.now(io).nanoseconds;
        const tmp_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/.tmp_dl_{s}_{d}.whl", .{ pkg, now_ns });
        defer allocator.free(tmp_path);
        defer cwd.deleteFile(io, tmp_path) catch {};

        {
            var out_file = try cwd.createFile(io, tmp_path, .{ .truncate = true });
            defer out_file.close(io);

            var file_writer_buf: [65536]u8 = undefined;
            var file_writer = out_file.writer(io, &file_writer_buf);

            var dl_transfer_buf: [65536]u8 = undefined;
            const dl_reader = dl_res.reader(&dl_transfer_buf);

            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            var total_downloaded: u64 = 0;

            while (true) {
                var chunk_buf: [65536]u8 = undefined;
                const n = try dl_reader.readSliceShort(&chunk_buf);
                if (n == 0) break;
                const chunk = chunk_buf[0..n];
                hasher.update(chunk);
                try file_writer.interface.writeAll(chunk);
                total_downloaded += n;

                if (total_downloaded > security.MAX_DOWNLOAD_BYTES) {
                    std.debug.print("  [!] Download size limit exceeded (> {d} bytes)\n", .{security.MAX_DOWNLOAD_BYTES});
                    return error.DownloadTooLarge;
                }
            }
            try file_writer.end();
            std.debug.print("  [+] Streamed {d} bytes directly to disk.\n", .{total_downloaded});

            if (best_size) |expected_size| {
                if (total_downloaded != expected_size) {
                    std.debug.print("  [!] Downloaded size mismatch (got {d}, expected {d})\n", .{ total_downloaded, expected_size });
                    return error.DownloadSizeMismatch;
                }
            }

            var digest: [32]u8 = undefined;
            hasher.final(&digest);

            if (best_sha256) |expected_sha| {
                if (!security.verifySha256(expected_sha, digest)) {
                    const actual_hex = std.fmt.bytesToHex(digest, .lower);
                    std.debug.print("  [!] SECURITY ALERT: SHA-256 checksum mismatch for '{s}'!\n", .{pkg});
                    std.debug.print("      Expected: {s}\n", .{expected_sha});
                    std.debug.print("      Actual:   {s}\n", .{actual_hex});
                    return error.ChecksumMismatch;
                }
                std.debug.print("  [+] Verified SHA-256 checksum: {s}\n", .{expected_sha});
            }
        }

        std.debug.print("  [+] Extracting {s} into .cache/pyLibrary/...\n", .{selected_filename});
        try zip_mod.extractZipFile(io, tmp_path, ".cache/pyLibrary");
    }

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
                if (parseDependencySpec(allocator, req_str, env.os)) |dep_name| {
                    try deps_list.append(allocator, dep_name);
                }
            }
        }
    }
    if (deps_list.items.len == 0) {
        sdist_mod.parseExtractedMetadataDeps(allocator, io, pkg, &deps_list) catch {};
    }

    return try deps_list.toOwnedSlice(allocator);
}

pub fn parseDependencySpec(allocator: std.mem.Allocator, spec: []const u8, os: []const u8) ?[]const u8 {
    if (std.mem.indexOfScalar(u8, spec, ';')) |semi_idx| {
        const marker = spec[semi_idx + 1 ..];
        if (!env_mod.isMarkerSupported(marker, os)) return null;
    }
    if (env_mod.parseRequirementLine(spec)) |pkg_name| {
        return allocator.dupe(u8, pkg_name) catch null;
    }
    return null;
}
