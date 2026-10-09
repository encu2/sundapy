const std = @import("std");

// ============================================================================
// GPU VRAM Ultra-High Precision-Scaled Quantization Engine
// Formats: FP16 (IEEE-754), BF16, INT8 (Affine/Sym), FP8 (E4M3/E5M2), FP4 (E2M1)
// ============================================================================

// --- FP16 (IEEE 754 Half-Precision Float) ---
pub inline fn f32_to_f16(val: f32) u16 {
    const h: f16 = @floatCast(val);
    return @bitCast(h);
}

pub inline fn f16_to_f32(raw: u16) f32 {
    const h: f16 = @bitCast(raw);
    return @floatCast(h);
}

// --- BF16 (Brain Floating Point 16) ---
pub inline fn f32_to_bf16(val: f32) u16 {
    const u: u32 = @bitCast(val);
    // Round to nearest even:
    const lsb = (u >> 16) & 1;
    const round_bias = @as(u32, 0x7FFF) + lsb;
    const rounded = u +% round_bias;
    return @truncate(rounded >> 16);
}

pub inline fn bf16_to_f32(raw: u16) f32 {
    const u: u32 = @as(u32, raw) << 16;
    return @bitCast(u);
}

// --- FP8 E4M3 (OCP / NVIDIA Hopper standard: 1 sign, 4 exp, 3 mantissa) ---
// Max finite magnitude: 448.0, Exponent bias: 7
pub fn f32_to_fp8_e4m3(val: f32) u8 {
    if (std.math.isNan(val)) return 0x7F;
    const u: u32 = @bitCast(val);
    const sign: u8 = @intCast((u >> 31) & 1);
    const exp_f32: i32 = @as(i32, @intCast((u >> 23) & 0xFF)) - 127;
    const mant_f32: u32 = u & 0x007FFFFF;

    if (val == 0.0) return sign << 7;

    const exp_fp8 = exp_f32 + 7;
    if (exp_fp8 >= 15) {
        // Saturate to max representable number 448.0 (mantissa = 6)
        return (sign << 7) | (15 << 3) | 6;
    } else if (exp_fp8 <= 0) {
        // Subnormal or zero
        if (exp_fp8 < -3) return sign << 7;
        const shift: u5 = @intCast(@as(i32, 1 - exp_fp8));
        const full_mant = (@as(u32, 1) << 23) | mant_f32;
        const sub_mant: u8 = @truncate((full_mant >> (20 + shift)));
        return (sign << 7) | @min(@as(u8, 7), sub_mant);
    } else {
        // Normal
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
        // Subnormal: 2^(-6) * (mant / 8.0)
        return sign * (@as(f32, @floatFromInt(mant)) / 8.0) * 0.015625; // 2^-6 = 0.015625
    }
    const exp_unbiased = @as(f32, @floatFromInt(@as(i32, exp) - 7));
    const mant_val = 1.0 + (@as(f32, @floatFromInt(mant)) / 8.0);
    return sign * mant_val * std.math.pow(f32, 2.0, exp_unbiased);
}

// --- FP8 E5M2 (OCP / IEEE-like: 1 sign, 5 exp, 2 mantissa) ---
// Exponent bias: 15
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
        return (sign << 7) | (31 << 2); // Inf
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
        // Subnormal: 2^(-14) * (mant / 4.0)
        return sign * (@as(f32, @floatFromInt(mant)) / 4.0) * 0.00006103515625;
    }
    const exp_unbiased = @as(f32, @floatFromInt(@as(i32, exp) - 15));
    const mant_val = 1.0 + (@as(f32, @floatFromInt(mant)) / 4.0);
    return sign * mant_val * std.math.pow(f32, 2.0, exp_unbiased);
}

// --- FP4 E2M1 (NVIDIA Blackwell Microscaling 4-bit float: 1 sign, 2 exp, 1 mantissa) ---
// Codebook: 0=0.0, 1=0.5, 2=1.0, 3=1.5, 4=2.0, 5=3.0, 6=4.0, 7=6.0 (and negative counterparts)
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

// --- INT8 Quantization (Affine & Symmetric) ---
pub const Int8Params = struct {
    scale: f32,
    zero_point: i8,
};

