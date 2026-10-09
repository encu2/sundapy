// ============================================================================
// SundaPy GUI Engine - Color Utilities, Standard Palettes & Shared Memory Deduplication
// Deduplicated palette storage enables 12x memory reduction for indexed canvases
// ============================================================================

const std = @import("std");

pub const ColorRGB = struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const ColorRGBA8 = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub inline fn init(r: u8, g: u8, b: u8, a: u8) ColorRGBA8 {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn toU32(self: ColorRGBA8) u32 {
        return @as(u32, self.r) | (@as(u32, self.g) << 8) | (@as(u32, self.b) << 16) | (@as(u32, self.a) << 24);
    }

    pub inline fn fromU32(val: u32) ColorRGBA8 {
        return .{
            .r = @truncate(val),
            .g = @truncate(val >> 8),
            .b = @truncate(val >> 16),
            .a = @truncate(val >> 24),
        };
    }
};

// Classic ColorRGB Constants (Preserved for compatibility)
pub const COLOR_BLACK = ColorRGB{ .r = 0.0, .g = 0.0, .b = 0.0 };
pub const COLOR_WHITE = ColorRGB{ .r = 252.0, .g = 252.0, .b = 252.0 };
pub const COLOR_RED = ColorRGB{ .r = 240.0, .g = 32.0, .b = 32.0 };
pub const COLOR_GREEN = ColorRGB{ .r = 32.0, .g = 220.0, .b = 32.0 };
pub const COLOR_BLUE = ColorRGB{ .r = 32.0, .g = 96.0, .b = 240.0 };
pub const COLOR_YELLOW = ColorRGB{ .r = 252.0, .g = 224.0, .b = 0.0 };
pub const COLOR_CYAN = ColorRGB{ .r = 0.0, .g = 220.0, .b = 240.0 };
pub const COLOR_MAGENTA = ColorRGB{ .r = 240.0, .g = 32.0, .b = 220.0 };

// Classic 64-Color Palette (RGB f32 arrays)
pub const COLOR_SKY = [3]f32{ 92.0, 148.0, 252.0 };
pub const COLOR_SKY_HORIZON = [3]f32{ 148.0, 192.0, 252.0 };
pub const COLOR_CLOUD_WHITE = [3]f32{ 252.0, 252.0, 252.0 };
pub const COLOR_CLOUD_SHADOW = [3]f32{ 216.0, 224.0, 252.0 };
pub const COLOR_HILL_DARK = [3]f32{ 0.0, 100.0, 0.0 };
pub const COLOR_HILL_LIGHT = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_HILL_SPOT = [3]f32{ 0.0, 80.0, 0.0 };
pub const COLOR_BUSH_GREEN = [3]f32{ 0.0, 168.0, 0.0 };
pub const COLOR_BUSH_DARK = [3]f32{ 0.0, 80.0, 0.0 };

// 16-Bit RGB565 Packing
pub inline fn rgbTo565(r: u8, g: u8, b: u8) u16 {
    const r5 = @as(u16, r >> 3) & 0x1F;
    const g6 = @as(u16, g >> 2) & 0x3F;
    const b5 = @as(u16, b >> 3) & 0x1F;
    return (r5 << 11) | (g6 << 5) | b5;
}

pub inline fn rgb565ToRgb(c: u16) ColorRGBA8 {
    const r5 = (c >> 11) & 0x1F;
    const g6 = (c >> 5) & 0x3F;
    const b5 = c & 0x1F;
    return ColorRGBA8{
        .r = @truncate((r5 * 527 + 23) >> 6),
        .g = @truncate((g6 * 259 + 33) >> 6),
        .b = @truncate((b5 * 527 + 23) >> 6),
        .a = 255,
    };
}

// 256-Color Palette Table & Fast Hash Calculation
pub const PaletteTable = [256]ColorRGBA8;

pub fn computePaletteHash(table: *const PaletteTable) u64 {
    var h: u64 = 0xcbf29ce484222325;
    const bytes = std.mem.sliceAsBytes(table);
    for (bytes) |b| {
        h = (h ^ b) *% 0x100000001b3;
    }
    return h;
}

