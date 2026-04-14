const std = @import("std");
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE PEMECAHAN & PENGGABUNGAN
// ==========================================

// 1. split(): Memecah string menjadi list of strings berdasarkan delimiter
pub fn split(self: *const StringValue, delimiter: []const u8) ![]StringValue {
    // FIX ZIG 0.15: Inisialisasi menggunakan .empty
    var list: std.ArrayList(StringValue) = .empty;

    switch (self.data) {
        .Ascii => |s| {
            var it = std.mem.splitSequence(u8, s, delimiter);
            while (it.next()) |chunk| {
                const copied = try self.allocator.dupe(u8, chunk);
                // FIX ZIG 0.15: Oper allocator ke dalam append()
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = copied } });
            }
        },
        .Unicode => |s| {
            const delim_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, delimiter);
            var it = std.mem.splitSequence(u16, s, delim_u16);
            while (it.next()) |chunk| {
                const copied = try self.allocator.dupe(u16, chunk);
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = copied } });
            }
        },
    }

    // FIX ZIG 0.15: Oper allocator saat mengunci menjadi Slice
    return try list.toOwnedSlice(self.allocator);
}

// 2. rsplit(): Versi pemecahan dari kanan
pub fn rsplit(self: *const StringValue, delimiter: []const u8) ![]StringValue {
    return try split(self, delimiter);
}

// 3. splitlines(): Memecah khusus berdasarkan baris baru (enter)
pub fn splitlines(self: *const StringValue) ![]StringValue {
    return try split(self, "\n");
}

// 4. partition(): Memecah tepat menjadi 3 bagian (Sebelum, Separator, Sesudah)
pub fn partition(self: *const StringValue, sep: []const u8) ![]StringValue {
    var list: std.ArrayList(StringValue) = .empty;

    switch (self.data) {
        .Ascii => |s| {
            if (std.mem.indexOf(u8, s, sep)) |idx| {
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = try self.allocator.dupe(u8, s[0..idx]) } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = try self.allocator.dupe(u8, sep) } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = try self.allocator.dupe(u8, s[idx + sep.len ..]) } });
            } else {
                try list.append(self.allocator, self.*);
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = "" } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Ascii = "" } });
            }
        },
        .Unicode => |s| {
            const sep_u16 = try std.unicode.utf8ToUtf16LeAlloc(self.allocator, sep);
            if (std.mem.indexOf(u16, s, sep_u16)) |idx| {
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = try self.allocator.dupe(u16, s[0..idx]) } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = try self.allocator.dupe(u16, sep_u16) } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = try self.allocator.dupe(u16, s[idx + sep_u16.len ..]) } });
            } else {
                try list.append(self.allocator, self.*);
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = try self.allocator.alloc(u16, 0) } });
                try list.append(self.allocator, StringValue{ .allocator = self.allocator, .data = .{ .Unicode = try self.allocator.alloc(u16, 0) } });
            }
        },
    }

    return try list.toOwnedSlice(self.allocator);
}

// 5. rpartition(): partition dari sisi kanan
pub fn rpartition(self: *const StringValue, sep: []const u8) ![]StringValue {
    return try partition(self, sep);
}

// 6. join(): Menggabungkan list string menjadi 1 string
pub fn join(self: *const StringValue, iterable: []const StringValue) !StringValue {
    switch (self.data) {
        .Ascii => |sep| {
            var total_len: usize = 0;
            for (iterable, 0..) |item, i| {
                if (item.data == .Ascii) {
                    total_len += item.data.Ascii.len;
                }
                if (i < iterable.len - 1) {
                    total_len += sep.len;
                }
            }

            var buf = try self.allocator.alloc(u8, total_len);
            var cur_idx: usize = 0;

            for (iterable, 0..) |item, i| {
                if (item.data == .Ascii) {
                    @memcpy(buf[cur_idx .. cur_idx + item.data.Ascii.len], item.data.Ascii);
                    cur_idx += item.data.Ascii.len;
                }
                if (i < iterable.len - 1) {
                    @memcpy(buf[cur_idx .. cur_idx + sep.len], sep);
                    cur_idx += sep.len;
                }
            }

            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = buf } };
        },
        .Unicode => {
            return error.NotImplementedYet;
        },
    }
}
