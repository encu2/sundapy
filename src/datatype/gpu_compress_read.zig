const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("gpu_types.zig");
const quant = @import("numeric/quant.zig");

pub fn readCompressedItem(ci: *const gpu_types.CompressionInfo, idx: usize) !Dynamic {
    const p = ci.raw_payload orelse return Dynamic.initFloat(0.0);
    const scheme = ci.scheme;
    if (std.mem.eql(u8, scheme, "fp8") or std.mem.eql(u8, scheme, "fp8_e4m3")) {
        if (4 + idx < p.len) return Dynamic.initFloat(@floatCast(quant.fp8_e4m3_to_f32(p[4 + idx])));
    } else if (std.mem.eql(u8, scheme, "fp8_e5m2")) {
        if (4 + idx < p.len) return Dynamic.initFloat(@floatCast(quant.fp8_e5m2_to_f32(p[4 + idx])));
    } else if (std.mem.eql(u8, scheme, "fp4") or std.mem.eql(u8, scheme, "fp4_e2m1")) {
        const byte_idx = 4 + (idx / 2);
        if (byte_idx < p.len) {
            const b = p[byte_idx];
            const nib: u4 = if ((idx % 2) == 0) @truncate(b >> 4) else @truncate(b & 0x0F);
            return Dynamic.initFloat(@floatCast(quant.fp4_e2m1_to_f32(nib)));
        }
    } else if (std.mem.eql(u8, scheme, "bf16")) {
        const off = 4 + idx * 2;
        if (off + 2 <= p.len) {
            const u = std.mem.readInt(u16, p[off..][0..2], .little);
            return Dynamic.initFloat(@floatCast(quant.bf16_to_f32(u)));
        }
    } else if (std.mem.eql(u8, scheme, "fp16")) {
        const off = 4 + idx * 2;
        if (off + 2 <= p.len) {
            const u = std.mem.readInt(u16, p[off..][0..2], .little);
            return Dynamic.initFloat(@floatCast(quant.f16_to_f32(u)));
        }
    } else if (std.mem.eql(u8, scheme, "quant8") or std.mem.eql(u8, scheme, "int8")) {
        if (p.len >= 12 and 12 + idx < p.len) {
            const min_u = std.mem.readInt(u32, p[4..][0..4], .little);
            const max_u = std.mem.readInt(u32, p[8..][0..4], .little);
            const min_v: f32 = @bitCast(min_u);
            const max_v: f32 = @bitCast(max_u);
            const q = p[12 + idx];
            const scale = (max_v - min_v) / 255.0;
            return Dynamic.initFloat(@floatCast(min_v + @as(f32, @floatFromInt(q)) * scale));
        }
    } else if (std.mem.eql(u8, scheme, "quant4") or std.mem.eql(u8, scheme, "int4")) {
        const byte_idx = 12 + (idx / 2);
        if (p.len >= 12 and byte_idx < p.len) {
            const min_u = std.mem.readInt(u32, p[4..][0..4], .little);
            const max_u = std.mem.readInt(u32, p[8..][0..4], .little);
            const min_v: f32 = @bitCast(min_u);
            const max_v: f32 = @bitCast(max_u);
            const b = p[byte_idx];
            const q: u8 = if ((idx % 2) == 0) (b & 0x0F) else ((b >> 4) & 0x0F);
            const scale = (max_v - min_v) / 15.0;
            return Dynamic.initFloat(@floatCast(min_v + @as(f32, @floatFromInt(q)) * scale));
        }
    } else if (std.mem.eql(u8, scheme, "nvfp4")) {
        const b_idx = idx / 16;
        const in_b = idx % 16;
        const blk_off = 6 + b_idx * 9;
        if (blk_off + 9 <= p.len) {
            const scale_fp8 = p[blk_off];
            const scale = quant.fp8_e4m3_to_f32(scale_fp8);
            const b = p[blk_off + 1 + (in_b / 2)];
            const pair = quant.unpack_fp4_pair(b);
            const val = if ((in_b % 2) == 0) pair[0] * scale else pair[1] * scale;
            return Dynamic.initFloat(@floatCast(val));
        }
    } else if (std.mem.eql(u8, scheme, "compact")) {
        if (p.len >= 12) {
            const active_count: usize = std.mem.readInt(u32, p[4..8], .little);
            const data_start: usize = 12;
            const idx_start: usize = 12 + active_count * 4;
            if (idx_start + active_count * 4 <= p.len) {
                for (0..active_count) |i| {
                    const orig_idx: usize = std.mem.readInt(u32, p[idx_start + i * 4 .. idx_start + (i + 1) * 4][0..4], .little);
                    if (orig_idx == idx) {
                        const u_v = std.mem.readInt(u32, p[data_start + i * 4 .. data_start + (i + 1) * 4][0..4], .little);
                        const val: f32 = @bitCast(u_v);
                        return Dynamic.initFloat(@floatCast(val));
                    }
                }
            }
        }
        return Dynamic.initFloat(0.0);
    }
    return Dynamic.initFloat(0.0);
}
