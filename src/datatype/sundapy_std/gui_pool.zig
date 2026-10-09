// ============================================================================
// SundaPy GUI Engine - Zero-Allocation Memory Pools for Render Scenes
// Pre-allocated monotonic bump arenas guarantee 0B heap churn during 60+ FPS loops
// ============================================================================

const std = @import("std");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const gui_clip = @import("gui_clip.zig");
const ClipRect = gui_clip.ClipRect;
const ScissorStack = gui_clip.ScissorStack;
const gui_palette = @import("gui_palette.zig");
const ColorRGBA8 = gui_palette.ColorRGBA8;
const gui_command = @import("gui_command.zig");
const CommandBuffer = gui_command.CommandBuffer;
const PackedDrawCommand = gui_command.PackedDrawCommand;
const gui_batch = @import("gui_batch.zig");
const InstanceBatcher = gui_batch.InstanceBatcher;
const RectInstance = gui_batch.RectInstance;
const GlyphInstance = gui_batch.GlyphInstance;
const LineInstance = gui_batch.LineInstance;
const gui_surface = @import("gui_surface.zig");
const IndexedSurface = gui_surface.IndexedSurface;

pub const MemoryReport = struct {
    capacity: usize,
    used: usize,
    peak: usize,
    utilization_pct: f32,
};

