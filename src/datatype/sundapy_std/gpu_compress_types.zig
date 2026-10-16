const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const quant = @import("gpu_quant.zig");
const gpu_types = @import("datatype/gpu_types.zig");

// ============================================================================
// Production GPU Memory Compression Types & Subsystem Enums
// ============================================================================

pub const CodecType = enum {
    none,
    fpc, // Lossless Fast Floating-Point Compression (Burtscher-Ratanaworabhan)
    quant8, // 8-Bit Linear Min-Max Quantization (4.0x compression)
    quant4, // 4-Bit Packed Nibble Quantization (8.0x compression)
    fp16, // IEEE 754 Half-Precision 16-Bit Float (2.0x compression)
    fp8, // OCP / NVIDIA Hopper E4M3 8-bit Float (4.0x compression)
    fp8_e5m2, // OCP IEEE-like E5M2 8-bit Float (4.0x compression)
    fp4, // NVIDIA Blackwell E2M1 4-bit Microscaled Float (8.0x compression)
    block_quant, // Block-Floating-Point Micro-scaling (5.33x - 6.4x compression)
    lz_fast, // Byte-Level Fast LZ Dictionary Compressor (lossless)
    rle, // Run-Length Encoding for sparse/homogeneous buffers (lossless)
    bpc, // Hardware Bit-Plane Compression (lossless 32-plane)
    delta_rle, // Delta ZigZag RLE (lossless)
    sparse, // Bit-Level CSR Sparse Matrix Compression (lossless)
    bf16, // Brain Floating Point 16 (2.0x compression)
    nvfp4, // Blackwell Microscaling NVFP4 (7.11x compression)
    compact, // Zero-Copy 64-byte Cacheline Compaction (lossless)

    pub fn fromString(str: []const u8) ?CodecType {
        if (std.mem.eql(u8, str, "fpc") or std.mem.eql(u8, str, "fpc_lossless")) return .fpc;
        if (std.mem.eql(u8, str, "quant8") or std.mem.eql(u8, str, "int8") or std.mem.eql(u8, str, "q8")) return .quant8;
        if (std.mem.eql(u8, str, "quant4") or std.mem.eql(u8, str, "int4") or std.mem.eql(u8, str, "q4")) return .quant4;
        if (std.mem.eql(u8, str, "fp16") or std.mem.eql(u8, str, "half") or std.mem.eql(u8, str, "f16")) return .fp16;
        if (std.mem.eql(u8, str, "fp8") or std.mem.eql(u8, str, "fp8_e4m3") or std.mem.eql(u8, str, "e4m3")) return .fp8;
        if (std.mem.eql(u8, str, "fp8_e5m2") or std.mem.eql(u8, str, "e5m2")) return .fp8_e5m2;
        if (std.mem.eql(u8, str, "fp4") or std.mem.eql(u8, str, "fp4_e2m1") or std.mem.eql(u8, str, "e2m1")) return .fp4;
        if (std.mem.eql(u8, str, "bf16") or std.mem.eql(u8, str, "bfloat16")) return .bf16;
        if (std.mem.eql(u8, str, "nvfp4") or std.mem.eql(u8, str, "microscale") or std.mem.eql(u8, str, "nvfp4_microscale")) return .nvfp4;
        if (std.mem.eql(u8, str, "compact") or std.mem.eql(u8, str, "compaction") or std.mem.eql(u8, str, "zero_copy_compact")) return .compact;
        if (std.mem.eql(u8, str, "block_quant") or std.mem.eql(u8, str, "bfp") or std.mem.eql(u8, str, "block")) return .block_quant;
        if (std.mem.eql(u8, str, "lz_fast") or std.mem.eql(u8, str, "lz") or std.mem.eql(u8, str, "lz4")) return .lz_fast;
        if (std.mem.eql(u8, str, "rle") or std.mem.eql(u8, str, "run_length")) return .rle;
        if (std.mem.eql(u8, str, "bpc") or std.mem.eql(u8, str, "bit_plane")) return .bpc;
        if (std.mem.eql(u8, str, "delta_rle") or std.mem.eql(u8, str, "zigzag_rle")) return .delta_rle;
        if (std.mem.eql(u8, str, "sparse") or std.mem.eql(u8, str, "bcsr") or std.mem.eql(u8, str, "bit_sparse")) return .sparse;
        if (std.mem.eql(u8, str, "none")) return .none;
        return null;
    }

    pub fn name(self: CodecType) []const u8 {
        return switch (self) {
            .none => "none",
            .fpc => "fpc",
            .quant8 => "quant8",
            .quant4 => "quant4",
            .fp16 => "fp16",
            .fp8 => "fp8",
            .fp8_e5m2 => "fp8_e5m2",
            .fp4 => "fp4",
            .bf16 => "bf16",
            .nvfp4 => "nvfp4",
            .compact => "compact",
            .block_quant => "block_quant",
            .lz_fast => "lz_fast",
            .rle => "rle",
            .bpc => "bpc",
            .delta_rle => "delta_rle",
            .sparse => "sparse",
        };
    }

    pub fn isLossless(self: CodecType) bool {
        return switch (self) {
            .fpc, .lz_fast, .rle, .bpc, .delta_rle, .sparse, .compact, .none => true,
            .quant8, .quant4, .fp16, .fp8, .fp8_e5m2, .fp4, .bf16, .nvfp4, .block_quant => false,
        };
    }
};

