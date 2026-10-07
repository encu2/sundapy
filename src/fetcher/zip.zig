const std = @import("std");

pub fn extractEntry(
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

pub fn extractZipFile(io: std.Io, zip_path: []const u8, dest_dir_path: []const u8) !void {
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

pub fn checkExtractedHasSo(allocator: std.mem.Allocator, io: std.Io, base_dir: []const u8, pkg: []const u8) bool {
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

pub fn scanDirForSo(allocator: std.mem.Allocator, io: std.Io, root_dir: std.Io.Dir) bool {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var stack: std.ArrayList([]const u8) = .empty;

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