pub const SceneMemoryPool = struct {
    buffer: []u8,
    offset: usize = 0,
    peak_offset: usize = 0,
    allocator: ?std.mem.Allocator = null,

    pub fn initPreallocated(memory: []u8) SceneMemoryPool {
        return .{
            .buffer = memory,
            .offset = 0,
            .peak_offset = 0,
            .allocator = null,
        };
    }

    pub fn initAllocated(allocator: std.mem.Allocator, capacity_bytes: usize) !SceneMemoryPool {
        const mem = try allocator.alloc(u8, capacity_bytes);
        return .{
            .buffer = mem,
            .offset = 0,
            .peak_offset = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SceneMemoryPool) void {
        if (self.allocator) |al| {
            al.free(self.buffer);
        }
    }

    pub fn alloc(self: *SceneMemoryPool, comptime T: type, count: usize) ![]T {
        const align_val = @alignOf(T);
        const aligned_offset = (self.offset + (align_val - 1)) & ~@as(usize, align_val - 1);
        const bytes_needed = @sizeOf(T) * count;
        const new_offset = aligned_offset + bytes_needed;

        if (new_offset > self.buffer.len) {
            return error.OutOfMemory;
        }

        self.offset = new_offset;
        if (self.offset > self.peak_offset) {
            self.peak_offset = self.offset;
        }

        const ptr = @as([*]T, @ptrCast(@alignCast(&self.buffer[aligned_offset])));
        return ptr[0..count];
    }

    pub inline fn reset(self: *SceneMemoryPool) void {
        self.offset = 0;
    }

    pub inline fn getUsedBytes(self: *const SceneMemoryPool) usize {
        return self.offset;
    }

    pub inline fn getPeakBytes(self: *const SceneMemoryPool) usize {
        return self.peak_offset;
    }

    pub inline fn getCapacity(self: *const SceneMemoryPool) usize {
        return self.buffer.len;
    }

    pub inline fn saveCheckpoint(self: *const SceneMemoryPool) usize {
        return self.offset;
    }

    pub inline fn restoreCheckpoint(self: *SceneMemoryPool, checkpoint: usize) void {
        self.offset = @min(checkpoint, self.buffer.len);
    }

    pub fn getMemoryReport(self: *const SceneMemoryPool) MemoryReport {
        const cap = self.getCapacity();
        const used = self.getUsedBytes();
        return .{
            .capacity = cap,
            .used = used,
            .peak = self.getPeakBytes(),
            .utilization_pct = if (cap > 0) (@as(f32, @floatFromInt(used)) / @as(f32, @floatFromInt(cap))) * 100.0 else 0.0,
        };
    }
};

pub const RenderScene = struct {
    pool: *SceneMemoryPool,
    cmd_buffer: CommandBuffer,
    batcher: InstanceBatcher,
    scissor: ScissorStack,

    pub fn create(
        pool: *SceneMemoryPool,
        max_commands: usize,
        max_rects: usize,
        max_glyphs: usize,
        max_lines: usize,
        text_capacity: usize,
    ) !RenderScene {
        const cmd_mem = try pool.alloc(PackedDrawCommand, max_commands);
        const text_mem = try pool.alloc(u8, text_capacity);
        const rect_mem = try pool.alloc(RectInstance, max_rects);
        const glyph_mem = try pool.alloc(GlyphInstance, max_glyphs);
        const line_mem = try pool.alloc(LineInstance, max_lines);

        return RenderScene{
            .pool = pool,
            .cmd_buffer = CommandBuffer.initPreallocated(cmd_mem, text_mem),
            .batcher = InstanceBatcher.initPreallocated(rect_mem, glyph_mem, line_mem),
            .scissor = ScissorStack.init(),
        };
    }

    pub inline fn begin(self: *RenderScene) void {
        self.cmd_buffer.clear();
        self.batcher.clear();
        self.scissor.clear();
    }

    pub fn clearSurface(self: *RenderScene, r: u8, g: u8, b: u8) void {
        _ = self.cmd_buffer.push(PackedDrawCommand.initClear(r, g, b));
    }

    pub fn drawRect(self: *RenderScene, x: i16, y: i16, w: u16, h: u16, col: ColorRGBA8, fill: bool) void {
        if (fill) {
            // Queue into instanced batcher for high speed
            _ = self.batcher.pushRect(RectInstance.init(x, y, w, h, col));
        } else {
            _ = self.cmd_buffer.push(PackedDrawCommand.initRect(x, y, w, h, col, false));
        }
    }

    pub fn drawLine(self: *RenderScene, x0: i16, y0: i16, x1: i16, y1: i16, col: ColorRGBA8) void {
        _ = self.batcher.pushLine(LineInstance.init(x0, y0, x1, y1, col));
    }

    pub fn drawCircle(self: *RenderScene, cx: i16, cy: i16, rad: u16, col: ColorRGBA8, fill: bool) void {
        _ = self.cmd_buffer.push(PackedDrawCommand.initCircle(cx, cy, rad, col, fill));
    }

    pub fn drawText(self: *RenderScene, x: i16, y: i16, text: []const u8, scale: u8, col: ColorRGBA8) void {
        _ = self.batcher.pushString(x, y, text, scale, col);
    }

    pub fn setClipRect(self: *RenderScene, x: i32, y: i32, w: i32, h: i32) void {
        const r = ClipRect.init(x, y, w, h);
        _ = self.scissor.push(r);
        _ = self.cmd_buffer.push(PackedDrawCommand{
            .op = .set_clip,
            .x = @truncate(x),
            .y = @truncate(y),
            .w = @truncate(@as(u32, @intCast(@max(0, w)))),
            .h = @truncate(@as(u32, @intCast(@max(0, h)))),
        });
    }

    pub fn resetClipRect(self: *RenderScene) void {
        self.scissor.clear();
        _ = self.cmd_buffer.push(PackedDrawCommand{ .op = .reset_clip });
    }

    pub fn render(self: *RenderScene, buf: *GpuBuffer, w: usize, h: usize) void {
        // Execute draw commands
        self.cmd_buffer.execute(buf, w, h);
        // Execute instanced batches
        self.batcher.flushAll(buf, w, h, self.scissor.current());
    }

    pub fn renderToIndexed(self: *RenderScene, surf: *IndexedSurface) void {
        self.batcher.flushRectsIndexed(surf, self.scissor.current());
    }

    pub inline fn reset(self: *RenderScene) void {
        self.begin();
        self.pool.reset();
    }
};

// Double-Buffered Frame Memory Pool
pub const SceneFramePool = struct {
    pools: [2]SceneMemoryPool,
    active_idx: usize = 0,

    pub fn initAllocated(allocator: std.mem.Allocator, capacity_per_frame: usize) !SceneFramePool {
        return .{
            .pools = [2]SceneMemoryPool{
                try SceneMemoryPool.initAllocated(allocator, capacity_per_frame),
                try SceneMemoryPool.initAllocated(allocator, capacity_per_frame),
            },
            .active_idx = 0,
        };
    }

    pub fn deinit(self: *SceneFramePool) void {
        self.pools[0].deinit();
        self.pools[1].deinit();
    }

    pub fn current(self: *SceneFramePool) *SceneMemoryPool {
        return &self.pools[self.active_idx];
    }

    pub fn swapFrames(self: *SceneFramePool) void {
        self.active_idx ^= 1;
        self.pools[self.active_idx].reset();
    }
};

// Global Scene Scratch Pool (1 MB pre-allocated)
var global_pool_storage: [1024 * 1024]u8 = undefined;
var global_pool = SceneMemoryPool.initPreallocated(&global_pool_storage);
var global_scene: ?RenderScene = null;

pub fn getGlobalScene() *RenderScene {
    if (global_scene == null) {
        global_scene = RenderScene.create(&global_pool, 4096, 4096, 8192, 2048, 65536) catch unreachable;
    }
    return &global_scene.?;
}

test "zero-allocation scene pool and checkpoint" {
    var pool_mem: [2048]u8 = undefined;
    var pool = SceneMemoryPool.initPreallocated(&pool_mem);

    const slice1 = try pool.alloc(u32, 10);
    try std.testing.expectEqual(@as(usize, 10), slice1.len);
    const cp = pool.saveCheckpoint();

    const slice2 = try pool.alloc(u64, 5);
    try std.testing.expectEqual(@as(usize, 5), slice2.len);
    try std.testing.expect(pool.getUsedBytes() > cp);

    pool.restoreCheckpoint(cp);
    try std.testing.expectEqual(cp, pool.getUsedBytes());

    const report = pool.getMemoryReport();
    try std.testing.expectEqual(@as(usize, 2048), report.capacity);
    try std.testing.expect(report.utilization_pct > 0.0);
}

test "render scene lifecycle" {
    var pool_mem: [16384]u8 = undefined;
    var pool = SceneMemoryPool.initPreallocated(&pool_mem);
    var scene = try RenderScene.create(&pool, 32, 32, 32, 32, 256);

    scene.begin();
    scene.clearSurface(10, 20, 30);
    scene.drawRect(5, 5, 20, 20, ColorRGBA8.init(255, 0, 0, 255), true);
    scene.drawText(0, 0, "HI", 1, ColorRGBA8.init(255, 255, 255, 255));
    try std.testing.expectEqual(@as(usize, 2), scene.batcher.getTotalInstances());

    scene.reset();
    try std.testing.expectEqual(@as(usize, 0), scene.batcher.getTotalInstances());
}

