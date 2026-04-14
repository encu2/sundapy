const std = @import("std");
const testing = std.testing;

// Import modul-modul yang sudah kita buat
const number = @import("datatypes/number.zig");
const string = @import("datatypes/string.zig");
const scanner = @import("lexer/scanner_string.zig");

// ==========================================
// 1. TEST CASE: DATATYPE NUMBER
// ==========================================
test "Number: Inisialisasi Dynamic Int dan Float" {
    // Test Integer Dinamis (isize)
    const var_int = number.NumberValue.initDynamicInt(1000);
    try testing.expect(var_int == .Int);
    try testing.expectEqual(@as(isize, 1000), var_int.Int);

    // Test Float Dinamis (f64)
    const var_float = number.NumberValue.initDynamicFloat(3.14);
    try testing.expect(var_float == .Float);
    try testing.expectEqual(@as(f64, 3.14), var_float.Float);
}

// ==========================================
// 2. TEST CASE: LEXER SCANNER (STRING PREFIX)
// ==========================================
test "Scanner: Deteksi String Tanpa Prefix" {
    const source = "\"halo dunia\"";
    const token = try scanner.scanStringLiteral(source, 0);

    try testing.expect(token.prefix == .None);
    try testing.expectEqualStrings("halo dunia", token.raw_content);
    try testing.expectEqual(@as(u8, '"'), token.quote_char);
}

test "Scanner: Deteksi f-string (Format)" {
    const source = "f'halo {nama}'";
    const token = try scanner.scanStringLiteral(source, 0);

    try testing.expect(token.prefix == .Format);
    try testing.expectEqualStrings("halo {nama}", token.raw_content);
    try testing.expectEqual(@as(u8, '\''), token.quote_char);
}

test "Scanner: Deteksi r-string dan rb-string (Raw & Byte)" {
    const source_r = "r\"C:\\folder\\baru\"";
    const token_r = try scanner.scanStringLiteral(source_r, 0);
    try testing.expect(token_r.prefix == .Raw);
    try testing.expectEqualStrings("C:\\folder\\baru", token_r.raw_content);

    const source_rb = "rb\"data\"";
    const token_rb = try scanner.scanStringLiteral(source_rb, 0);
    try testing.expect(token_rb.prefix == .RawByte);
    try testing.expectEqualStrings("data", token_rb.raw_content);
}

// ==========================================
// 3. TEST CASE: DATATYPE STRING (MEMORI)
// ==========================================
test "String: Deteksi Otomatis Ascii vs Unicode" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Teks murni ASCII
    const str_ascii = try string.StringValue.init(allocator, "Biasa");
    try testing.expect(str_ascii.data == .Ascii);

    // Teks mengandung Emoji/Unicode (> 127 byte)
    const str_unicode = try string.StringValue.init(allocator, "Halo 🚀");
    try testing.expect(str_unicode.data == .Unicode);
}

// ==========================================
// 4. TEST CASE: DATATYPE STRING (METHODS)
// ==========================================
test "String Methods: Manipulasi dan Validasi" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Persiapan data
    const teks_kotor = try string.StringValue.init(allocator, "   halo zig   ");
    const angka_str = try string.StringValue.init(allocator, "1024");

    // Test strip() -> Menghilangkan spasi
    const teks_bersih = teks_kotor.strip();
    try testing.expectEqualStrings("halo zig", teks_bersih.data.Ascii);

    // Test upper() -> Mengubah ke huruf kapital
    const teks_kapital = try teks_bersih.upper();
    try testing.expectEqualStrings("HALO ZIG", teks_kapital.data.Ascii);

    // Test startswith() -> Mengecek awalan
    const is_start_halo = try teks_bersih.startswith("halo");
    try testing.expect(is_start_halo == true);

    // Test isdigit() -> Mengecek apakah murni angka
    try testing.expect(angka_str.isdigit() == true);
    try testing.expect(teks_kotor.isdigit() == false);
}

test "String Methods: Pemecahan (Split)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const teks_csv = try string.StringValue.init(allocator, "apel,jeruk,mangga");
    const hasil_split = try teks_csv.split(",");

    try testing.expectEqual(@as(usize, 3), hasil_split.len);
    try testing.expectEqualStrings("apel", hasil_split[0].data.Ascii);
    try testing.expectEqualStrings("jeruk", hasil_split[1].data.Ascii);
    try testing.expectEqualStrings("mangga", hasil_split[2].data.Ascii);
}
