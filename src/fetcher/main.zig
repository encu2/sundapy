const std = @import("std");

pub fn main(ctx: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = try std.process.Args.Iterator.initAllocator(ctx.minimal.args, allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // skip executable

    var packages: std.ArrayList([]const u8) = .empty;

    while (args_iter.next()) |arg| {
        try packages.append(allocator, arg);
    }

    if (packages.items.len == 0) {
        std.debug.print("Usage: sundafetch <pkg1> <pkg2> ...\n", .{});
        std.process.exit(1);
    }

    // Initialize IO
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, ".cache/pyLibrary") catch {};

    var bundle = std.crypto.Certificate.Bundle.empty;
    try bundle.rescan(allocator, io, std.Io.Clock.real.now(io));

    var threads = std.ArrayList(std.Thread).empty;
    defer threads.deinit(allocator);

    for (packages.items) |pkg| {
        const t = try std.Thread.spawn(.{}, fetchPackage, .{allocator, &bundle, pkg});
        try threads.append(allocator, t);
    }

    for (threads.items) |t| {
        t.join();
    }

    std.debug.print("All packages fetched successfully.\n", .{});
}

fn fetchPackage(allocator: std.mem.Allocator, shared_bundle: *std.crypto.Certificate.Bundle, pkg: []const u8) void {
    fetchPackageImpl(allocator, shared_bundle, pkg) catch |err| {
        std.debug.print("Error fetching '{s}': {any}\n", .{pkg, err});
    };
}

fn fetchPackageImpl(allocator: std.mem.Allocator, shared_bundle: *std.crypto.Certificate.Bundle, pkg: []const u8) !void {
    std.debug.print("Resolving {s}...\n", .{pkg});
    
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = std.http.Client{
        .allocator = allocator,
        .io = io,
        .ca_bundle = shared_bundle.*,
        .now = std.Io.Clock.real.now(io),
    };
    defer {
        // Prevent client.deinit() from freeing the shared bundle's inner pointers!
        client.ca_bundle = .empty;
        client.deinit();
    }

    // The user wants a native resolver. We can't bundle python/uv.
    // But JSON parsing + HTTP request + ZIP extraction in Zig takes a lot of code.
    // Let's implement the HTTP + JSON + ZIP extraction!

    const url = try std.fmt.allocPrint(allocator, "https://pypi.org/pypi/{s}/json/", .{pkg});
    defer allocator.free(url);

    var req = try client.request(.GET, try std.Uri.parse(url), .{
        .headers = .{ .accept_encoding = .{ .override = "gzip" } },
    });
    defer req.deinit();
    try req.sendBodiless();

    var server_header_buffer: [8192]u8 = undefined;
    var res = try req.receiveHead(&server_header_buffer);

    if (@intFromEnum(res.head.status) != 200) {
        std.debug.print("Failed to fetch metadata for {s} (status {})\n", .{pkg, res.head.status});
        return error.MetadataFetchFailed;
    }

    std.debug.print("[{s}] Reading transfer buffer...\n", .{pkg});
    var transfer_buf: [8192]u8 = undefined;
    const transfer_reader = res.reader(&transfer_buf);
    
    // PyPI forces gzip if accept-encoding is provided
    std.debug.print("[{s}] Initializing decompressor...\n", .{pkg});
    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var flate = std.compress.flate.Decompress.init(transfer_reader, .gzip, &decompress_buf);
    
    std.debug.print("[{s}] Allocating and reading body...\n", .{pkg});
    const body = try flate.reader.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(body);
    
    std.debug.print("[{s}] Body read success! Length: {}\n", .{pkg, body.len});

    std.debug.print("Body length for {s}: {}\n", .{pkg, body.len});
    if (body.len > 0) {
        std.debug.print("Body prefix: {s}\n", .{body[0..@min(body.len, 50)]});
    }

    // ponytail: use json parsing
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const urls = parsed.value.object.get("urls").?.array;
    var wheel_url: ?[]const u8 = null;
    
    for (urls.items) |u| {
        const ptype = u.object.get("packagetype").?.string;
        if (std.mem.eql(u8, ptype, "bdist_wheel")) {
            wheel_url = u.object.get("url").?.string;
            break;
        }
    }

    const final_url = wheel_url orelse {
        std.debug.print("No wheel found for {s}\n", .{pkg});
        return error.NoWheelFound;
    };

    std.debug.print("Downloading wheel for {s} from {s}\n", .{pkg, final_url});

    var dl_req = try client.request(.GET, try std.Uri.parse(final_url), .{});
    defer dl_req.deinit();
    try dl_req.sendBodiless();
    
    var dl_header_buffer: [8192]u8 = undefined;
    var dl_res = try dl_req.receiveHead(&dl_header_buffer);

    if (dl_res.head.status != .ok) {
        std.debug.print("Failed to download wheel (status {})\n", .{dl_res.head.status});
        return error.DownloadFailed;
    }

    const cache_dir = std.Io.Dir.cwd();
    var dl_transfer_buf: [8192]u8 = undefined;
    const dl_body_reader = dl_res.reader(&dl_transfer_buf);
    const wheel_data = try dl_body_reader.allocRemaining(allocator, .limited(50 * 1024 * 1024));
    defer allocator.free(wheel_data);

    std.debug.print("Extracting {s} ({} bytes)...\n", .{pkg, wheel_data.len});

    const tmp_path = try std.fmt.allocPrint(allocator, ".cache/pyLibrary/{s}.whl", .{pkg});
    defer allocator.free(tmp_path);
    try cache_dir.writeFile(io, .{ .sub_path = tmp_path, .data = wheel_data });
    
    std.debug.print("Successfully streamed {s}.whl to disk!\n", .{pkg});
    
    // Now extract it
    var file = try cache_dir.openFile(io, tmp_path, .{});
    defer file.close(io);
    var file_reader_buf: [8192]u8 = undefined;
    var reader = file.reader(io, &file_reader_buf);
    
    var lib_dir = try cache_dir.openDir(io, ".cache/pyLibrary", .{});
    defer lib_dir.close(io);
    
    std.zip.extract(lib_dir, &reader, .{}) catch |e| {
        std.debug.print("Failed to extract ZIP: {any}\n", .{e});
        return e;
    };
    std.debug.print("Successfully extracted {s} to .cache/pyLibrary!\n", .{pkg});
}
