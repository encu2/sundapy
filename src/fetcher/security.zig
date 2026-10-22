const std = @import("std");

pub const MAX_SINGLE_FILE_UNCOMPRESSED: u64 = 1024 * 1024 * 1024; // 1 GB
pub const MAX_ARCHIVE_UNCOMPRESSED: u64 = 4 * 1024 * 1024 * 1024; // 4 GB
pub const MAX_ARCHIVE_ENTRIES: usize = 50_000;
pub const MAX_COMPRESSION_RATIO: u64 = 100;
pub const MAX_DOWNLOAD_BYTES: u64 = 2 * 1024 * 1024 * 1024; // 2 GB

pub const SecurityError = error{
    PathTraversalDetected,
    DecompressionBombDetected,
    FileTooLarge,
    TooManyEntries,
    ArchiveTooLarge,
    SuspiciousEntryForbidden,
    ChecksumMismatch,
    InvalidPackageName,
    InsecureUrlProtocol,
    DownloadTooLarge,
    InvalidIdentifier,
};

pub fn validatePackageName(pkg: []const u8) bool {
    if (pkg.len == 0 or pkg.len > 214) return false;
    const first = pkg[0];
    const last = pkg[pkg.len - 1];
    if (!std.ascii.isAlphanumeric(first) or !std.ascii.isAlphanumeric(last)) return false;

    var prev_dot = false;
    for (pkg) |c| {
        if (std.ascii.isAlphanumeric(c)) {
            prev_dot = false;
        } else if (c == '-' or c == '_') {
            prev_dot = false;
        } else if (c == '.') {
            if (prev_dot) return false;
            prev_dot = true;
        } else {
            return false;
        }
    }
    return true;
}

pub fn sanitizeEntryPath(dest_buf: []u8, raw_path: []const u8) SecurityError![]const u8 {
    if (raw_path.len == 0 or raw_path.len > dest_buf.len) return error.PathTraversalDetected;
    if (raw_path[0] == '/' or raw_path[0] == '\\') return error.PathTraversalDetected;
    if (std.mem.indexOfScalar(u8, raw_path, 0) != null) return error.PathTraversalDetected;
    if (std.mem.indexOfScalar(u8, raw_path, ':') != null) return error.PathTraversalDetected;

    var out_len: usize = 0;
    var i: usize = 0;
    const is_dir = raw_path[raw_path.len - 1] == '/' or raw_path[raw_path.len - 1] == '\\';

    while (i < raw_path.len) {
        while (i < raw_path.len and (raw_path[i] == '/' or raw_path[i] == '\\')) : (i += 1) {}
        if (i >= raw_path.len) break;
        const start = i;
        while (i < raw_path.len and raw_path[i] != '/' and raw_path[i] != '\\') : (i += 1) {}
        const segment = raw_path[start..i];

        if (std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) return error.PathTraversalDetected;

        if (out_len > 0 and dest_buf[out_len - 1] != '/') {
            if (out_len >= dest_buf.len) return error.PathTraversalDetected;
            dest_buf[out_len] = '/';
            out_len += 1;
        }
        if (out_len + segment.len > dest_buf.len) return error.PathTraversalDetected;
        @memcpy(dest_buf[out_len..][0..segment.len], segment);
        out_len += segment.len;
    }

    if (out_len == 0) return error.PathTraversalDetected;
    if (is_dir and dest_buf[out_len - 1] != '/') {
        if (out_len >= dest_buf.len) return error.PathTraversalDetected;
        dest_buf[out_len] = '/';
        out_len += 1;
    }
    return dest_buf[0..out_len];
}