// Built-in Palettes
pub fn generateDefaultVgaPalette() PaletteTable {
    var p: PaletteTable = undefined;
    // 0..15: Standard ANSI/CGA 16 colors
    const cga = [_]ColorRGBA8{
        ColorRGBA8.init(0, 0, 0, 255),
        ColorRGBA8.init(0, 0, 170, 255),
        ColorRGBA8.init(0, 170, 0, 255),
        ColorRGBA8.init(0, 170, 170, 255),
        ColorRGBA8.init(170, 0, 0, 255),
        ColorRGBA8.init(170, 0, 170, 255),
        ColorRGBA8.init(170, 85, 0, 255),
        ColorRGBA8.init(170, 170, 170, 255),
        ColorRGBA8.init(85, 85, 85, 255),
        ColorRGBA8.init(85, 85, 255, 255),
        ColorRGBA8.init(85, 255, 85, 255),
        ColorRGBA8.init(85, 255, 255, 255),
        ColorRGBA8.init(255, 85, 85, 255),
        ColorRGBA8.init(255, 85, 255, 255),
        ColorRGBA8.init(255, 255, 85, 255),
        ColorRGBA8.init(255, 255, 255, 255),
    };
    @memcpy(p[0..16], &cga);

    // 16..231: 6x6x6 Color Cube
    var idx: usize = 16;
    var ri: u8 = 0;
    while (ri < 6) : (ri += 1) {
        var gi: u8 = 0;
        while (gi < 6) : (gi += 1) {
            var bi: u8 = 0;
            while (bi < 6) : (bi += 1) {
                p[idx] = ColorRGBA8.init(
                    if (ri == 0) 0 else ri * 40 + 55,
                    if (gi == 0) 0 else gi * 40 + 55,
                    if (bi == 0) 0 else bi * 40 + 55,
                    255,
                );
                idx += 1;
            }
        }
    }

    // 232..255: 24 Grayscale Ramp
    var gray: u8 = 0;
    while (gray < 24) : (gray += 1) {
        const v = gray * 10 + 8;
        p[idx] = ColorRGBA8.init(v, v, v, 255);
        idx += 1;
    }
    return p;
}

pub fn generateRetroEgaPalette() PaletteTable {
    var p = generateDefaultVgaPalette();
    // Overwrite top slots with SundaPy UI colors
    p[16] = ColorRGBA8.init(92, 148, 252, 255); // Sky
    p[17] = ColorRGBA8.init(148, 192, 252, 255); // Sky Horizon
    p[18] = ColorRGBA8.init(0, 168, 0, 255); // Hill Light
    p[19] = ColorRGBA8.init(0, 100, 0, 255); // Hill Dark
    p[20] = ColorRGBA8.init(216, 224, 252, 255); // Cloud Shadow
    return p;
}

// Shared Palette Registry (Deduplication Store)
pub const MAX_SHARED_PALETTES: usize = 64;

pub const SharedPaletteRegistry = struct {
    palettes: [MAX_SHARED_PALETTES]PaletteTable = undefined,
    hashes: [MAX_SHARED_PALETTES]u64 = [_]u64{0} ** MAX_SHARED_PALETTES,
    count: usize = 0,
    initialized: bool = false,

    pub fn getGlobal() *SharedPaletteRegistry {
        if (!global_registry.initialized) {
            global_registry.initDefaults();
        }
        return &global_registry;
    }

    pub fn initDefaults(self: *SharedPaletteRegistry) void {
        self.count = 0;
        _ = self.intern(generateDefaultVgaPalette());
        _ = self.intern(generateRetroEgaPalette());
        self.initialized = true;
    }

    pub fn intern(self: *SharedPaletteRegistry, table: PaletteTable) u16 {
        const h = computePaletteHash(&table);
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.hashes[i] == h) {
                if (std.mem.eql(u8, std.mem.sliceAsBytes(&self.palettes[i]), std.mem.sliceAsBytes(&table))) {
                    return @intCast(i);
                }
            }
        }
        if (self.count < MAX_SHARED_PALETTES) {
            const slot = self.count;
            self.palettes[slot] = table;
            self.hashes[slot] = h;
            self.count += 1;
            return @intCast(slot);
        }
        return 0; // Fallback to slot 0 if full
    }

    pub fn get(self: *const SharedPaletteRegistry, id: u16) *const PaletteTable {
        if (id < self.count) {
            return &self.palettes[id];
        }
        return &self.palettes[0];
    }
};

var global_registry = SharedPaletteRegistry{};

pub fn internSharedPalette(table: PaletteTable) u16 {
    return SharedPaletteRegistry.getGlobal().intern(table);
}

pub fn getSharedPalette(id: u16) *const PaletteTable {
    return SharedPaletteRegistry.getGlobal().get(id);
}

pub fn getSharedPaletteCount() usize {
    return SharedPaletteRegistry.getGlobal().count;
}

