const std = @import("std");

// ============================================================================
// Sparse GPU Memory Lossless RLE & Zero-Dense Compression Engine
// ============================================================================

pub const RlePacket = extern struct {
    count: u16,
    value: f32,
};

pub fn compressFrame(slice: []const f32, store: *std.ArrayList(u8)) ?struct { offset: u32, len: u16 } {
    var packets = std.ArrayList(RlePacket).empty;
    defer packets.deinit(std.heap.c_allocator);

    var i: usize = 0;
    while (i < slice.len) {
        const val = slice[i];
        var count: u16 = 1;
        while (i + count < slice.len and slice[i + count] == val and count < 65535) {
            count += 1;
        }
        packets.append(std.heap.c_allocator, .{ .count = count, .value = val }) catch return null;
        i += count;
    }

    const byte_len = packets.items.len * @sizeOf(RlePacket);
    // Only compress if saving at least 50% of the 4KB page
    if (byte_len >= (slice.len * @sizeOf(f32)) / 2) return null;

    const offset: u32 = @intCast(store.items.len);
    const bytes_ptr: [*]const u8 = @ptrCast(packets.items.ptr);
    store.appendSlice(std.heap.c_allocator, bytes_ptr[0..byte_len]) catch return null;
    return .{ .offset = offset, .len = @intCast(byte_len) };
}

pub fn decompressToSlice(store: []const u8, offset: u32, byte_len: u16, out: []f32) void {
    if (offset + byte_len > store.len) {
        @memset(out, 0.0);
        return;
    }

    const raw = store[offset .. offset + byte_len];
    const num_packets = byte_len / @sizeOf(RlePacket);
    const packets: [*]const RlePacket = @ptrCast(@alignCast(raw.ptr));

    var out_idx: usize = 0;
    for (0..num_packets) |p_i| {
        const pkt = packets[p_i];
        const end = @min(out.len, out_idx + pkt.count);
        @memset(out[out_idx..end], pkt.value);
        out_idx = end;
        if (out_idx >= out.len) break;
    }
    if (out_idx < out.len) @memset(out[out_idx..], 0.0);
}
