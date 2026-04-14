const std = @import("std");

// ==========================================
// 1. DEFINISI TIPE ANGKA (Type Annotations)
// ==========================================
// Enum ini digunakan oleh Parser ketika membaca anotasi tipe (strict typing).
pub const NumberType = enum {
    // Default Dynamics
    Int, // Default python-like 'int'
    Float, // Default python-like 'float'

    // Signed Integers
    i8,
    i16,
    i32,
    i64,
    isize,

    // Unsigned Integers
    u8,
    u16,
    u32,
    u64,
    usize,

    // Khusus Arbitrary Bit-Width yang diizinkan
    i256,
    u256,
    i512,
    u512,
    i1024,
    u1024,

    // Floating Points
    f16,
    f32,
    f64,
    f80,
    f128,
};

// ==========================================
// 2. PENYIMPANAN NILAI MEMORI (Value Container)
// ==========================================
// Tagged Union ini menyimpan nilai aktual di memori Zig.
pub const NumberValue = union(NumberType) {
    // Default Dynamics (Sesuai instruksi)
    Int: isize,
    Float: f64,

    // Signed Integers
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    isize: isize,

    // Unsigned Integers
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    usize: usize,

    // Khusus Arbitrary Bit-Width yang diizinkan
    i256: i256,
    u256: u256,
    i512: i512,
    u512: u512,
    i1024: i1024,
    u1024: u1024,

    // Floating Points
    f16: f16,
    f32: f32,
    f64: f64,
    f80: f80,
    f128: f128,

    // ==========================================
    // 3. FUNGSI PEMBANTU (Interpreter Utils)
    // ==========================================

    // Inisialisasi default dynamic int (Python 'int')
    pub fn initDynamicInt(val: isize) NumberValue {
        return NumberValue{ .Int = val };
    }

    // Inisialisasi default dynamic float (Python 'float')
    pub fn initDynamicFloat(val: f64) NumberValue {
        return NumberValue{ .Float = val };
    }
};
