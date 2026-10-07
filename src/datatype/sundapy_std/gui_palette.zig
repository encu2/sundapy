// ============================================================================
// SundaPy GUI Engine - Color Utilities & Palettes
// ============================================================================

pub const ColorRGB = struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const COLOR_BLACK = ColorRGB{ .r = 0.0, .g = 0.0, .b = 0.0 };
pub const COLOR_WHITE = ColorRGB{ .r = 252.0, .g = 252.0, .b = 252.0 };
pub const COLOR_RED = ColorRGB{ .r = 240.0, .g = 32.0, .b = 32.0 };
pub const COLOR_GREEN = ColorRGB{ .r = 32.0, .g = 220.0, .b = 32.0 };
pub const COLOR_BLUE = ColorRGB{ .r = 32.0, .g = 96.0, .b = 240.0 };
pub const COLOR_YELLOW = ColorRGB{ .r = 252.0, .g = 224.0, .b = 0.0 };
pub const COLOR_CYAN = ColorRGB{ .r = 0.0, .g = 220.0, .b = 240.0 };
pub const COLOR_MAGENTA = ColorRGB{ .r = 240.0, .g = 32.0, .b = 220.0 };

// Classic 64-Color Palette (RGB)
pub const COLOR_SKY = [3]f32{ 92.0, 148.0, 252.0 };
pub const COLOR_SKY_HORIZON = [3]f32{ 148.0, 192.0, 252.0 };
pub const COLOR_CLOUD_WHITE = [3]f32{ 252.0, 252.0, 252.0 };
pub const COLOR_CLOUD_SHADOW = [3]f32{ 216.0, 224.0, 252.0 };
pub const COLOR_HILL_DARK = [3]f32{ 0.0, 100.0, 0.0 };
pub const COLOR_HILL_LIGHT = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_HILL_SPOT = [3]f32{ 0.0, 80.0, 0.0 };
pub const COLOR_BUSH_GREEN = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_BUSH_DARK = [3]f32{ 0.0, 80.0, 0.0 };
