const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

pub const palette = @import("gui_palette.zig");
pub const primitives = @import("gui_primitives.zig");
pub const font = @import("gui_font.zig");

pub const name = Dynamic.initStr("GUIEngine");

// Palette re-exports
pub const ColorRGB = palette.ColorRGB;
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
pub const draw_pixel = primitives.draw_pixel;
pub const draw_pixel_slice = primitives.draw_pixel_slice;
pub const draw_rect = primitives.draw_rect;
pub const draw_line = primitives.draw_line;
pub const draw_circle = primitives.draw_circle;
pub const blit_surface = primitives.blit_surface;
pub const rgb_to_bgr = primitives.rgb_to_bgr;

// Font re-exports
pub const getCharGlyph = font.getCharGlyph;
pub const draw_text_fast = font.draw_text_fast;
pub const draw_text = font.draw_text;

// Conventional aliases
pub const clear = clear_surface;
pub const blit = blit_surface;

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
    if (std.mem.eql(u8, attr, "draw_rect")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_rect);
    if (std.mem.eql(u8, attr, "draw_line")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_line);
    if (std.mem.eql(u8, attr, "draw_circle")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_circle);
    if (std.mem.eql(u8, attr, "draw_text")) return @import("datatype/dynamic.zig").toDynamicFunc(draw_text);
    if (std.mem.eql(u8, attr, "blit")) return @import("datatype/dynamic.zig").toDynamicFunc(blit_surface);
    if (std.mem.eql(u8, attr, "rgb_to_bgr")) return @import("datatype/dynamic.zig").toDynamicFunc(rgb_to_bgr);
    if (std.mem.eql(u8, attr, "render_game_scene")) return Dynamic{ .value = .{ .func_type_slice = render_game_scene } };
    if (std.mem.eql(u8, attr, "render_mario_frame")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame } };
    return error.AttributeError;
}

pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {}

