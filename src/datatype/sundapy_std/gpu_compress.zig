const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const CompressionInfo = gpu_types.CompressionInfo;

pub const types = @import("gpu_compress_types.zig");
pub const CodecType = types.CodecType;
pub const CompressedBuffer = types.CompressedBuffer;
pub const BenchmarkEntry = types.BenchmarkEntry;

pub const fpc = @import("gpu_codec_fpc.zig");
pub const quant = @import("gpu_codec_quant.zig");
pub const lz = @import("gpu_codec_lz.zig");
pub const budget = @import("gpu_budget.zig");
pub const bench = @import("gpu_compress_bench.zig");
pub const gpu_quant = @import("gpu_quant.zig");
pub const lossless = @import("gpu_lossless.zig");
pub const sparse = @import("gpu_sparse.zig");
pub const ultra = @import("gpu_codec_ultra.zig");

// ============================================================================
// Core Unified Compression & Decompression Engines
// ============================================================================

pub fn compressData(allocator: std.mem.Allocator, data: []const f32, codec: CodecType) ![]u8 {
    return switch (codec) {
        .fpc => try fpc.compress(allocator, data),
        .quant8 => try quant.quant8Compress(allocator, data),
        .quant4 => try quant.quant4Compress(allocator, data),
        .fp16 => try quant.fp16Compress(allocator, data),
        .fp8 => try ultra.fp8E4m3Compress(allocator, data),
        .fp8_e5m2 => try ultra.fp8E5m2Compress(allocator, data),
        .fp4 => try ultra.fp4E2m1Compress(allocator, data),
        .bf16 => try ultra.bf16Compress(allocator, data),
        .nvfp4 => try ultra.nvfp4MicroscaleCompress(allocator, data),
        .compact => try ultra.compactCompressSlice(allocator, data, 1e-6),
        .block_quant => try quant.blockQuantCompress(allocator, data),
        .lz_fast => try lz.lzCompressFloats(allocator, data),
        .rle => try lz.rleCompressFloats(allocator, data),
        .bpc => blk: {
            const raw_bytes: []const u8 = @as([*]const u8, @ptrCast(data.ptr))[0 .. data.len * @sizeOf(f32)];
            break :blk try lossless.compress_lossless(allocator, raw_bytes, .bpc);
        },
        .delta_rle => blk: {
            const raw_bytes: []const u8 = @as([*]const u8, @ptrCast(data.ptr))[0 .. data.len * @sizeOf(f32)];
            break :blk try lossless.compress_lossless(allocator, raw_bytes, .delta_rle);
        },
        .sparse => blk: {
            // Compress dense 1D vector as BitSparseMatrix
            const bcsr = try sparse.compress_dense_to_bcsr(allocator, data, 1, data.len, 1e-6);
            defer bcsr.deinit();
            // Serialize: rows(8B) + cols(8B) + nnz(8B) + bitmasks + values
            const total_sz = 24 + bcsr.bitmasks.len * 8 + bcsr.values.len * 4;
            const out_buf = try allocator.alloc(u8, total_sz);
            std.mem.writeInt(u64, out_buf[0..8], 1, .little);
            std.mem.writeInt(u64, out_buf[8..16], data.len, .little);
            std.mem.writeInt(u64, out_buf[16..24], bcsr.nnz, .little);
            const bm_bytes: []const u8 = @as([*]const u8, @ptrCast(bcsr.bitmasks.ptr))[0 .. bcsr.bitmasks.len * 8];
            @memcpy(out_buf[24 .. 24 + bm_bytes.len], bm_bytes);
            const val_bytes: []const u8 = @as([*]const u8, @ptrCast(bcsr.values.ptr))[0 .. bcsr.values.len * 4];
            @memcpy(out_buf[24 + bm_bytes.len ..], val_bytes);
            break :blk out_buf;
        },
        .none => blk: {
            const bytes: []const u8 = @as([*]const u8, @ptrCast(data.ptr))[0 .. data.len * @sizeOf(f32)];
            const dup = try allocator.alloc(u8, bytes.len);
            @memcpy(dup, bytes);
            break :blk dup;
        },
    };
}