pub fn compute_int8_params(slice: []const f32) Int8Params {
    if (slice.len == 0) return .{ .scale = 1.0, .zero_point = 0 };
    var min_val: f32 = slice[0];
    var max_val: f32 = slice[0];
    for (slice[1..]) |v| {
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
    }
    const range = max_val - min_val;
    if (range < 1e-7) return .{ .scale = 1.0, .zero_point = 0 };
    const scale = range / 255.0;
    const zp_f = -min_val / scale - 128.0;
    const zp: i8 = @intCast(std.math.clamp(@as(i64, @intFromFloat(@round(zp_f))), -128, 127));
    return .{ .scale = scale, .zero_point = zp };
}

pub inline fn quantize_int8(val: f32, scale: f32, zero_point: i8) i8 {
    if (scale <= 1e-9) return 0;
    const scaled = @round(val / scale) + @as(f32, @floatFromInt(zero_point));
    return @intCast(std.math.clamp(@as(i64, @intFromFloat(scaled)), -128, 127));
}

pub inline fn dequantize_int8(q: i8, scale: f32, zero_point: i8) f32 {
    return (@as(f32, @floatFromInt(q)) - @as(f32, @floatFromInt(zero_point))) * scale;
}

// --- Vector Batch Encoders / Decoders ---

pub fn quantize_slice_f16(src: []const f32, dst: []u8) void {
    const out: [*]u16 = @ptrCast(@alignCast(dst.ptr));
    for (src, 0..) |v, i| {
        out[i] = f32_to_f16(v);
    }
}

pub fn dequantize_slice_f16(src: []const u8, dst: []f32) void {
    const in: [*]const u16 = @ptrCast(@alignCast(src.ptr));
    for (dst, 0..) |*out, i| {
        out.* = f16_to_f32(in[i]);
    }
}

pub fn quantize_slice_bf16(src: []const f32, dst: []u8) void {
    const out: [*]u16 = @ptrCast(@alignCast(dst.ptr));
    for (src, 0..) |v, i| {
        out[i] = f32_to_bf16(v);
    }
}

pub fn dequantize_slice_bf16(src: []const u8, dst: []f32) void {
    const in: [*]const u16 = @ptrCast(@alignCast(src.ptr));
    for (dst, 0..) |*out, i| {
        out.* = bf16_to_f32(in[i]);
    }
}

pub fn quantize_slice_int8(src: []const f32, dst: []u8, scale: f32, zero_point: i8) void {
    const out: [*]i8 = @ptrCast(dst.ptr);
    for (src, 0..) |v, i| {
        out[i] = quantize_int8(v, scale, zero_point);
    }
}

pub fn dequantize_slice_int8(src: []const u8, dst: []f32, scale: f32, zero_point: i8) void {
    const in: [*]const i8 = @ptrCast(src.ptr);
    for (dst, 0..) |*out, i| {
        out.* = dequantize_int8(in[i], scale, zero_point);
    }
}

pub fn quantize_slice_fp8(src: []const f32, dst: []u8, is_e4m3: bool) void {
    if (is_e4m3) {
        for (src, 0..) |v, i| {
            dst[i] = f32_to_fp8_e4m3(v);
        }
    } else {
        for (src, 0..) |v, i| {
            dst[i] = f32_to_fp8_e5m2(v);
        }
    }
}

pub fn dequantize_slice_fp8(src: []const u8, dst: []f32, is_e4m3: bool) void {
    if (is_e4m3) {
        for (dst, 0..) |*out, i| {
            out.* = fp8_e4m3_to_f32(src[i]);
        }
    } else {
        for (dst, 0..) |*out, i| {
            out.* = fp8_e5m2_to_f32(src[i]);
        }
    }
}

pub fn quantize_slice_fp4(src: []const f32, dst: []u8) void {
    var i: usize = 0;
    var out_idx: usize = 0;
    while (i < src.len) : (out_idx += 1) {
        const v0 = src[i];
        const v1 = if (i + 1 < src.len) src[i + 1] else 0.0;
        dst[out_idx] = pack_fp4_pair(v0, v1);
        i += 2;
    }
}

pub fn dequantize_slice_fp4(src: []const u8, dst: []f32) void {
    var out_idx: usize = 0;
    for (src) |b| {
        const pair = unpack_fp4_pair(b);
        if (out_idx < dst.len) {
            dst[out_idx] = pair[0];
            out_idx += 1;
        }
        if (out_idx < dst.len) {
            dst[out_idx] = pair[1];
            out_idx += 1;
        }
    }
}
