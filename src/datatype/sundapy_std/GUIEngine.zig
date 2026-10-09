const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const GpuBuffer = @import("datatype/gpu_types.zig").GpuBuffer;

pub const batch = @import("gui_batch.zig");
pub const clip = @import("gui_clip.zig");
pub const command = @import("gui_command.zig");
pub const font = @import("gui_font.zig");
pub const palette = @import("gui_palette.zig");
pub const pool = @import("gui_pool.zig");
pub const primitives = @import("gui_primitives.zig");
pub const surface = @import("gui_surface.zig");
pub const compress = @import("gui_compress.zig");

pub const name = Dynamic.initStr("GUIEngine");

// Palette re-exports
pub const ColorRGB = palette.ColorRGB;
pub const ColorRGBA8 = palette.ColorRGBA8;
pub const COLOR_BLACK = palette.COLOR_BLACK;
pub const COLOR_WHITE = palette.COLOR_WHITE;
pub const COLOR_RED = palette.COLOR_RED;
pub const COLOR_GREEN = palette.COLOR_GREEN;
pub const COLOR_BLUE = palette.COLOR_BLUE;
pub const COLOR_YELLOW = palette.COLOR_YELLOW;
pub const COLOR_CYAN = palette.COLOR_CYAN;
pub const COLOR_MAGENTA = palette.COLOR_MAGENTA;
pub const COLOR_SKY = palette.COLOR_SKY;
pub const COLOR_SKY_HORIZON = palette.COLOR_SKY_HORIZON;
pub const COLOR_CLOUD_WHITE = palette.COLOR_CLOUD_WHITE;
pub const COLOR_CLOUD_SHADOW = palette.COLOR_CLOUD_SHADOW;
pub const COLOR_HILL_DARK = palette.COLOR_HILL_DARK;
pub const COLOR_HILL_LIGHT = palette.COLOR_HILL_LIGHT;
pub const COLOR_HILL_SPOT = palette.COLOR_HILL_SPOT;
pub const COLOR_BUSH_GREEN = palette.COLOR_BUSH_GREEN;
pub const COLOR_BUSH_DARK = palette.COLOR_BUSH_DARK;

// Primitives re-exports
pub const create_surface = primitives.create_surface;
pub const clear_surface = primitives.clear_surface;
pub const sync = primitives.sync;
pub const draw_pixel_slice = primitives.draw_pixel_slice;
pub const draw_rect_slice = primitives.draw_rect_slice;
pub const draw_line_slice = primitives.draw_line_slice;
pub const draw_circle_slice = primitives.draw_circle_slice;
pub const blit_surface = primitives.blit_surface;
pub const blit_surface_slice = primitives.blit_surface_slice;
pub const rgb_to_bgr = primitives.rgb_to_bgr;

// Font re-exports
pub const getCharGlyph = font.getCharGlyph;
pub const getPackedGlyph = font.getPackedGlyph;
pub const registerCustomGlyph = font.registerCustomGlyph;
pub const measure_text = font.measure_text;
pub const measureTextMultiline = font.measureTextMultiline;
pub const draw_text_fast = font.draw_text_fast;
pub const draw_text = font.draw_text;
pub const draw_text_slice = font.draw_text_slice;

// Conventional aliases
pub const clear = clear_surface;
pub const blit = blit_surface;

// Scene & Memory Pool APIs
pub fn begin_scene() anyerror!Dynamic {
    pool.getGlobalScene().begin();
    return Dynamic.initNone();
}

pub fn scene_clear(r_dyn: Dynamic, g_dyn: Dynamic, b_dyn: Dynamic) anyerror!Dynamic {
    const r: u8 = if (r_dyn.value == .i64_type) @intCast(@max(0, @min(255, r_dyn.value.i64_type))) else 0;
    const g: u8 = if (g_dyn.value == .i64_type) @intCast(@max(0, @min(255, g_dyn.value.i64_type))) else 0;
    const b: u8 = if (b_dyn.value == .i64_type) @intCast(@max(0, @min(255, b_dyn.value.i64_type))) else 0;
    pool.getGlobalScene().clearSurface(r, g, b);
    return Dynamic.initNone();
}

