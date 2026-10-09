const std = @import("std");

// ============================================================================
// Zero-Allocation Double & Triple Buffer Management
// Supports both Heap and X11 MIT-SHM shared memory presentation
// ============================================================================

pub const BufferMode = enum {
    single,
    double,
    triple,
};

pub var mode: BufferMode = .triple;
pub var buffer_size_bytes: usize = 0;
pub var buffer_pixel_count: usize = 0;
pub var is_shm_pool: bool = false;

// Buffer storage pointers
var shm_raw_ptr: ?[*]u8 = null;
var heap_buf_front: ?[]u8 = null;
var heap_buf_back: ?[]u8 = null;
var heap_buf_prev: ?[]u8 = null;

// Ring buffer slot indexes: 0, 1, 2
var slot_back: usize = 0;
var slot_front: usize = 1;
var slot_prev: usize = 2;

var initialized: bool = false;

pub fn isInitialized() bool {
    return initialized;
}

pub fn getBufferModeName() []const u8 {
    if (!initialized) return "Uninitialized";
    if (is_shm_pool) return "X11 SHM Zero-Copy Double-Buffer";
    return "Heap Zero-Allocation Triple-Buffer";
}

pub fn getPoolMemoryBytes() usize {
    if (!initialized) return 0;
    if (is_shm_pool) {
        // SHM has 2 slots + 1 heap reference slot for delta tracking
        return buffer_size_bytes * 2 + (if (heap_buf_prev != null) buffer_size_bytes else 0);
    }
    return buffer_size_bytes * 3;
}

pub fn initPool(
    allocator: std.mem.Allocator,
    win_w: usize,
    win_h: usize,
    is_shm: bool,
    shm_base_ptr: ?[*]u8,
) !void {
    deinitPool(allocator);

    buffer_pixel_count = win_w * win_h;
    buffer_size_bytes = buffer_pixel_count * 4;
    is_shm_pool = is_shm;

    if (is_shm and shm_base_ptr != null) {
        shm_raw_ptr = shm_base_ptr;
        // In SHM mode: SHM segment contains 2 slots (offset 0 and offset buffer_size_bytes)
        // Staging/reference buffer for delta frame tracking is kept in heap memory
        heap_buf_prev = try allocator.alloc(u8, buffer_size_bytes);
        @memset(heap_buf_prev.?, 0);
        slot_back = 0;
        slot_front = 1;
        slot_prev = 2;
        mode = .double;
    } else {
        heap_buf_back = try allocator.alloc(u8, buffer_size_bytes);
        heap_buf_front = try allocator.alloc(u8, buffer_size_bytes);
        heap_buf_prev = try allocator.alloc(u8, buffer_size_bytes);
        @memset(heap_buf_back.?, 0);
        @memset(heap_buf_front.?, 0);
        @memset(heap_buf_prev.?, 0);
        slot_back = 0;
        slot_front = 1;
        slot_prev = 2;
        mode = .triple;
    }

    initialized = true;
}

pub fn deinitPool(allocator: std.mem.Allocator) void {
    if (heap_buf_back) |b| {
        allocator.free(b);
        heap_buf_back = null;
    }
    if (heap_buf_front) |b| {
        allocator.free(b);
        heap_buf_front = null;
    }
    if (heap_buf_prev) |b| {
        allocator.free(b);
        heap_buf_prev = null;
    }
    shm_raw_ptr = null;
    initialized = false;
    buffer_size_bytes = 0;
    buffer_pixel_count = 0;
}

pub fn getBackBuffer() []u8 {
    if (!initialized or buffer_size_bytes == 0) return &[_]u8{};
    if (is_shm_pool and shm_raw_ptr != null) {
        const offset = slot_back * buffer_size_bytes;
        return (shm_raw_ptr.? + offset)[0..buffer_size_bytes];
    }
    return switch (slot_back) {
        0 => heap_buf_back.?,
        1 => heap_buf_front.?,
        else => heap_buf_prev.?,
    };
}

pub fn getFrontBuffer() []u8 {
    if (!initialized or buffer_size_bytes == 0) return &[_]u8{};
    if (is_shm_pool and shm_raw_ptr != null) {
        const offset = slot_front * buffer_size_bytes;
        return (shm_raw_ptr.? + offset)[0..buffer_size_bytes];
    }
    return switch (slot_front) {
        0 => heap_buf_back.?,
        1 => heap_buf_front.?,
        else => heap_buf_prev.?,
    };
}

