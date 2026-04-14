const std = @import("std");

// Mengimpor struktur dasar StringValue dari file string.zig yang berada di folder yang sama
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE MODIFIKASI HURUF (CASE CONVERSION)
// ==========================================

// 1. upper(): Mengubah semua menjadi huruf kapital
pub fn upper(self: *const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const new_s = try self.allocator.alloc(u8, s.len);
            for (s, 0..) |c, i| {
                new_s[i] = std.ascii.toUpper(c);
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = new_s } };
        },
        .Unicode => |s| {
            const new_s = try self.allocator.alloc(u16, s.len);
            for (s, 0..) |c, i| {
                // Konversi ASCII dasar di dalam range u16
                new_s[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = new_s } };
        },
    }
}

// 2. lower(): Mengubah semua menjadi huruf kecil
pub fn lower(self: *const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const new_s = try self.allocator.alloc(u8, s.len);
            for (s, 0..) |c, i| {
                new_s[i] = std.ascii.toLower(c);
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = new_s } };
        },
        .Unicode => |s| {
            const new_s = try self.allocator.alloc(u16, s.len);
            for (s, 0..) |c, i| {
                new_s[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = new_s } };
        },
    }
}

// 3. casefold(): Versi lower() yang lebih agresif (untuk MVP, dipetakan ke lower)
pub fn casefold(self: *const StringValue) !StringValue {
    return try lower(self);
}

// 4. capitalize(): Huruf pertama kapital, sisanya huruf kecil
pub fn capitalize(self: *const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const new_s = try self.allocator.alloc(u8, s.len);
            if (s.len > 0) {
                // Karakter pertama dikapitalisasi
                new_s[0] = std.ascii.toUpper(s[0]);
                // Sisanya dipaksa menjadi huruf kecil
                for (s[1..], 1..) |c, i| {
                    new_s[i] = std.ascii.toLower(c);
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = new_s } };
        },
        .Unicode => |s| {
            const new_s = try self.allocator.alloc(u16, s.len);
            if (s.len > 0) {
                new_s[0] = if (s[0] >= 'a' and s[0] <= 'z') s[0] - 32 else s[0];
                for (s[1..], 1..) |c, i| {
                    new_s[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = new_s } };
        },
    }
}

// 5. title(): Setiap awal kata menjadi huruf kapital
pub fn title(self: *const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const new_s = try self.allocator.alloc(u8, s.len);
            var last_is_space = true; // Penanda untuk mendeteksi awal kata baru

            for (s, 0..) |c, i| {
                if (std.ascii.isWhitespace(c)) {
                    new_s[i] = c;
                    last_is_space = true;
                } else {
                    new_s[i] = if (last_is_space) std.ascii.toUpper(c) else std.ascii.toLower(c);
                    last_is_space = false;
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = new_s } };
        },
        .Unicode => |s| {
            const new_s = try self.allocator.alloc(u16, s.len);
            var last_is_space = true;

            for (s, 0..) |c, i| {
                const is_space = (c == ' ' or c == '\t' or c == '\n' or c == '\r');
                if (is_space) {
                    new_s[i] = c;
                    last_is_space = true;
                } else {
                    if (last_is_space) {
                        new_s[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
                    } else {
                        new_s[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                    }
                    last_is_space = false;
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = new_s } };
        },
    }
}

// 6. swapcase(): Membalikkan huruf besar jadi kecil, dan sebaliknya
pub fn swapcase(self: *const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            const new_s = try self.allocator.alloc(u8, s.len);
            for (s, 0..) |c, i| {
                if (std.ascii.isLower(c)) {
                    new_s[i] = std.ascii.toUpper(c);
                } else if (std.ascii.isUpper(c)) {
                    new_s[i] = std.ascii.toLower(c);
                } else {
                    new_s[i] = c;
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = new_s } };
        },
        .Unicode => |s| {
            const new_s = try self.allocator.alloc(u16, s.len);
            for (s, 0..) |c, i| {
                if (c >= 'a' and c <= 'z') {
                    new_s[i] = c - 32;
                } else if (c >= 'A' and c <= 'Z') {
                    new_s[i] = c + 32;
                } else {
                    new_s[i] = c;
                }
            }
            return StringValue{ .allocator = self.allocator, .data = .{ .Unicode = new_s } };
        },
    }
}