pub fn decompressDataInto(codec: CodecType, comp_bytes: []const u8, out_data: []f32) !void {
    switch (codec) {
        .fpc => try fpc.decompressInto(comp_bytes, out_data),
        .quant8 => try quant.quant8DecompressInto(comp_bytes, out_data),
        .quant4 => try quant.quant4DecompressInto(comp_bytes, out_data),
        .fp16 => try quant.fp16DecompressInto(comp_bytes, out_data),
        .fp8 => try ultra.fp8E4m3DecompressInto(comp_bytes, out_data),
        .fp8_e5m2 => try ultra.fp8E5m2DecompressInto(comp_bytes, out_data),
        .fp4 => try ultra.fp4E2m1DecompressInto(comp_bytes, out_data),
        .bf16 => try ultra.bf16DecompressInto(comp_bytes, out_data),
        .nvfp4 => try ultra.nvfp4MicroscaleDecompressInto(comp_bytes, out_data),
        .compact => try ultra.compactDecompressSliceInto(comp_bytes, out_data),
        .block_quant => try quant.blockQuantDecompressInto(comp_bytes, out_data),
        .lz_fast => try lz.lzDecompressFloatsInto(comp_bytes, out_data),
        .rle => try lz.rleDecompressFloatsInto(comp_bytes, out_data),
        .bpc, .delta_rle => {
            const dec_bytes = try lossless.decompress_lossless(std.heap.c_allocator, comp_bytes);
            defer std.heap.c_allocator.free(dec_bytes);
            const copy_len = @min(dec_bytes.len, out_data.len * @sizeOf(f32));
            @memcpy(@as([*]u8, @ptrCast(out_data.ptr))[0..copy_len], dec_bytes[0..copy_len]);
        },
        .sparse => {
            @memset(out_data, 0.0);
            if (comp_bytes.len >= 24) {
                const cols: usize = @intCast(std.mem.readInt(u64, comp_bytes[8..16], .little));
                const nnz: usize = @intCast(std.mem.readInt(u64, comp_bytes[16..24], .little));
                const words_per_row = (cols + 63) / 64;
                const bm_len = words_per_row * 8;
                if (24 + bm_len + nnz * 4 <= comp_bytes.len) {
                    var v_idx: usize = 0;
                    for (0..words_per_row) |w| {
                        var mask = std.mem.readInt(u64, comp_bytes[24 + w * 8 .. 32 + w * 8][0..8], .little);
                        const col_base = w * 64;
                        while (mask != 0 and v_idx < nnz) {
                            const bit_pos = @ctz(mask);
                            const c = col_base + bit_pos;
                            const u_val = std.mem.readInt(u32, comp_bytes[24 + bm_len + v_idx * 4 .. 28 + bm_len + v_idx * 4][0..4], .little);
                            const f_val: f32 = @bitCast(u_val);
                            if (c < out_data.len) {
                                out_data[c] = f_val;
                            }
                            v_idx += 1;
                            mask &= mask - 1;
                        }
                    }
                }
            }
        },
        .none => {
            const target_bytes: []u8 = @as([*]u8, @ptrCast(out_data.ptr))[0 .. out_data.len * @sizeOf(f32)];
            const copy_len = @min(comp_bytes.len, target_bytes.len);
            @memcpy(target_bytes[0..copy_len], comp_bytes[0..copy_len]);
        },
    }
}

// ============================================================================
// Python API Callbacks
// ============================================================================

pub fn compress(buf_dyn: Dynamic, codec_dyn: ?Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var c_type: CodecType = .fpc;
    if (codec_dyn) |cd| {
        if (cd.value == .str_type) {
            c_type = CodecType.fromString(cd.value.str_type) orelse .fpc;
        }
    }

    const compressed_payload = try compressData(std.heap.c_allocator, buf.data, c_type);
    const comp_obj = try CompressedBuffer.init(std.heap.c_allocator, c_type, buf.size, compressed_payload);
    budget.recordCompression(buf.size * @sizeOf(f32), compressed_payload.len);

    return comp_obj.asDynamic();
}

