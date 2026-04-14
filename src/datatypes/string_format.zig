const std = @import("std");
const string = @import("string.zig");
const StringValue = string.StringValue;

// ==========================================
// METODE PEMFORMATAN & PERATAAN
// ==========================================

// 1. zfill(): Mengisi sebelah kiri dengan angka '0' hingga mencapai target panjang (width)
pub fn zfill(self: *const StringValue, width: usize) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len >= width) return self.*; // Tidak perlu dipanjangkan

            const pad_len = width - s.len;
            var buf = try self.allocator.alloc(u8, width);

            @memset(buf[0..pad_len], '0'); // Isi bagian awal dengan '0'
            @memcpy(buf[pad_len..], s); // Salin string asli setelahnya

            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = buf } };
        },
        .Unicode => {
            return error.NotImplementedYet; // Membutuhkan memset untuk array u16
        },
    }
}

// 2. ljust(): Rata kiri, mengisi sisa ruang di sebelah kanan dengan karakter pengisi (default ' ')
pub fn ljust(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len >= width) return self.*;

            var buf = try self.allocator.alloc(u8, width);
            @memcpy(buf[0..s.len], s);
            @memset(buf[s.len..], fillchar);

            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = buf } };
        },
        .Unicode => return error.NotImplementedYet,
    }
}

// 3. rjust(): Rata kanan, mengisi sisa ruang di sebelah kiri dengan karakter pengisi
pub fn rjust(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len >= width) return self.*;

            const pad_len = width - s.len;
            var buf = try self.allocator.alloc(u8, width);
            @memset(buf[0..pad_len], fillchar);
            @memcpy(buf[pad_len..], s);

            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = buf } };
        },
        .Unicode => return error.NotImplementedYet,
    }
}

// 4. center(): Teks di tengah, mengisi sisa ruang di kiri dan kanan dengan seimbang
// ... (kode awal tetap sama)

// Pada fungsi center():
pub fn center(self: *const StringValue, width: usize, fillchar: u8) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            if (s.len >= width) return self.*;

            const pad_total = width - s.len;
            const pad_left = pad_total / 2;
            // HAPUS BARIS INI KARENA TIDAK DIPAKAI:
            // const pad_right = pad_total - pad_left;

            var buf = try self.allocator.alloc(u8, width);
            @memset(buf[0..pad_left], fillchar);
            @memcpy(buf[pad_left .. pad_left + s.len], s);
            @memset(buf[pad_left + s.len ..], fillchar);

            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = buf } };
        },
        .Unicode => return error.NotImplementedYet,
    }
}

// Pada fungsi expandtabs():
pub fn expandtabs(self: *const StringValue, tabsize: usize) !StringValue {
    switch (self.data) {
        .Ascii => |s| {
            // UBAH 'var' MENJADI 'const' KARENA POINTERNYA TIDAK BERUBAH:
            const spaces = try self.allocator.alloc(u8, tabsize);
            @memset(spaces, ' ');

            const replaced = try std.mem.replaceAlloc(self.allocator, u8, s, "\t", spaces);
            return StringValue{ .allocator = self.allocator, .data = .{ .Ascii = replaced } };
        },
        .Unicode => return error.NotImplementedYet,
    }
}

// Pada fungsi format & format_map (Bagian paling bawah):
// TAMBAHKAN `_ = self;` UNTUK MENGABAIKAN PARAMETER SECARA EKSPLISIT
pub fn format(self: *const StringValue) !void {
    _ = self;
    return error.RequireInterpreterAST;
}
pub fn format_map(self: *const StringValue) !void {
    _ = self;
    return error.RequireInterpreterAST;
}