pub fn scene_draw_rect(
    x_dyn: Dynamic,
    y_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
    fill_dyn: Dynamic,
) anyerror!Dynamic {
    const x: i16 = if (x_dyn.value == .i64_type) @intCast(x_dyn.value.i64_type) else 0;
    const y: i16 = if (y_dyn.value == .i64_type) @intCast(y_dyn.value.i64_type) else 0;
    const w: u16 = if (w_dyn.value == .i64_type) @intCast(@max(0, w_dyn.value.i64_type)) else 10;
    const h: u16 = if (h_dyn.value == .i64_type) @intCast(@max(0, h_dyn.value.i64_type)) else 10;
    const r: u8 = if (r_dyn.value == .i64_type) @intCast(@max(0, @min(255, r_dyn.value.i64_type))) else 255;
    const g: u8 = if (g_dyn.value == .i64_type) @intCast(@max(0, @min(255, g_dyn.value.i64_type))) else 255;
    const b: u8 = if (b_dyn.value == .i64_type) @intCast(@max(0, @min(255, b_dyn.value.i64_type))) else 255;
    const fill = if (fill_dyn.value == .bool_type) fill_dyn.value.bool_type else true;

    pool.getGlobalScene().drawRect(x, y, w, h, ColorRGBA8.init(r, g, b, 255), fill);
    return Dynamic.initNone();
}

pub fn scene_draw_rect_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len < 7) return Dynamic.initNone();
    const fill = if (args.len > 7) args[7] else Dynamic.initBool(true);
    return scene_draw_rect(args[0], args[1], args[2], args[3], args[4], args[5], args[6], fill);
}

pub fn scene_draw_line(
    x0_dyn: Dynamic,
    y0_dyn: Dynamic,
    x1_dyn: Dynamic,
    y1_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
) anyerror!Dynamic {
    const x0: i16 = if (x0_dyn.value == .i64_type) @intCast(x0_dyn.value.i64_type) else 0;
    const y0: i16 = if (y0_dyn.value == .i64_type) @intCast(y0_dyn.value.i64_type) else 0;
    const x1: i16 = if (x1_dyn.value == .i64_type) @intCast(x1_dyn.value.i64_type) else 0;
    const y1: i16 = if (y1_dyn.value == .i64_type) @intCast(y1_dyn.value.i64_type) else 0;
    const r: u8 = if (r_dyn.value == .i64_type) @intCast(@max(0, @min(255, r_dyn.value.i64_type))) else 255;
    const g: u8 = if (g_dyn.value == .i64_type) @intCast(@max(0, @min(255, g_dyn.value.i64_type))) else 255;
    const b: u8 = if (b_dyn.value == .i64_type) @intCast(@max(0, @min(255, b_dyn.value.i64_type))) else 255;

    pool.getGlobalScene().drawLine(x0, y0, x1, y1, ColorRGBA8.init(r, g, b, 255));
    return Dynamic.initNone();
}

pub fn scene_draw_line_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len < 7) return Dynamic.initNone();
    return scene_draw_line(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
}

pub fn scene_draw_text(
    x_dyn: Dynamic,
    y_dyn: Dynamic,
    text_dyn: Dynamic,
    scale_dyn: Dynamic,
    r_dyn: Dynamic,
    g_dyn: Dynamic,
    b_dyn: Dynamic,
) anyerror!Dynamic {
    const x: i16 = if (x_dyn.value == .i64_type) @intCast(x_dyn.value.i64_type) else 0;
    const y: i16 = if (y_dyn.value == .i64_type) @intCast(y_dyn.value.i64_type) else 0;
    const text = if (text_dyn.value == .str_type) text_dyn.value.str_type else "";
    const scale: u8 = if (scale_dyn.value == .i64_type) @intCast(@max(1, scale_dyn.value.i64_type)) else 1;
    const r: u8 = if (r_dyn.value == .i64_type) @intCast(@max(0, @min(255, r_dyn.value.i64_type))) else 255;
    const g: u8 = if (g_dyn.value == .i64_type) @intCast(@max(0, @min(255, g_dyn.value.i64_type))) else 255;
    const b: u8 = if (b_dyn.value == .i64_type) @intCast(@max(0, @min(255, b_dyn.value.i64_type))) else 255;

    pool.getGlobalScene().drawText(x, y, text, scale, ColorRGBA8.init(r, g, b, 255));
    return Dynamic.initNone();
}

pub fn scene_draw_text_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len < 6) return Dynamic.initNone();
    const b = if (args.len > 6) args[6] else Dynamic.initInt(255);
    return scene_draw_text(args[0], args[1], args[2], args[3], args[4], args[5], b);
}

