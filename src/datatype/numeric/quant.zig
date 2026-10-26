const std = @import("std");

// ============================================================================
// Pure Bit-Conversion Quantization Primitives for Core GpuBuffer Runtime
// Formats: FP16 (IEEE-754), BF16, FP8 (E4M3/E5M2), FP4 (E2M1)
// ============================================================================

pub inline fn f32_to_f16(val: f32) u16 {
    const h: f16 = @floatCast(val);
    return @bitCast(h);
}

pub inline fn f16_to_f32(raw: u16) f32 {
    const h: f16 = @bitCast(raw);
    return @floatCast(h);
}

pub inline fn f32_to_bf16(val: f32) u16 {
    const u: u32 = @bitCast(val);
    const lsb = (u >> 16) & 1;
    const round_bias = @as(u32, 0x7FFF) + lsb;
    const rounded = u +% round_bias;
    return @truncate(rounded >> 16);
}

pub inline fn bf16_to_f32(raw: u16) f32 {
    const u: u32 = @as(u32, raw) << 16;
    return @bitCast(u);
}

pub fn f32_to_fp8_e4m3(val: f32) u8 {
    if (std.math.isNan(val)) return 0x7F;
    const u: u32 = @bitCast(val);
    const sign: u8 = @intCast((u >> 31) & 1);
    const exp_f32: i32 = @as(i32, @intCast((u >> 23) & 0xFF)) - 127;
    const mant_f32: u32 = u & 0x007FFFFF;

    if (val == 0.0) return sign << 7;

    const exp_fp8 = exp_f32 + 7;
    if (exp_fp8 >= 15) {
        return (sign << 7) | (15 << 3) | 6;
    } else if (exp_fp8 <= 0) {
        if (exp_fp8 < -3) return sign << 7;
        const shift: u5 = @intCast(@as(i32, 1 - exp_fp8));
        const full_mant = (@as(u32, 1) << 23) | mant_f32;
        const sub_mant: u8 = @truncate((full_mant >> (20 + shift)));
        return (sign << 7) | @min(@as(u8, 7), sub_mant);
    } else {
        const mant_fp8: u8 = @truncate(mant_f32 >> 20);
        return (sign << 7) | (@as(u8, @intCast(exp_fp8)) << 3) | mant_fp8;
    }
}

pub fn fp8_e4m3_to_f32(raw: u8) f32 {
    const sign: f32 = if ((raw & 0x80) != 0) -1.0 else 1.0;
    const exp: u8 = (raw >> 3) & 0x0F;
    const mant: u8 = raw & 0x07;

    if (exp == 15 and mant == 7) return std.math.nan(f32);
    if (exp == 0) {
        if (mant == 0) return if (sign < 0) -0.0 else 0.0;
        return sign * (@as(f32, @floatFromInt(mant)) / 8.0) * 0.015625;
    }
    const exp_unbiased = @as(f32, @floatFromInt(@as(i32, exp) - 7));
    const mant_val = 1.0 + (@as(f32, @floatFromInt(mant)) / 8.0);
    return sign * mant_val * std.math.pow(f32, 2.0, exp_unbiased);
}

pub fn f32_to_fp8_e5m2(val: f32) u8 {
    if (std.math.isNan(val)) return 0x7F;
    if (std.math.isInf(val)) return if (val < 0) 0xFC else 0x7C;
    const u: u32 = @bitCast(val);
    const sign: u8 = @intCast((u >> 31) & 1);
    const exp_f32: i32 = @as(i32, @intCast((u >> 23) & 0xFF)) - 127;
    const mant_f32: u32 = u & 0x007FFFFF;

    if (val == 0.0) return sign << 7;

    const exp_fp8 = exp_f32 + 15;
    if (exp_fp8 >= 31) {
        return (sign << 7) | (31 << 2);
    } else if (exp_fp8 <= 0) {
        if (exp_fp8 < -2) return sign << 7;
        const shift: u5 = @intCast(@as(i32, 1 - exp_fp8));
        const full_mant = (@as(u32, 1) << 23) | mant_f32;
        const sub_mant: u8 = @truncate(full_mant >> (21 + shift));
        return (sign << 7) | @min(@as(u8, 3), sub_mant);
    } else {
        const mant_fp8: u8 = @truncate(mant_f32 >> 21);
        return (sign << 7) | (@as(u8, @intCast(exp_fp8)) << 2) | mant_fp8;
    }
}

pub fn fp8_e5m2_to_f32(raw: u8) f32 {
    const sign: f32 = if ((raw & 0x80) != 0) -1.0 else 1.0;
    const exp: u8 = (raw >> 2) & 0x1F;
    const mant: u8 = raw & 0x03;

    if (exp == 31) {
        if (mant != 0) return std.math.nan(f32);
        return sign * std.math.inf(f32);
    }
    if (exp == 0) {
        if (mant == 0) return if (sign < 0) -0.0 else 0.0;
        return sign * (@as(f32, @floatFromInt(mant)) / 4.0) * 0.00006103515625;
    }
    const exp_unbiased = @as(f32, @floatFromInt(@as(i32, exp) - 15));
    const mant_val = 1.0 + (@as(f32, @floatFromInt(mant)) / 4.0);
    return sign * mant_val * std.math.pow(f32, 2.0, exp_unbiased);
}

const FP4_POSITIVE = [_]f32{ 0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0 };

pub fn f32_to_fp4_e2m1(val: f32) u4 {
    const is_neg = val < 0.0;
    const abs_val = @abs(val);

    var best_code: u4 = 0;
    var best_diff: f32 = 1e9;
    for (FP4_POSITIVE, 0..) |target, code| {
        const diff = @abs(abs_val - target);
        if (diff < best_diff) {
            best_diff = diff;
            best_code = @intCast(code);
        }
    }
    return if (is_neg) best_code | 0x8 else best_code;
}

pub fn fp4_e2m1_to_f32(raw: u4) f32 {
    const is_neg = (raw & 0x8) != 0;
    const mag_code: usize = raw & 0x7;
    const mag = FP4_POSITIVE[mag_code];
    return if (is_neg) -mag else mag;
}

pub inline fn pack_fp4_pair(v0: f32, v1: f32) u8 {
    const n0 = f32_to_fp4_e2m1(v0);
    const n1 = f32_to_fp4_e2m1(v1);
    return (@as(u8, n0) << 4) | @as(u8, n1);
}

pub inline fn unpack_fp4_pair(byte: u8) [2]f32 {
    const n0: u4 = @truncate(byte >> 4);
    const n1: u4 = @truncate(byte & 0x0F);
    return [_]f32{ fp4_e2m1_to_f32(n0), fp4_e2m1_to_f32(n1) };
}
