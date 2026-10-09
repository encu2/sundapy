const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const types = @import("gpu_compress_types.zig");
const CodecType = types.CodecType;

// Forward reference to compress/decompress functions
const compress_engine = @import("gpu_compress.zig");

const builtin = @import("builtin");

fn get_time_ns() i64 {
    if (builtin.os.tag == .linux) {
        var ts: std.os.linux.timespec = undefined;
        _ = std.os.linux.clock_gettime(.MONOTONIC, &ts);
        return @as(i64, ts.sec) * 1_000_000_000 + @as(i64, ts.nsec);
    } else if (builtin.os.tag == .windows) {
        return @as(i64, @intCast(std.os.windows.QueryPerformanceCounter() catch 0));
    } else {
        return 1_000_000;
    }
}

// ============================================================================
// Production GPU Memory Compression Benchmark Engine
// Validates ratio, compression throughput, and fidelity across all codecs
// ============================================================================

pub fn benchmark_compression(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = kwargs;
    var size: usize = 1024 * 64; // Default 64k floats = 256 KB
    var test_data: []f32 = undefined;
    var allocated_scratch = false;

    if (args.len > 0) {
        if (args[0].value == .i64_type) {
            size = @intCast(@max(16, args[0].value.i64_type));
            test_data = try alloc.alloc(f32, size);
            allocated_scratch = true;
            for (0..size) |i| {
                const x: f32 = @floatFromInt(i);
                test_data[i] = @sin(x * 0.05) * 100.0 + @cos(x * 0.01) * 20.0;
            }
        } else if (args[0].value == .gpu_buffer_type) {
            const buf: *GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
            size = buf.size;
            test_data = buf.data;
        }
    } else {
        test_data = try alloc.alloc(f32, size);
        allocated_scratch = true;
        for (0..size) |i| {
            const x: f32 = @floatFromInt(i);
            test_data[i] = @sin(x * 0.05) * 100.0 + @cos(x * 0.01) * 20.0;
        }
    }
    defer if (allocated_scratch) alloc.free(test_data);

    const test_codecs = [_]CodecType{
        .fpc,
        .quant8,
        .quant4,
        .fp16,
        .fp8,
        .fp8_e5m2,
        .fp4,
        .bf16,
        .nvfp4,
        .block_quant,
        .lz_fast,
        .rle,
        .bpc,
        .delta_rle,
        .compact,
    };
    var result_list = std.ArrayList(Dynamic).empty;

    std.debug.print(
        \\========================================================================================
        \\ SUNDAPY PRODUCTION GPU MEMORY COMPRESSION CODEC BENCHMARK ({d} Floats)
        \\========================================================================================
        \\ Codec       | Orig (KB) | Comp (KB) | Ratio  | Savings% | Comp GB/s | Decomp GB/s | Max Err
        \\-------------+-----------+-----------+--------+----------+-----------+-------------+--------
        \\
    , .{size});

    for (test_codecs) |c| {
        const orig_bytes = size * @sizeOf(f32);

        // Compression timing
        const t0 = get_time_ns();
        const comp = compress_engine.compressData(alloc, test_data, c) catch continue;
        defer alloc.free(comp);
        const t1 = get_time_ns();

        // Decompression timing
        const decomp_scratch = try alloc.alloc(f32, size);
        defer alloc.free(decomp_scratch);
        const t2 = get_time_ns();
        compress_engine.decompressDataInto(c, comp, decomp_scratch) catch continue;
        const t3 = get_time_ns();

        const c_time_ns: u64 = @intCast(@max(1, t1 - t0));
        const d_time_ns: u64 = @intCast(@max(1, t3 - t2));
        const c_gbps: f32 = (@as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(c_time_ns)));
        const d_gbps: f32 = (@as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(d_time_ns)));

        const ratio = if (comp.len > 0) @as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(comp.len)) else 1.0;
        const savings = if (orig_bytes > comp.len) (@as(f32, @floatFromInt(orig_bytes - comp.len)) / @as(f32, @floatFromInt(orig_bytes))) * 100.0 else 0.0;

        var max_err: f32 = 0.0;
        for (0..size) |i| {
            const diff = @abs(test_data[i] - decomp_scratch[i]);
            if (diff > max_err) max_err = diff;
        }

        std.debug.print(" {s:<11} | {d:^9.1} | {d:^9.1} | {d:^6.2}x | {d:^7.1}% | {d:^9.2} | {d:^11.2} | {d:.4}\n", .{
            c.name(),
            @as(f32, @floatFromInt(orig_bytes)) / 1024.0,
            @as(f32, @floatFromInt(comp.len)) / 1024.0,
            ratio,
            savings,
            c_gbps,
            d_gbps,
            max_err,
        });

        var item = Dynamic.initDict(alloc);
        try item.value.dict_type.put(Dynamic.initStr("codec"), Dynamic.initStr(c.name()));
        try item.value.dict_type.put(Dynamic.initStr("ratio"), Dynamic.initFloat(@floatCast(ratio)));
        try item.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings)));
        try item.value.dict_type.put(Dynamic.initStr("comp_gbps"), Dynamic.initFloat(@floatCast(c_gbps)));
        try item.value.dict_type.put(Dynamic.initStr("decomp_gbps"), Dynamic.initFloat(@floatCast(d_gbps)));
        try item.value.dict_type.put(Dynamic.initStr("max_error"), Dynamic.initFloat(@floatCast(max_err)));
        try item.value.dict_type.put(Dynamic.initStr("is_lossless"), Dynamic.initBool(c.isLossless()));
        try result_list.append(alloc, item);
    }

    std.debug.print("========================================================================================\n", .{});
    return Dynamic.initList(result_list);
}