pub fn scene_set_clip(x_dyn: Dynamic, y_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    const x: i32 = if (x_dyn.value == .i64_type) @intCast(x_dyn.value.i64_type) else 0;
    const y: i32 = if (y_dyn.value == .i64_type) @intCast(y_dyn.value.i64_type) else 0;
    const w: i32 = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 0;
    const h: i32 = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 0;
    pool.getGlobalScene().setClipRect(x, y, w, h);
    return Dynamic.initNone();
}

pub fn scene_reset_clip() anyerror!Dynamic {
    pool.getGlobalScene().resetClipRect();
    return Dynamic.initNone();
}

pub fn render_scene(buf_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return Dynamic.initNone();
    const buf: *primitives.GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const w: usize = if (w_dyn.value == .i64_type) @intCast(w_dyn.value.i64_type) else 256;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(h_dyn.value.i64_type) else 240;

    pool.getGlobalScene().render(buf, w, h);
    return Dynamic.initNone();
}

pub fn get_memory_stats() anyerror!Dynamic {
    const sc = pool.getGlobalScene();
    const rep = sc.pool.getMemoryReport();
    var d = Dynamic.initDict(std.heap.c_allocator);
    try d.value.dict_type.put(Dynamic.initStr("pool_capacity"), Dynamic.initInt(@intCast(rep.capacity)));
    try d.value.dict_type.put(Dynamic.initStr("pool_used"), Dynamic.initInt(@intCast(rep.used)));
    try d.value.dict_type.put(Dynamic.initStr("pool_peak"), Dynamic.initInt(@intCast(rep.peak)));
    try d.value.dict_type.put(Dynamic.initStr("total_instances"), Dynamic.initInt(@intCast(sc.batcher.getTotalInstances())));
    try d.value.dict_type.put(Dynamic.initStr("shared_palettes"), Dynamic.initInt(@intCast(palette.getSharedPaletteCount())));
    return d;
}

pub fn get_memory_stats_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = args;
    _ = kwargs;
    return get_memory_stats();
}

pub fn compress_surface(surface_dyn: Dynamic, codec_dyn: Dynamic) anyerror!Dynamic {
    const codec = if (codec_dyn.value == .str_type) codec_dyn.value.str_type else "rle";
    return compress.compressSurface(std.heap.c_allocator, surface_dyn, codec);
}

pub fn compress_surface_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const codec_dyn = if (args.len > 1) args[1] else Dynamic.initStr("rle");
    return compress_surface(args[0], codec_dyn);
}

pub fn decompress_surface(comp_dyn: Dynamic) anyerror!Dynamic {
    return compress.decompressSurface(std.heap.c_allocator, comp_dyn, null);
}

pub fn decompress_surface_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const out_dyn = if (args.len > 1) args[1] else null;
    return compress.decompressSurface(std.heap.c_allocator, args[0], out_dyn);
}

pub fn compress_ratio(surface_dyn: Dynamic, codec_dyn: Dynamic) anyerror!Dynamic {
    const codec = if (codec_dyn.value == .str_type) codec_dyn.value.str_type else "rle";
    return compress.compressRatio(surface_dyn, codec);
}

pub fn compress_ratio_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    const codec_dyn = if (args.len > 1) args[1] else Dynamic.initStr("rle");
    return compress_ratio(args[0], codec_dyn);
}

pub fn get_surface_stats(surf_dyn: Dynamic) anyerror!Dynamic {
    if (surf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(surf_dyn.value.gpu_buffer_type));
    var d = Dynamic.initDict(std.heap.c_allocator);
    const bytes = buf.size * buf.dtype.sizeOf();
    const mb: f32 = @as(f32, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    try d.value.dict_type.put(Dynamic.initStr("size"), Dynamic.initInt(@intCast(buf.size)));
    try d.value.dict_type.put(Dynamic.initStr("bytes"), Dynamic.initInt(@intCast(bytes)));
    try d.value.dict_type.put(Dynamic.initStr("mb"), Dynamic.initFloat(@floatCast(mb)));
    return d;
}

pub fn get_surface_stats_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    return get_surface_stats(args[0]);
}

pub fn benchmark_surface(surface_dyn: Dynamic) anyerror!Dynamic {
    return compress.benchmarkSurface(std.heap.c_allocator, surface_dyn);
}

pub fn benchmark_surface_slice(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    return benchmark_surface(args[0]);
}

