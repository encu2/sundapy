const std = @import("std");

// ==========================================
// 1. DEFINISI TOKEN PREFIX
// ==========================================
pub const StringPrefix = enum {
    None, // "" atau ''
    Format, // f"" atau F""
    Raw, // r"" atau R""
    Byte, // b"" atau B""
    Unicode, // u"" atau U""
    RawByte, // rb"", br"", RB"", dll.
};

// Struktur hasil pindaian Lexer untuk sebuah String
pub const StringToken = struct {
    prefix: StringPrefix,
    raw_content: []const u8, // Isi mentah di dalam tanda kutip
    quote_char: u8, // Menyimpan apakah memakai ' atau "
};

// ==========================================
// 2. LOGIKA PEMINDAIAN (SCANNER)
// ==========================================
// Fungsi ini akan dipanggil oleh Lexer utama ketika menemui karakter
// yang berpotensi menjadi awal mula sebuah string.
pub fn scanStringLiteral(source: []const u8, start_idx: usize) !StringToken {
    // Variabel ini tidak pernah dimutasi, jadi wajib const di Zig
    const current = start_idx;

    if (current >= source.len) return error.EndOfFile;

    const c1 = source[current];

    // Pengecekan kutip langsung (tanpa prefix)
    if (c1 == '"' or c1 == '\'') {
        return try consumeString(source, current, current, .None);
    }

    // Pengecekan 1-huruf prefix (f, r, b, u)
    if (current + 1 < source.len) {
        const c2 = source[current + 1];
        if (c2 == '"' or c2 == '\'') {
            const prefix: StringPrefix = switch (c1) {
                'f', 'F' => .Format,
                'r', 'R' => .Raw,
                'b', 'B' => .Byte,
                'u', 'U' => .Unicode,
                else => .None,
            };

            if (prefix != .None) {
                return try consumeString(source, current + 1, current + 1, prefix);
            }
        }
    }

    // Pengecekan 2-huruf prefix (rb, br)
    if (current + 2 < source.len) {
        const c2 = source[current + 1];
        const c3 = source[current + 2];

        if (c3 == '"' or c3 == '\'') {
            const is_rb = (c1 == 'r' or c1 == 'R') and (c2 == 'b' or c2 == 'B');
            const is_br = (c1 == 'b' or c1 == 'B') and (c2 == 'r' or c2 == 'R');

            if (is_rb or is_br) {
                return try consumeString(source, current + 2, current + 2, .RawByte);
            }
        }
    }

    return error.NotAString; // Bukan permulaan string yang valid
}

// ==========================================
// 3. FUNGSI INTERNAL PENGURAS TEKS (CONSUMER)
// ==========================================
// Fungsi ini bertugas berjalan dari tanda kutip pembuka hingga kutip penutup,
// sambil mengabaikan karakter yang di-escape (seperti \")
fn consumeString(source: []const u8, quote_idx: usize, start_content: usize, prefix: StringPrefix) !StringToken {
    const quote_char = source[quote_idx];
    var current = start_content + 1; // Mulai setelah tanda kutip pembuka

    while (current < source.len) {
        const c = source[current];

        // Jika ketemu tanda backslash (\), lompati satu karakter berikutnya
        // agar tanda kutip di dalam string tidak dianggap sebagai penutup.
        // Pengecualian: Mode Raw dan RawByte akan membaca backslash sebagai teks biasa.
        if (c == '\\' and prefix != .Raw and prefix != .RawByte) {
            current += 2;
            continue;
        }

        // Jika ketemu tanda kutip penutup yang cocok
        if (c == quote_char) {
            return StringToken{
                .prefix = prefix,
                // Kita ambil slice memori dari setelah kutip awal sampai sebelum kutip akhir
                .raw_content = source[start_content + 1 .. current],
                .quote_char = quote_char,
            };
        }

        current += 1;
    }

    // Jika sampai akhir file tidak ada kutip penutup
    return error.UnterminatedString;
}