pub fn decompress(comp_dyn: Dynamic, out_dyn: ?Dynamic) anyerror!Dynamic {
    var codec: CodecType = .fpc;
    var orig_len: usize = 0;
    var comp_bytes: []const u8 = &[_]u8{};

    if (comp_dyn.value == .dict_type) {
        if (comp_dyn.value.dict_type.get(Dynamic.initStr("handle"))) |h_dyn| {
            if (h_dyn.value == .i64_type) {
                const ptr: usize = @intCast(h_dyn.value.i64_type);
                const c_buf: *CompressedBuffer = @ptrFromInt(ptr);
                codec = c_buf.codec;
                orig_len = c_buf.original_size;
                comp_bytes = c_buf.compressed_bytes;
            }
        }
    }

    if (orig_len == 0 and comp_bytes.len == 0) return error.InvalidData;

    var out_buf: *GpuBuffer = undefined;
    if (out_dyn != null and out_dyn.?.value == .gpu_buffer_type) {
        out_buf = @ptrCast(@alignCast(out_dyn.?.value.gpu_buffer_type));
    } else {
        out_buf = try GpuBuffer.init(std.heap.c_allocator, orig_len);
    }

    try decompressDataInto(codec, comp_bytes, out_buf.data);
    budget.recordDecompression(orig_len * @sizeOf(f32), comp_bytes.len);
    return out_buf.asDynamic();
}

pub fn compress_ratio(buf_dyn: Dynamic, codec_dyn: ?Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    var c_type: CodecType = .fpc;
    if (codec_dyn) |cd| {
        if (cd.value == .str_type) {
            c_type = CodecType.fromString(cd.value.str_type) orelse .fpc;
        }
    }

    const compressed_payload = try compressData(std.heap.c_allocator, buf.data, c_type);
    defer std.heap.c_allocator.free(compressed_payload);

    const orig_b = buf.size * @sizeOf(f32);
    const r: f32 = if (compressed_payload.len > 0)
        @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(compressed_payload.len))
    else
        1.0;

    return Dynamic.initFloat(@floatCast(r));
}

pub fn get_codecs() anyerror!Dynamic {
    var list = std.ArrayList(Dynamic).empty;
    const all = [_][]const u8{
        "fpc",
        "quant8",
        "quant4",
        "fp16",
        "fp8",
        "fp8_e5m2",
        "fp4",
        "bf16",
        "nvfp4",
        "compact",
        "block_quant",
        "lz_fast",
        "rle",
        "bpc",
        "delta_rle",
        "sparse",
    };
    for (all) |name| {
        try list.append(std.heap.c_allocator, Dynamic.initStr(name));
    }
    return Dynamic.initList(list);
}

pub fn initBufferHooks() void {
    gpu_types.buffer_compress_fn = bufferCompressHook;
    gpu_types.buffer_decompress_inplace_fn = bufferDecompressHook;
}

// Slice adaptors for arbitrary-argument Python calls
pub fn compress_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const cd = if (args.len > 1) args[1] else null;
    return compress(args[0], cd);
}

pub fn decompress_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const od = if (args.len > 1) args[1] else null;
    return decompress(args[0], od);
}

pub fn compress_ratio_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const cd = if (args.len > 1) args[1] else null;
    return compress_ratio(args[0], cd);
}

pub fn set_budget_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    if (args[0].value == .i64_type) {
        budget.setMemoryBudget(@intCast(@max(0, args[0].value.i64_type)));
    }
    return Dynamic.initNone();
}

