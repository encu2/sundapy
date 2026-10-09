const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_palette = @import("gui_palette.zig");
const fpc = @import("gpu_codec_fpc.zig");

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

pub const CompressedSurfaceObj = struct {
    allocator: std.mem.Allocator,
    codec: []const u8,
    original_size: usize, // Float count
    original_bytes: usize,
    compressed_bytes: []u8,
    ratio: f32,

    pub fn deinit(self: *CompressedSurfaceObj) void {
        self.allocator.free(self.compressed_bytes);
        self.allocator.destroy(self);
    }
};

pub fn compressSurfaceRle(allocator: std.mem.Allocator, data: []const f32) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    // Compress in runs of 3-float RGB pixels
    var i: usize = 0;
    const num_px = data.len / 3;

    while (i < num_px) {
        const r = data[i * 3];
        const g = data[i * 3 + 1];
        const b = data[i * 3 + 2];
        var run_len: usize = 1;

        while (i + run_len < num_px and run_len < 65535) {
            const next_r = data[(i + run_len) * 3];
            const next_g = data[(i + run_len) * 3 + 1];
            const next_b = data[(i + run_len) * 3 + 2];
            if (next_r == r and next_g == g and next_b == b) {
                run_len += 1;
            } else {
                break;
            }
        }

        // Emit packet: run_len (u16), r (u8), g (u8), b (u8)
        var len_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &len_bytes, @intCast(run_len), .little);
        try out.appendSlice(allocator, &len_bytes);

        const ru: u8 = @intFromFloat(std.math.clamp(r, 0.0, 255.0));
        const gu: u8 = @intFromFloat(std.math.clamp(g, 0.0, 255.0));
        const bu: u8 = @intFromFloat(std.math.clamp(b, 0.0, 255.0));
        try out.append(allocator, ru);
        try out.append(allocator, gu);
        try out.append(allocator, bu);

        i += run_len;
    }

    return out.toOwnedSlice(allocator);
}

pub fn decompressSurfaceRle(comp: []const u8, out_data: []f32) void {
    var in_pos: usize = 0;
    var out_px: usize = 0;
    const max_px = out_data.len / 3;

    while (in_pos + 5 <= comp.len and out_px < max_px) {
        const run_len: usize = std.mem.readInt(u16, comp[in_pos .. in_pos + 2][0..2], .little);
        const rf: f32 = @floatFromInt(comp[in_pos + 2]);
        const gf: f32 = @floatFromInt(comp[in_pos + 3]);
        const bf: f32 = @floatFromInt(comp[in_pos + 4]);
        in_pos += 5;

        for (0..run_len) |_| {
            if (out_px >= max_px) break;
            out_data[out_px * 3] = rf;
            out_data[out_px * 3 + 1] = gf;
            out_data[out_px * 3 + 2] = bf;
            out_px += 1;
        }
    }
}

pub fn compressSurface(allocator: std.mem.Allocator, surface_dyn: Dynamic, codec_str: []const u8) anyerror!Dynamic {
    if (surface_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(surface_dyn.value.gpu_buffer_type));

    const orig_b = buf.size * @sizeOf(f32);
    var comp_payload: []u8 = undefined;

    if (std.mem.eql(u8, codec_str, "fpc")) {
        comp_payload = try fpc.compress(allocator, buf.data);
    } else {
        // Default: fast UI RLE
        comp_payload = try compressSurfaceRle(allocator, buf.data);
    }

    const ratio: f32 = if (comp_payload.len > 0)
        @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(comp_payload.len))
    else
        1.0;
    const savings: f32 = if (orig_b > comp_payload.len)
        (@as(f32, @floatFromInt(orig_b - comp_payload.len)) / @as(f32, @floatFromInt(orig_b))) * 100.0
    else
        0.0;

    const obj = try allocator.create(CompressedSurfaceObj);
    obj.* = .{
        .allocator = allocator,
        .codec = codec_str,
        .original_size = buf.size,
        .original_bytes = orig_b,
        .compressed_bytes = comp_payload,
        .ratio = ratio,
    };

    var dict = Dynamic.initDict(allocator);
    try dict.value.dict_type.put(Dynamic.initStr("codec"), Dynamic.initStr(codec_str));
    try dict.value.dict_type.put(Dynamic.initStr("original_bytes"), Dynamic.initInt(@intCast(orig_b)));
    try dict.value.dict_type.put(Dynamic.initStr("compressed_bytes"), Dynamic.initInt(@intCast(comp_payload.len)));
    try dict.value.dict_type.put(Dynamic.initStr("ratio"), Dynamic.initFloat(@floatCast(ratio)));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings)));
    try dict.value.dict_type.put(Dynamic.initStr("handle"), Dynamic.initInt(@intCast(@intFromPtr(obj))));
    return dict;
}

