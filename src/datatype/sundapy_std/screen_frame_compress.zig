const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const screen_compress = @import("screen_compress.zig");

// ============================================================================
// Framebuffer-Level Tile Compression & Bandwidth Reduction Subsystem
// Splits frame into 16x16 tiles and applies temporal delta, RLE, and solid deduplication
// ============================================================================

pub var last_frame_pixels: ?[]u32 = null;
pub var last_frame_width: usize = 0;
pub var last_frame_height: usize = 0;

pub fn getCompressionStats(allocator: std.mem.Allocator) !Dynamic {
    var dict = Dynamic.initDict(allocator);
    const uncomp = screen_compress.stats_total_uncompressed;
    const comp = screen_compress.stats_total_compressed;
    const saved = screen_compress.stats_saved_bandwidth;
    const ratio = screen_compress.getCompressionRatio();
    const savings_pct = if (uncomp > 0) (@as(f64, @floatFromInt(saved)) / @as(f64, @floatFromInt(uncomp))) * 100.0 else 0.0;

    try dict.value.dict_type.put(Dynamic.initStr("uncompressed_bytes"), Dynamic.initInt(@intCast(uncomp)));
    try dict.value.dict_type.put(Dynamic.initStr("compressed_bytes"), Dynamic.initInt(@intCast(comp)));
    try dict.value.dict_type.put(Dynamic.initStr("saved_bandwidth_bytes"), Dynamic.initInt(@intCast(saved)));
    try dict.value.dict_type.put(Dynamic.initStr("compression_ratio"), Dynamic.initFloat(@floatCast(ratio)));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings_pct)));
    try dict.value.dict_type.put(Dynamic.initStr("clean_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_clean_tiles)));
    try dict.value.dict_type.put(Dynamic.initStr("solid_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_solid_tiles)));
    try dict.value.dict_type.put(Dynamic.initStr("palette2_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_palette2_tiles)));
    try dict.value.dict_type.put(Dynamic.initStr("palette4_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_palette4_tiles)));
    try dict.value.dict_type.put(Dynamic.initStr("rle_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_rle_tiles)));
    try dict.value.dict_type.put(Dynamic.initStr("raw_tiles"), Dynamic.initInt(@intCast(screen_compress.stats_raw_tiles)));
    return dict;
}

pub fn compressFramebuffer(allocator: std.mem.Allocator, buf: *GpuBuffer, w: usize, h: usize) !Dynamic {
    const tile_w = screen_compress.TILE_SIZE;
    const tile_h = screen_compress.TILE_SIZE;
    const tiles_x = (w + tile_w - 1) / tile_w;
    const tiles_y = (h + tile_h - 1) / tile_h;

    // Convert f32 RGB/BGRA buffer data to packed u32
    const total_pixels = w * h;
    const current_pixels = try allocator.alloc(u32, total_pixels);
    defer allocator.free(current_pixels);

    if (buf.data.len >= total_pixels * 3) {
        // 3 floats per pixel RGB
        for (0..total_pixels) |i| {
            const r: u32 = @intFromFloat(std.math.clamp(buf.data[i * 3], 0.0, 255.0));
            const g: u32 = @intFromFloat(std.math.clamp(buf.data[i * 3 + 1], 0.0, 255.0));
            const b: u32 = @intFromFloat(std.math.clamp(buf.data[i * 3 + 2], 0.0, 255.0));
            current_pixels[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
        }
    } else {
        // Direct or 1 float per pixel
        for (0..@min(total_pixels, buf.data.len)) |i| {
            current_pixels[i] = @intFromFloat(buf.data[i]);
        }
    }

    var prev_pixels_ptr: ?[*]const u32 = null;
    if (last_frame_pixels != null and last_frame_width == w and last_frame_height == h) {
        prev_pixels_ptr = last_frame_pixels.?.ptr;
    }

    var comp_payload = std.ArrayList(u8).empty;
    defer comp_payload.deinit(allocator);

    var tile_scratch: [1024 * 4]u8 = undefined;
    var clean_count: usize = 0;
    var solid_count: usize = 0;
    var rle_count: usize = 0;
    var raw_count: usize = 0;

    var ty: usize = 0;
    while (ty < tiles_y) : (ty += 1) {
        var tx: usize = 0;
        while (tx < tiles_x) : (tx += 1) {
            const actual_tw = @min(tile_w, w - tx * tile_w);
            const actual_th = @min(tile_h, h - ty * tile_h);
            const curr_offset = (ty * tile_h) * w + (tx * tile_w);
            const curr_tile_ptr = current_pixels.ptr + curr_offset;
            const prev_tile_ptr = if (prev_pixels_ptr) |p| p + curr_offset else null;

            const res = screen_compress.compressTile(
                curr_tile_ptr,
                prev_tile_ptr,
                actual_tw,
                actual_th,
                w,
                w,
                &tile_scratch,
            );

            switch (res.tile_type) {
                .clean => clean_count += 1,
                .solid => solid_count += 1,
                .palette2, .palette4, .rle, .delta_rle => rle_count += 1,
                .raw => raw_count += 1,
            }

            // Write tile header: type (1B), payload_len (2B)
            try comp_payload.append(allocator, @intFromEnum(res.tile_type));
            var len_bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &len_bytes, @intCast(res.bytes_written), .little);
            try comp_payload.appendSlice(allocator, &len_bytes);

            if (res.bytes_written > 0) {
                try comp_payload.appendSlice(allocator, tile_scratch[0..res.bytes_written]);
            }
        }
    }

    // Cache current frame for next delta comparison
    if (last_frame_pixels == null or last_frame_pixels.?.len != total_pixels) {
        if (last_frame_pixels) |old| allocator.free(old);
        last_frame_pixels = try allocator.alloc(u32, total_pixels);
    }
    @memcpy(last_frame_pixels.?, current_pixels);
    last_frame_width = w;
    last_frame_height = h;

    const uncomp_bytes = w * h * 4;
    const comp_bytes = comp_payload.items.len;
    const ratio: f64 = if (comp_bytes > 0) @as(f64, @floatFromInt(uncomp_bytes)) / @as(f64, @floatFromInt(comp_bytes)) else 1.0;
    const savings: f64 = if (uncomp_bytes > comp_bytes) (@as(f64, @floatFromInt(uncomp_bytes - comp_bytes)) / @as(f64, @floatFromInt(uncomp_bytes))) * 100.0 else 0.0;

    var dict = Dynamic.initDict(allocator);
    try dict.value.dict_type.put(Dynamic.initStr("width"), Dynamic.initInt(@intCast(w)));
    try dict.value.dict_type.put(Dynamic.initStr("height"), Dynamic.initInt(@intCast(h)));
    try dict.value.dict_type.put(Dynamic.initStr("tiles_x"), Dynamic.initInt(@intCast(tiles_x)));
    try dict.value.dict_type.put(Dynamic.initStr("tiles_y"), Dynamic.initInt(@intCast(tiles_y)));
    try dict.value.dict_type.put(Dynamic.initStr("original_bytes"), Dynamic.initInt(@intCast(uncomp_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("uncompressed_bytes"), Dynamic.initInt(@intCast(uncomp_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("compressed_bytes"), Dynamic.initInt(@intCast(comp_bytes)));
    try dict.value.dict_type.put(Dynamic.initStr("ratio"), Dynamic.initFloat(@floatCast(ratio)));
    try dict.value.dict_type.put(Dynamic.initStr("compression_ratio"), Dynamic.initFloat(@floatCast(ratio)));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(@floatCast(savings)));
    try dict.value.dict_type.put(Dynamic.initStr("clean_tiles"), Dynamic.initInt(@intCast(clean_count)));
    try dict.value.dict_type.put(Dynamic.initStr("solid_tiles"), Dynamic.initInt(@intCast(solid_count)));
    try dict.value.dict_type.put(Dynamic.initStr("rle_tiles"), Dynamic.initInt(@intCast(rle_count)));
    try dict.value.dict_type.put(Dynamic.initStr("raw_tiles"), Dynamic.initInt(@intCast(raw_count)));
    return dict;
}