pub const CompressedBuffer = struct {
    allocator: std.mem.Allocator,
    codec: CodecType,
    original_size: usize, // Count of elements
    original_bytes: usize, // Uncompressed byte footprint
    compressed_bytes: []u8,
    min_val: f32 = 0.0,
    max_val: f32 = 0.0,
    scale: f32 = 1.0,
    ratio: f32 = 1.0,
    last_method: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator, codec: CodecType, orig_len: usize, comp_bytes: []u8) !*CompressedBuffer {
        const self = try allocator.create(CompressedBuffer);
        const orig_b = orig_len * @sizeOf(f32);
        const r: f32 = if (comp_bytes.len > 0) @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(comp_bytes.len)) else 1.0;

        self.* = .{
            .allocator = allocator,
            .codec = codec,
            .original_size = orig_len,
            .original_bytes = orig_b,
            .compressed_bytes = comp_bytes,
            .ratio = r,
        };
        return self;
    }

    pub fn deinit(self: *CompressedBuffer) void {
        self.allocator.free(self.compressed_bytes);
        self.allocator.destroy(self);
    }

    pub fn savingsPercent(self: *const CompressedBuffer) f32 {
        if (self.original_bytes == 0) return 0.0;
        if (self.compressed_bytes.len >= self.original_bytes) return 0.0;
        const saved = self.original_bytes - self.compressed_bytes.len;
        return (@as(f32, @floatFromInt(saved)) / @as(f32, @floatFromInt(self.original_bytes))) * 100.0;
    }

    pub fn asDynamic(self: *CompressedBuffer) Dynamic {
        // Return a dictionary representation with live dynamic method and property bindings
        var dict = Dynamic.initDict(self.allocator);
        dict.value.dict_type.put(Dynamic.initStr("codec"), Dynamic.initStr(self.codec.name())) catch {};
        dict.value.dict_type.put(Dynamic.initStr("size"), Dynamic.initInt(@intCast(self.original_size))) catch {};
        dict.value.dict_type.put(Dynamic.initStr("original_bytes"), Dynamic.initInt(@intCast(self.original_bytes))) catch {};
        dict.value.dict_type.put(Dynamic.initStr("compressed_bytes"), Dynamic.initInt(@intCast(self.compressed_bytes.len))) catch {};
        dict.value.dict_type.put(Dynamic.initStr("ratio"), Dynamic.initFloat(@floatCast(self.ratio))) catch {};
        dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(self.savingsPercent()))) catch {};
        dict.value.dict_type.put(Dynamic.initStr("is_lossless"), Dynamic.initBool(self.codec.isLossless())) catch {};
        dict.value.dict_type.put(Dynamic.initStr("handle"), Dynamic.initInt(@intCast(@intFromPtr(self)))) catch {};
        return dict;
    }
};

pub const BenchmarkEntry = struct {
    codec: CodecType,
    original_bytes: usize,
    compressed_bytes: usize,
    ratio: f32,
    savings_pct: f32,
    compress_time_ns: u64,
    decompress_time_ns: u64,
    compress_gbps: f32,
    decompress_gbps: f32,
    max_error: f32,
    mse: f32,
    is_exact: bool,
};

pub const readCompressedItem = @import("datatype/gpu_compress_read.zig").readCompressedItem;