pub fn render_game_scene(alloc: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = alloc;
    _ = kwargs;
    if (args.len > 0 and args[0].value == .gpu_buffer_type) {
        _ = primitives.clear_surface(args[0], Dynamic.initFloat(92.0), Dynamic.initFloat(148.0), Dynamic.initFloat(252.0)) catch {};
    }
    return Dynamic.initNone();
}
pub const render_mario_frame = render_game_scene;

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "create_surface")) return @import("datatype/dynamic.zig").toDynamicFunc(create_surface);
    if (std.mem.eql(u8, attr, "clear")) return @import("datatype/dynamic.zig").toDynamicFunc(clear_surface);
    if (std.mem.eql(u8, attr, "clear_surface")) return @import("datatype/dynamic.zig").toDynamicFunc(clear_surface);
    if (std.mem.eql(u8, attr, "sync")) return @import("datatype/dynamic.zig").toDynamicFunc(sync);
    if (std.mem.eql(u8, attr, "draw_pixel")) return Dynamic{ .value = .{ .func_type_slice = draw_pixel_slice } };
    if (std.mem.eql(u8, attr, "draw_rect")) return Dynamic{ .value = .{ .func_type_slice = draw_rect_slice } };
    if (std.mem.eql(u8, attr, "draw_line")) return Dynamic{ .value = .{ .func_type_slice = draw_line_slice } };
    if (std.mem.eql(u8, attr, "draw_circle")) return Dynamic{ .value = .{ .func_type_slice = draw_circle_slice } };
    if (std.mem.eql(u8, attr, "draw_text")) return Dynamic{ .value = .{ .func_type_slice = draw_text_slice } };
    if (std.mem.eql(u8, attr, "blit")) return Dynamic{ .value = .{ .func_type_slice = blit_surface_slice } };
    if (std.mem.eql(u8, attr, "blit_surface")) return Dynamic{ .value = .{ .func_type_slice = blit_surface_slice } };
    if (std.mem.eql(u8, attr, "rgb_to_bgr")) return @import("datatype/dynamic.zig").toDynamicFunc(rgb_to_bgr);
    if (std.mem.eql(u8, attr, "begin_scene")) return @import("datatype/dynamic.zig").toDynamicFunc(begin_scene);
    if (std.mem.eql(u8, attr, "scene_clear")) return @import("datatype/dynamic.zig").toDynamicFunc(scene_clear);
    if (std.mem.eql(u8, attr, "scene_draw_rect")) return Dynamic{ .value = .{ .func_type_slice = scene_draw_rect_slice } };
    if (std.mem.eql(u8, attr, "scene_draw_line")) return Dynamic{ .value = .{ .func_type_slice = scene_draw_line_slice } };
    if (std.mem.eql(u8, attr, "scene_draw_text")) return Dynamic{ .value = .{ .func_type_slice = scene_draw_text_slice } };
    if (std.mem.eql(u8, attr, "scene_set_clip")) return @import("datatype/dynamic.zig").toDynamicFunc(scene_set_clip);
    if (std.mem.eql(u8, attr, "scene_reset_clip")) return @import("datatype/dynamic.zig").toDynamicFunc(scene_reset_clip);
    if (std.mem.eql(u8, attr, "render_scene")) return @import("datatype/dynamic.zig").toDynamicFunc(render_scene);
    if (std.mem.eql(u8, attr, "compress_surface")) return Dynamic{ .value = .{ .func_type_slice = compress_surface_slice } };
    if (std.mem.eql(u8, attr, "decompress_surface")) return Dynamic{ .value = .{ .func_type_slice = decompress_surface_slice } };
    if (std.mem.eql(u8, attr, "compress_ratio")) return Dynamic{ .value = .{ .func_type_slice = compress_ratio_slice } };
    if (std.mem.eql(u8, attr, "get_surface_stats") or std.mem.eql(u8, attr, "surface_stats")) return Dynamic{ .value = .{ .func_type_slice = get_surface_stats_slice } };
    if (std.mem.eql(u8, attr, "benchmark_surface")) return Dynamic{ .value = .{ .func_type_slice = benchmark_surface_slice } };
    if (std.mem.eql(u8, attr, "get_memory_stats")) return Dynamic{ .value = .{ .func_type_slice = get_memory_stats_slice } };
    if (std.mem.eql(u8, attr, "render_game_scene")) return Dynamic{ .value = .{ .func_type_slice = render_game_scene } };
    if (std.mem.eql(u8, attr, "render_mario_frame")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame } };
    return error.AttributeError;
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}
