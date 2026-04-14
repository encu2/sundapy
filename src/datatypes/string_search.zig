const std = @import("std");
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE PENCARIAN & PENGHITUNGAN (SEARCH & COUNT)
// ==========================================

// 1. find(): Mengembalikan indeks pertama, atau -1 jika gagal
pub fn find(self: *const StringValue, sub: []const u8) !isize {
    switch (self.data) {
        .Ascii => |s| {
            if (std.mem.indexOf(u8, s, sub)) |idx| {
                return @as(isize, @intCast(idx));
            }
            return -1;
        },
        .Unicode => |s| {
            const sub_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, sub);
            if (std.mem.indexOf(u16, s, sub_u16)) |idx| {
                return @as(isize, @intCast(idx));
            }
            return -1;
        },
    }
}

// 2. rfind(): Mengembalikan indeks dari belakang, atau -1 jika gagal
pub fn rfind(self: *const StringValue, sub: []const u8) !isize {
    switch (self.data) {
        .Ascii => |s| {
            if (std.mem.lastIndexOf(u8, s, sub)) |idx| {
                return @as(isize, @intCast(idx));
            }
            return -1;
        },
        .Unicode => |s| {
            const sub_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, sub);
            if (std.mem.lastIndexOf(u16, s, sub_u16)) |idx| {
                return @as(isize, @intCast(idx));
            }
            return -1;
        },
    }
}

// 3. index(): Sama seperti find(), tapi melempar error (ValueError di Python)
pub fn index(self: *const StringValue, sub: []const u8) !usize {
    const idx = try find(self, sub);
    if (idx == -1) {
        return error.ValueError; // Eksekutor (PVM) kita akan menangkap ini sebagai Exception
    }
    // Konversi isize kembali ke usize (karena dipastikan tidak minus)
    return @as(usize, @intCast(idx));
}

// 4. rindex(): Sama seperti rfind(), tapi melempar error jika gagal
pub fn rindex(self: *const StringValue, sub: []const u8) !usize {
    const idx = try rfind(self, sub);
    if (idx == -1) {
        return error.ValueError;
    }
    return @as(usize, @intCast(idx));
}

// 5. count(): Menghitung berapa kali teks muncul
pub fn count(self: *const StringValue, sub: []const u8) !usize {
    switch (self.data) {
        .Ascii => |s| {
            return std.mem.count(u8, s, sub);
        },
        .Unicode => |s| {
            const sub_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, sub);
            return std.mem.count(u16, s, sub_u16);
        },
    }
}
