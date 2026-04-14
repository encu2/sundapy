const std = @import("std");

// Import modul-modul internal proyek pythonZigZag
const number = @import("datatypes/number.zig");
const string = @import("datatypes/string.zig");
const scanner = @import("lexer/scanner_string.zig");

pub fn main() !void {
    // 1. SETUP MEMORY SCOPE
    // Kita menggunakan ArenaAllocator agar ketika fungsi main() selesai,
    // seluruh memori yang digunakan oleh string dan angka akan dibersihkan
    // secara otomatis (Zero Memory Leak).
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // ==========================================
    // SIMULASI ALUR KERJA INTERPRETER
    // ==========================================
    
    std.debug.print("\n=== PYTHON ZIGZAG INTERPRETER (MVP TEST) ===\n\n", .{});

    // TAHAP 1: KODE SUMBER MENTAH (SOURCE CODE)
    // Anggap ini adalah kode Python yang dibaca dari sebuah file .py
    const source_code = "f'halo zig 0.15'";
    std.debug.print("[Tahap 1] Kode Sumber Mentah : {s}\n", .{source_code});

    // TAHAP 2: LEXER SCANNING
    // Lexer membaca kode mentah dan mengekstrak token serta prefix-nya
    const token = try scanner.scanStringLiteral(source_code, 0);
    std.debug.print("[Tahap 2] Lexer Tokenizer    :\n", .{});
    std.debug.print("          - Prefix : {s}\n", .{@tagName(token.prefix)});
    std.debug.print("          - Teks   : {s}\n", .{token.raw_content});
    std.debug.print("          - Kutip  : {c}\n", .{token.quote_char});

    // TAHAP 3: ALOKASI RUNTIME OBJECT (DATATYPES)
    // Parser memerintahkan Datatypes untuk membuat objek di memori 
    // berdasarkan hasil temuan Lexer.
    const string_obj = try string.StringValue.init(allocator, token.raw_content);
    std.debug.print("[Tahap 3] Memori Terbentuk   : Object(String, mem: {s})\n", .{@tagName(string_obj.data)});

    // TAHAP 4: EKSEKUSI PYTHON METHOD
    // Mensimulasikan pemanggilan method .upper() dan .replace()
    std.debug.print("[Tahap 4] Eksekusi Method    :\n", .{});
    
    // Test .upper()
    const str_upper = try string_obj.upper();
    std.debug.print("          - .upper()   -> '{s}'\n", .{str_upper.data.Ascii});

    // Test .replace()
    const str_replaced = try string_obj.replace("zig 0.15", "python 3.12");
    std.debug.print("          - .replace() -> '{s}'\n", .{str_replaced.data.Ascii});

    // ==========================================
    // TEST NOMOR (NUMBER DATATYPES)
    // ==========================================
    std.debug.print("\n=== DATATYPES NUMBER TEST ===\n", .{});
    
    // Inisialisasi Dinamis
    const num_int = number.NumberValue.initDynamicInt(2026);
    const num_float = number.NumberValue.initDynamicFloat(3.14159);
    
    std.debug.print("Int Dinamis   : {d} (Type: {s})\n", .{num_int.Int, @tagName(num_int)});
    std.debug.print("Float Dinamis : {d} (Type: {s})\n\n", .{num_float.Float, @tagName(num_float)});
}