pub fn decompressSurface(allocator: std.mem.Allocator, comp_dyn: Dynamic, out_dyn: ?Dynamic) anyerror!Dynamic {
    if (comp_dyn.value != .dict_type) return error.TypeError;
    const handle_dyn = comp_dyn.value.dict_type.get(Dynamic.initStr("handle")) orelse return error.InvalidData;
    if (handle_dyn.value != .i64_type) return error.TypeError;

    const obj: *CompressedSurfaceObj = @ptrFromInt(@as(usize, @intCast(handle_dyn.value.i64_type)));

    var out_buf: *GpuBuffer = undefined;
    if (out_dyn != null and out_dyn.?.value == .gpu_buffer_type) {
        out_buf = @ptrCast(@alignCast(out_dyn.?.value.gpu_buffer_type));
    } else {
        out_buf = try GpuBuffer.init(allocator, obj.original_size);
    }

    if (std.mem.eql(u8, obj.codec, "fpc")) {
        try fpc.decompressInto(obj.compressed_bytes, out_buf.data);
    } else {
        decompressSurfaceRle(obj.compressed_bytes, out_buf.data);
    }

    return out_buf.asDynamic();
}

pub fn compressRatio(surface_dyn: Dynamic, codec_str: []const u8) anyerror!Dynamic {
    if (surface_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(surface_dyn.value.gpu_buffer_type));
    const orig_b = buf.size * @sizeOf(f32);

    var comp_payload: []u8 = undefined;
    if (std.mem.eql(u8, codec_str, "fpc")) {
        comp_payload = try fpc.compress(std.heap.c_allocator, buf.data);
    } else {
        comp_payload = try compressSurfaceRle(std.heap.c_allocator, buf.data);
    }
    defer std.heap.c_allocator.free(comp_payload);

    const ratio: f32 = if (comp_payload.len > 0)
        @as(f32, @floatFromInt(orig_b)) / @as(f32, @floatFromInt(comp_payload.len))
    else
        1.0;
    return Dynamic.initFloat(@floatCast(ratio));
}

pub fn getSurfaceStats(allocator: std.mem.Allocator, surface_dyn: Dynamic) anyerror!Dynamic {
    if (surface_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(surface_dyn.value.gpu_buffer_type));

    var dict = Dynamic.initDict(allocator);
    const bytes = buf.size * buf.dtype.sizeOf();
    const mb = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);

    try dict.value.dict_type.put(Dynamic.initStr("size"), Dynamic.initInt(@intCast(buf.size)));
    try dict.value.dict_type.put(Dynamic.initStr("bytes"), Dynamic.initInt(@intCast(bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("mb"), Dynamic.initFloat(mb));
    try dict.value.dict_type.put(Dynamic.initStr("is_compressed"), Dynamic.initBool(if (buf.compression_info) |ci| ci.is_compressed else false));
    try dict.value.dict_type.put(Dynamic.initStr("compression_ratio"), Dynamic.initFloat(if (buf.compression_info) |ci| ci.compression_ratio else 1.0));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(if (buf.compression_info) |ci| ci.savings_pct else 0.0));
    try dict.value.dict_type.put(Dynamic.initStr("scheme"), Dynamic.initStr(if (buf.compression_info) |ci| ci.scheme else "none"));
    return dict;
}

pub fn benchmarkSurface(allocator: std.mem.Allocator, surface_dyn: Dynamic) anyerror!Dynamic {
    if (surface_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(surface_dyn.value.gpu_buffer_type));

    const codecs = [_][]const u8{ "rle", "fpc" };
    var result_list = std.ArrayList(Dynamic).empty;

    for (codecs) |c_name| {
        const orig_bytes = buf.size * @sizeOf(f32);
        const t0 = get_time_ns();
        var comp: []u8 = undefined;
        if (std.mem.eql(u8, c_name, "fpc")) {
            comp = try fpc.compress(allocator, buf.data);
        } else {
            comp = try compressSurfaceRle(allocator, buf.data);
        }
        defer allocator.free(comp);
        const t1 = get_time_ns();

        const scratch = try allocator.alloc(f32, buf.size);
        defer allocator.free(scratch);
        const t2 = get_time_ns();
        if (std.mem.eql(u8, c_name, "fpc")) {
            try fpc.decompressInto(comp, scratch);
        } else {
            decompressSurfaceRle(comp, scratch);
        }
        const t3 = get_time_ns();

        const c_time_ns: u64 = @intCast(@max(1, t1 - t0));
        const d_time_ns: u64 = @intCast(@max(1, t3 - t2));
        const c_gbps: f32 = (@as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(c_time_ns)));
        const d_gbps: f32 = (@as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(d_time_ns)));
        const ratio = if (comp.len > 0) @as(f32, @floatFromInt(orig_bytes)) / @as(f32, @floatFromInt(comp.len)) else 1.0;
        const savings = if (orig_bytes > comp.len) (@as(f32, @floatFromInt(orig_bytes - comp.len)) / @as(f32, @floatFromInt(orig_bytes))) * 100.0 else 0.0;

        var item = Dynamic.initDict(allocator);
        try item.value.dict_type.put(Dynamic.initStr("codec"), Dynamic.initStr(c_name));
        try item.value.dict_type.put(Dynamic.initStr("ratio"), Dynamic.initFloat(@floatCast(ratio)));
        try item.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings)));
        try item.value.dict_type.put(Dynamic.initStr("comp_gbps"), Dynamic.initFloat(@floatCast(c_gbps)));
        try item.value.dict_type.put(Dynamic.initStr("decomp_gbps"), Dynamic.initFloat(@floatCast(d_gbps)));
        try result_list.append(allocator, item);
    }

    return Dynamic.initList(result_list);
}