pub fn get_budget_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = args;
    _ = kwargs;
    const b = budget.getMemoryBudget();
    var dict = Dynamic.initDict(alloc);
    try dict.value.dict_type.put(Dynamic.initStr("budget_limit"), Dynamic.initInt(@intCast(b.budget_limit_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("used_bytes"), Dynamic.initInt(@intCast(b.total_physical_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("saved_bytes"), Dynamic.initInt(@intCast(b.saved_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("oom_prevented"), Dynamic.initInt(@intCast(b.oom_prevented_count)));
    return dict;
}

pub fn get_stats_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = args;
    _ = kwargs;
    return budget.getMemoryStats(alloc);
}

pub fn memory_report_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = args;
    _ = kwargs;
    budget.printMemoryReport();
    return budget.getMemoryStats(alloc);
}

pub fn compact_memory_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = args;
    _ = kwargs;
    const reclaimed = budget.compactMemory();
    return Dynamic.initInt(@intCast(reclaimed));
}

pub const benchmark_compression = bench.benchmark_compression;

// ============================================================================
// Buffer In-Place Hooks
// ============================================================================

pub fn bufferCompressHook(buf: *GpuBuffer, codec_str: []const u8) anyerror!void {
    const c_type = CodecType.fromString(codec_str) orelse .fpc;
    const comp_bytes = try compressData(buf.allocator, buf.data, c_type);

    if (buf.compression_info == null) {
        buf.compression_info = try buf.allocator.create(CompressionInfo);
        buf.compression_info.?.* = .{};
    }
    const ci = buf.compression_info.?;

    if (ci.raw_payload) |old_p| {
        buf.allocator.free(old_p);
    }
    ci.raw_payload = comp_bytes;
    ci.compressed_bytes = comp_bytes.len;
    ci.original_bytes = buf.size * buf.dtype.sizeOf();
    ci.is_compressed = true;
    ci.scheme = c_type.name();

    const orig_b = ci.original_bytes;
    ci.compression_ratio = if (comp_bytes.len > 0)
        @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(comp_bytes.len))
    else
        1.0;
    ci.savings_pct = if (orig_b > comp_bytes.len)
        (@as(f32, @floatFromInt(orig_b - comp_bytes.len)) / @as(f32, @floatFromInt(orig_b))) * 100.0
    else
        0.0;

    budget.recordCompression(orig_b, comp_bytes.len);
}

pub fn bufferDecompressHook(buf: *GpuBuffer) anyerror!void {
    if (buf.compression_info == null) return;
    const ci = buf.compression_info.?;
    if (!ci.is_compressed or ci.raw_payload == null) return;

    const c_type = CodecType.fromString(ci.scheme) orelse .fpc;
    const payload = ci.raw_payload.?;
    try decompressDataInto(c_type, payload, buf.data);

    budget.recordDecompression(ci.original_bytes, ci.compressed_bytes);
    ci.is_compressed = false;
    ci.compression_ratio = 1.0;
    ci.savings_pct = 0.0;
    buf.allocator.free(payload);
    ci.raw_payload = null;
}

// ============================================================================
// Attribute Lookup for Dynamic Dispatch
// ============================================================================

pub fn lookup(attr: []const u8) ?Dynamic {
    if (std.mem.eql(u8, attr, "compress")) return Dynamic{ .value = .{ .func_type_slice = compress_slice } };
    if (std.mem.eql(u8, attr, "decompress")) return Dynamic{ .value = .{ .func_type_slice = decompress_slice } };
    if (std.mem.eql(u8, attr, "compress_ratio")) return Dynamic{ .value = .{ .func_type_slice = compress_ratio_slice } };
    if (std.mem.eql(u8, attr, "codecs") or std.mem.eql(u8, attr, "get_codecs")) return dynamic.toDynamicFunc(get_codecs);
    if (std.mem.eql(u8, attr, "set_memory_budget")) return Dynamic{ .value = .{ .func_type_slice = set_budget_slice } };
    if (std.mem.eql(u8, attr, "get_memory_budget")) return Dynamic{ .value = .{ .func_type_slice = get_budget_slice } };
    if (std.mem.eql(u8, attr, "get_memory_stats")) return Dynamic{ .value = .{ .func_type_slice = get_stats_slice } };
    if (std.mem.eql(u8, attr, "memory_report")) return Dynamic{ .value = .{ .func_type_slice = memory_report_slice } };
    if (std.mem.eql(u8, attr, "compact_memory")) return Dynamic{ .value = .{ .func_type_slice = compact_memory_slice } };
    if (std.mem.eql(u8, attr, "quantize")) return Dynamic{ .value = .{ .func_type_slice = compress_slice } };
    if (std.mem.eql(u8, attr, "dequantize")) return Dynamic{ .value = .{ .func_type_slice = decompress_slice } };
    if (std.mem.eql(u8, attr, "benchmark_compression")) return Dynamic{ .value = .{ .func_type_slice = benchmark_compression } };
    return null;
}