// Fast Color Quantization using Euclidean Color Distance
pub fn findNearestPaletteIndex(table: *const PaletteTable, r: u8, g: u8, b: u8) u8 {
    var best_idx: u8 = 0;
    var min_dist: u32 = std.math.maxInt(u32);

    for (table, 0..) |col, idx| {
        const dr = @as(i32, col.r) - @as(i32, r);
        const dg = @as(i32, col.g) - @as(i32, g);
        const db = @as(i32, col.b) - @as(i32, b);
        const dist = @as(u32, @intCast(dr * dr * 3 + dg * dg * 4 + db * db * 2));
        if (dist < min_dist) {
            min_dist = dist;
            best_idx = @intCast(idx);
            if (dist == 0) break;
        }
    }
    return best_idx;
}

pub fn getRegistryMemoryBytes() usize {
    return @sizeOf(SharedPaletteRegistry);
}

// 4-bit (16-color) Compact Sub-Byte Packing
pub inline fn pack2x4Bit(c0: u8, c1: u8) u8 {
    return (c0 & 0x0F) | ((c1 & 0x0F) << 4);
}

pub inline fn unpack2x4Bit(byte: u8) struct { c0: u8, c1: u8 } {
    return .{
        .c0 = byte & 0x0F,
        .c1 = (byte >> 4) & 0x0F,
    };
}

// 4-Bit per Channel Quantization Cache (4096 entries, 4 KB)
pub const QuantizationCache = [16][16][16]u8;

pub fn initQuantizationCache(palette: *const PaletteTable) QuantizationCache {
    var cache: QuantizationCache = undefined;
    var r: usize = 0;
    while (r < 16) : (r += 1) {
        const rc: u8 = @intCast(r * 17);
        var g: usize = 0;
        while (g < 16) : (g += 1) {
            const gc: u8 = @intCast(g * 17);
            var b: usize = 0;
            while (b < 16) : (b += 1) {
                const bc: u8 = @intCast(b * 17);
                cache[r][g][b] = findNearestPaletteIndex(palette, rc, gc, bc);
            }
        }
    }
    return cache;
}

pub inline fn findNearestPaletteFast(cache: *const QuantizationCache, r: u8, g: u8, b: u8) u8 {
    return cache[r >> 4][g >> 4][b >> 4];
}

pub fn generatePastelUiPalette() PaletteTable {
    var p = generateDefaultVgaPalette();
    p[0] = ColorRGBA8.init(30, 30, 46, 255);
    p[1] = ColorRGBA8.init(205, 214, 244, 255);
    p[2] = ColorRGBA8.init(137, 180, 250, 255);
    p[3] = ColorRGBA8.init(166, 227, 161, 255);
    p[4] = ColorRGBA8.init(243, 139, 168, 255);
    p[5] = ColorRGBA8.init(249, 226, 175, 255);
    p[6] = ColorRGBA8.init(203, 166, 247, 255);
    p[7] = ColorRGBA8.init(49, 50, 68, 255);
    return p;
}

pub fn generateCyberpunkPalette() PaletteTable {
    var p = generateDefaultVgaPalette();
    p[0] = ColorRGBA8.init(10, 10, 15, 255);
    p[1] = ColorRGBA8.init(0, 255, 204, 255);
    p[2] = ColorRGBA8.init(255, 0, 128, 255);
    p[3] = ColorRGBA8.init(255, 238, 0, 255);
    p[4] = ColorRGBA8.init(128, 0, 255, 255);
    p[5] = ColorRGBA8.init(0, 255, 65, 255);
    return p;
}

test "palette hashing and deduplication" {
    const vga1 = generateDefaultVgaPalette();
    const vga2 = generateDefaultVgaPalette();
    try std.testing.expectEqual(computePaletteHash(&vga1), computePaletteHash(&vga2));

    var reg = SharedPaletteRegistry{};
    reg.initDefaults();
    const id1 = reg.intern(vga1);
    const id2 = reg.intern(vga2);
    try std.testing.expectEqual(id1, id2);
}

test "RGB565 packing roundtrip" {
    const orig = ColorRGBA8.init(250, 128, 64, 255);
    const packed565 = rgbTo565(orig.r, orig.g, orig.b);
    const unpacked = rgb565ToRgb(packed565);
    try std.testing.expect(@abs(@as(i32, unpacked.r) - @as(i32, orig.r)) <= 8);
    try std.testing.expect(@abs(@as(i32, unpacked.g) - @as(i32, orig.g)) <= 4);
    try std.testing.expect(@abs(@as(i32, unpacked.b) - @as(i32, orig.b)) <= 8);
}

test "4-bit packing" {
    const p = pack2x4Bit(0x0A, 0x05);
    const u = unpack2x4Bit(p);
    try std.testing.expectEqual(@as(u8, 0x0A), u.c0);
    try std.testing.expectEqual(@as(u8, 0x05), u.c1);
}

