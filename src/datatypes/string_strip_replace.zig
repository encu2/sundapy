const std = @import("std");
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE PEMOTONGAN & PENGGANTIAN
// ==========================================

// 1. strip(): Menghapus spasi di kiri dan kanan
pub fn strip(self: *const StringValue) StringValue {
    switch (self.data) {
        .Ascii => |s| {
            // std.mem.trim hanya memotong slice, tidak ada alokasi baru
            const trimmed = std.mem.trim(u8, s, " \t\r\n");
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = trimmed } };
        },
        .Unicode => |s| {
            var start: usize = 0;
            var end: usize = s.len;
            while (start < end and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n' or s[start] == '\r')) : (start += 1) {}
            while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\n' or s[end - 1] == '\r')) : (end -= 1) {}
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = s[start..end] } };
        },
    }
}

// 2. lstrip(): Menghapus spasi hanya di kiri
pub fn lstrip(self: *const StringValue) StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const trimmed = std.mem.trimLeft(u8, s, " \t\r\n");
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = trimmed } };
        },
        .Unicode => |s| {
            var start: usize = 0;
            while (start < s.len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n' or s[start] == '\r')) : (start += 1) {}
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = s[start..] } };
        },
    }
}

// 3. rstrip(): Menghapus spasi hanya di kanan
pub fn rstrip(self: *const StringValue) StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const trimmed = std.mem.trimRight(u8, s, " \t\r\n");
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = trimmed } };
        },
        .Unicode => |s| {
            var end: usize = s.len;
            while (end > 0 and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\n' or s[end - 1] == '\r')) : (end -= 1) {}
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = s[0..end] } };
        },
    }
}

// 4. removeprefix(): Menghapus teks awalan jika cocok
pub fn removeprefix(self: *const StringValue, prefix: []const u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (std.mem.startsWith(u8, s, prefix)) {
                return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = s[prefix.len..] } };
            }
            return self.*; // Kembalikan copy struct aslinya jika tidak cocok
        },
        .Unicode => |s| {
            const prefix_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, prefix);
            if (std.mem.startsWith(u16, s, prefix_u16)) {
                return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = s[prefix_u16.len..] } };
            }
            return self.*;
        },
    }
}

// 5. removesuffix(): Menghapus teks akhiran jika cocok
pub fn removesuffix(self: *const StringValue, suffix: []const u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (std.mem.endsWith(u8, s, suffix)) {
                return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = s[0 .. s.len - suffix.len] } };
            }
            return self.*;
        },
        .Unicode => |s| {
            const suffix_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, suffix);
            if (std.mem.endsWith(u16, s, suffix_u16)) {
                return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = s[0 .. s.len - suffix_u16.len] } };
            }
            return self.*;
        },
    }
}

// 6. replace(): Mengganti teks lama dengan teks baru (butuh alokasi)
pub fn replace(self: *const StringValue, old: []const u8, new: []const u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const replaced = try std.mem.replaceAlloc(self.allocator, u8, s, old, new);
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = replaced } };
        },
        .Unicode => |s| {
            const old_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, old);
            const new_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, new);
            const replaced = try std.mem.replaceAlloc(self.allocator, u16, s, old_u16, new_u16);
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = replaced } };
        },
    }
}

// Stub untuk metode yang membutuhkan objek Dictionary/Hash Map di masa depan
pub fn maketrans(self: *const StringValue) !void {
    _ = self; // Tambahkan ini
    return error.RequireDictionaryType;
}

pub fn translate(self: *const StringValue) !void {
    _ = self; // Tambahkan ini
    return error.RequireDictionaryType;
}