pub fn getPrevBuffer() []u8 {
    if (!initialized or buffer_size_bytes == 0) return &[_]u8{};
    if (is_shm_pool) {
        return heap_buf_prev orelse &[_]u8{};
    }
    return switch (slot_prev) {
        0 => heap_buf_back.?,
        1 => heap_buf_front.?,
        else => heap_buf_prev.?,
    };
}

pub fn getBackBuffer32() []u32 {
    const raw = getBackBuffer();
    if (raw.len == 0) return &[_]u32{};
    const ptr: [*]u32 = @ptrCast(@alignCast(raw.ptr));
    return ptr[0..buffer_pixel_count];
}

pub fn getFrontBuffer32() []u32 {
    const raw = getFrontBuffer();
    if (raw.len == 0) return &[_]u32{};
    const ptr: [*]u32 = @ptrCast(@alignCast(raw.ptr));
    return ptr[0..buffer_pixel_count];
}

pub fn getPrevBuffer32() []u32 {
    const raw = getPrevBuffer();
    if (raw.len == 0) return &[_]u32{};
    const ptr: [*]u32 = @ptrCast(@alignCast(raw.ptr));
    return ptr[0..buffer_pixel_count];
}

pub fn getScanoutShmOffset() u32 {
    if (!is_shm_pool) return 0;
    return @intCast(slot_back * buffer_size_bytes);
}

pub fn swapBuffers() void {
    if (!initialized) return;

    if (is_shm_pool) {
        // Copy back buffer into prev buffer for delta frame tracking
        if (shm_raw_ptr) |raw| {
            const back_offset = slot_back * buffer_size_bytes;
            const back_slice = (raw + back_offset)[0..buffer_size_bytes];
            if (heap_buf_prev) |prev| {
                @memcpy(prev[0..buffer_size_bytes], back_slice);
            }
        }
        // Swap SHM front and back slots (0 <-> 1)
        const temp = slot_back;
        slot_back = slot_front;
        slot_front = temp;
    } else {
        // Rotate triple buffers: prev becomes back, back becomes front, front becomes prev
        const old_prev = slot_prev;
        slot_prev = slot_front;
        slot_front = slot_back;
        slot_back = old_prev;
    }
}

pub fn copyBackToPrev() void {
    if (!initialized or buffer_size_bytes == 0) return;
    const back = getBackBuffer();
    const prev = getPrevBuffer();
    if (back.len >= buffer_size_bytes and prev.len >= buffer_size_bytes) {
        @memcpy(prev[0..buffer_size_bytes], back[0..buffer_size_bytes]);
    }
}

test "buffer pool initialization and swap" {
    const allocator = std.testing.allocator;
    try initPool(allocator, 10, 10, false, null);
    defer deinitPool(allocator);

    try std.testing.expect(isInitialized());
    try std.testing.expectEqual(@as(usize, 400), buffer_size_bytes);
    try std.testing.expectEqual(@as(usize, 100), buffer_pixel_count);
    try std.testing.expectEqual(@as(usize, 1200), getPoolMemoryBytes());

    const back32 = getBackBuffer32();
    @memset(back32, 0xAABBCCDD);
    var prev32 = getPrevBuffer32();
    @memset(prev32, 0x11223344);

    copyBackToPrev();
    prev32 = getPrevBuffer32();
    try std.testing.expectEqual(@as(u32, 0xAABBCCDD), prev32[0]);

    swapBuffers();
    const new_front = getFrontBuffer32();
    try std.testing.expectEqual(@as(u32, 0xAABBCCDD), new_front[0]);
}

test "shm double buffer pool" {
    const allocator = std.testing.allocator;
    var fake_shm: [800]u8 = undefined;
    @memset(&fake_shm, 0);

    try initPool(allocator, 10, 10, true, &fake_shm);
    defer deinitPool(allocator);

    try std.testing.expect(isInitialized());
    try std.testing.expectEqual(@as(u32, 0), getScanoutShmOffset());
    try std.testing.expectEqual(@as(usize, 1200), getPoolMemoryBytes());

    const back = getBackBuffer();
    @memset(back, 0x55);
    try std.testing.expectEqual(@as(u8, 0x55), fake_shm[0]);

    swapBuffers();
    try std.testing.expectEqual(@as(u32, 400), getScanoutShmOffset());
}
