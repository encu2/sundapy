const std = @import("std");
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE VALIDASI BOOLEAN (TRUE/FALSE)
// ==========================================

pub fn startswith(self: *const StringValue, prefix: []const u8) !bool {
    switch (self.data) {
        .Ascii => |s| return std.mem.startsWith(u8, s, prefix),
        .Unicode => |s| {
            // Kita harus mengubah prefix u8 menjadi u16 agar memori bisa dibandingkan apple-to-apple
            const prefix_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, prefix);
            return std.mem.startsWith(u16, s, prefix_u16);
        },
    }
}

pub fn endswith(self: *const StringValue, suffix: []const u8) !bool {
    switch (self.data) {
        .Ascii => |s| return std.mem.endsWith(u8, s, suffix),
        .Unicode => |s| {
            const suffix_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, suffix);
            return std.mem.endsWith(u16, s, suffix_u16);
        },
    }
}

pub fn isalnum(self: *const StringValue) bool {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (!std.ascii.isAlphanumeric(c)) return false;
            }
            return true;
        },
        .Unicode => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                const is_ascii_alnum = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9');
                if (!is_ascii_alnum) return false; // MVP: Unicode penuh butuh tabel yang sangat besar
            }
            return true;
        },
    }
}

pub fn isalpha(self: *const StringValue) bool {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (!std.ascii.isAlphabetic(c)) return false;
            }
            return true;
        },
        .Unicode => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                const is_ascii_alpha = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z');
                if (!is_ascii_alpha) return false;
            }
            return true;
        },
    }
}

// isascii langsung dieksekusi secara native berkat arsitektur Tagged Union kita!
pub fn isascii(self: *const StringValue) bool {
    return self.data == .Ascii;
}

pub fn isdigit(self: *const StringValue) bool {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (!std.ascii.isDigit(c)) return false;
            }
            return true;
        },
        .Unicode => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (c < '0' or c > '9') return false;
            }
            return true;
        },
    }
}

// isdecimal dan isnumeric dipetakan ke isdigit untuk versi MVP ini
pub fn isdecimal(self: *const StringValue) bool {
    return isdigit(self);
}
pub fn isnumeric(self: *const StringValue) bool {
    return isdigit(self);
}

pub fn islower(self: *const StringValue) bool {
    var has_alpha = false;
    switch (self.data) {
        .Ascii => |s| {
            for (s) |c| {
                if (std.ascii.isUpper(c)) return false;
                if (std.ascii.isLower(c)) has_alpha = true;
            }
        },
        .Unicode => |s| {
            for (s) |c| {
                if (c >= 'A' and c <= 'Z') return false;
                if (c >= 'a' and c <= 'z') has_alpha = true;
            }
        },
    }
    return has_alpha; // Harus ada minimal 1 huruf
}

pub fn isupper(self: *const StringValue) bool {
    var has_alpha = false;
    switch (self.data) {
        .Ascii => |s| {
            for (s) |c| {
                if (std.ascii.isLower(c)) return false;
                if (std.ascii.isUpper(c)) has_alpha = true;
            }
        },
        .Unicode => |s| {
            for (s) |c| {
                if (c >= 'a' and c <= 'z') return false;
                if (c >= 'A' and c <= 'Z') has_alpha = true;
            }
        },
    }
    return has_alpha;
}

pub fn isspace(self: *const StringValue) bool {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (!std.ascii.isWhitespace(c)) return false;
            }
            return true;
        },
        .Unicode => |s| {
            if (s.len == 0) return false;
            for (s) |c| {
                if (c != ' ' and c != '\t' and c != '\n' and c != '\r') return false;
            }
            return true;
        },
    }
}

pub fn isprintable(self: *const StringValue) bool {
    switch (self.data) {
        .Ascii => |s| {
            for (s) |c| {
                if (std.ascii.isControl(c)) return false;
            }
            return true;
        },
        .Unicode => return true, // Disederhanakan: anggap sebagian besar u16 bisa di-print
    }
}