pub fn validateEntrySafety(uncompressed_size: u64, compressed_size: u64, external_attrs: u32) SecurityError!void {
    const posix_mode = (external_attrs >> 16) & 0o170000;
    if (posix_mode == 0o120000 or posix_mode == 0o010000 or posix_mode == 0o060000 or posix_mode == 0o020000 or posix_mode == 0o140000) {
        return error.SuspiciousEntryForbidden;
    }

    if (uncompressed_size > MAX_SINGLE_FILE_UNCOMPRESSED) {
        return error.FileTooLarge;
    }

    if (uncompressed_size > 10 * 1024 * 1024) {
        if (compressed_size == 0) return error.DecompressionBombDetected;
        if (uncompressed_size / compressed_size > MAX_COMPRESSION_RATIO) {
            return error.DecompressionBombDetected;
        }
    }
}

pub fn validateArchiveLimits(entry_count: usize, total_uncompressed: u64) SecurityError!void {
    if (entry_count > MAX_ARCHIVE_ENTRIES) return error.TooManyEntries;
    if (total_uncompressed > MAX_ARCHIVE_UNCOMPRESSED) return error.ArchiveTooLarge;
}

pub fn verifySha256(expected_hex: []const u8, actual_bytes: [32]u8) bool {
    const actual_hex = std.fmt.bytesToHex(actual_bytes, .lower);
    return std.ascii.eqlIgnoreCase(&actual_hex, expected_hex);
}

pub fn isSafeHttpsUrl(url: []const u8) bool {
    if (!std.mem.startsWith(u8, url, "https://")) return false;
    if (url.len < 10) return false;
    for (url) |c| {
        if (c <= 0x20 or c >= 0x7F) return false;
    }
    return true;
}

pub fn validateIdentifier(id: []const u8) bool {
    if (id.len == 0 or id.len > 256) return false;
    for (id) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') {
            return false;
        }
    }
    return true;
}

test "validatePackageName" {
    try std.testing.expect(validatePackageName("numpy"));
    try std.testing.expect(validatePackageName("requests-toolbelt"));
    try std.testing.expect(validatePackageName("typing_extensions"));
    try std.testing.expect(validatePackageName("zope.interface"));
    try std.testing.expect(!validatePackageName("../malicious"));
    try std.testing.expect(!validatePackageName("-numpy"));
    try std.testing.expect(!validatePackageName("numpy-"));
    try std.testing.expect(!validatePackageName("foo..bar"));
    try std.testing.expect(!validatePackageName("pkg; rm -rf /"));
    try std.testing.expect(!validatePackageName(""));
}

test "sanitizeEntryPath" {
    var buf: [512]u8 = undefined;
    const ok1 = try sanitizeEntryPath(&buf, "requests/__init__.py");
    try std.testing.expectEqualStrings("requests/__init__.py", ok1);

    const ok2 = try sanitizeEntryPath(&buf, "foo//bar/");
    try std.testing.expectEqualStrings("foo/bar/", ok2);

    try std.testing.expectError(error.PathTraversalDetected, sanitizeEntryPath(&buf, "../../etc/passwd"));
    try std.testing.expectError(error.PathTraversalDetected, sanitizeEntryPath(&buf, "/etc/shadow"));
    try std.testing.expectError(error.PathTraversalDetected, sanitizeEntryPath(&buf, "foo/../bar"));
    try std.testing.expectError(error.PathTraversalDetected, sanitizeEntryPath(&buf, "C:\\Windows\\system.ini"));
    try std.testing.expectError(error.PathTraversalDetected, sanitizeEntryPath(&buf, ""));
}

test "validateEntrySafety" {
    try validateEntrySafety(1024, 512, 0o100644 << 16);
    try std.testing.expectError(error.SuspiciousEntryForbidden, validateEntrySafety(1024, 512, 0o120777 << 16));
    try std.testing.expectError(error.FileTooLarge, validateEntrySafety(MAX_SINGLE_FILE_UNCOMPRESSED + 1, 1000, 0));
    try std.testing.expectError(error.DecompressionBombDetected, validateEntrySafety(50 * 1024 * 1024, 100, 0));
}

test "verifySha256" {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("sundapy-security-test");
    var digest: [32]u8 = undefined;
    hasher.final(&digest);

    const hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expect(verifySha256(&hex, digest));
    try std.testing.expect(!verifySha256("0000000000000000000000000000000000000000000000000000000000000000", digest));
}
