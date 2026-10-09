const std = @import("std");

// ============================================================================
// Binary Buddy Sub-Allocator for Medium/Large VRAM Blocks (64KB - 64MB)
// Power-of-Two Splitting and Recursive Coalescing on Deallocation
// ============================================================================

pub const MIN_BUDDY_ORDER: usize = 16; // 64 KB = 2^16
pub const MAX_BUDDY_ORDER: usize = 26; // 64 MB = 2^26
pub const NUM_ORDERS: usize = MAX_BUDDY_ORDER - MIN_BUDDY_ORDER + 1; // 11 orders

inline fn orderToBytes(order: usize) usize {
    return @as(usize, 1) << @as(u6, @intCast(order));
}

pub const BuddyBlock = struct {
    offset: usize,
    order: usize,
    is_free: bool = true,
};

pub const SpinLock = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinLock) void {
        while (self.state.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.state.store(false, .release);
    }
};

pub const BuddyAllocator = struct {
    total_bytes: usize,
    free_lists: [NUM_ORDERS]std.ArrayList(usize),
    block_orders: std.AutoHashMap(usize, usize),
    lock: SpinLock = .{},
    is_init: bool = false,

    pub fn init(self: *BuddyAllocator, total_capacity: usize) !void {
        if (self.is_init) return;
        self.lock.lock();
        defer self.lock.unlock();
        if (self.is_init) return;

        self.total_bytes = total_capacity;
        for (0..NUM_ORDERS) |i| {
            self.free_lists[i] = .empty;
        }
        self.block_orders = std.AutoHashMap(usize, usize).init(std.heap.c_allocator);

        // Seed with root block(s) of MAX_BUDDY_ORDER
        const max_block_size = orderToBytes(MAX_BUDDY_ORDER);
        var offset: usize = 0;
        while (offset + max_block_size <= total_capacity) : (offset += max_block_size) {
            const order_idx = MAX_BUDDY_ORDER - MIN_BUDDY_ORDER;
            try self.free_lists[order_idx].append(std.heap.c_allocator, offset);
            try self.block_orders.put(offset, MAX_BUDDY_ORDER);
        }
        self.is_init = true;
    }

    pub fn alloc(self: *BuddyAllocator, req_bytes: usize) ?struct { offset: usize, allocated_bytes: usize } {
        self.lock.lock();
        defer self.lock.unlock();

        var target_order = MIN_BUDDY_ORDER;
        while (orderToBytes(target_order) < req_bytes and target_order < MAX_BUDDY_ORDER) {
            target_order += 1;
        }

        const start_idx = target_order - MIN_BUDDY_ORDER;
        var found_idx: ?usize = null;
        for (start_idx..NUM_ORDERS) |i| {
            if (self.free_lists[i].items.len > 0) {
                found_idx = i;
                break;
            }
        }

        const current_idx = found_idx orelse return null;
        const offset = self.free_lists[current_idx].pop() orelse return null;
        var current_order = current_idx + MIN_BUDDY_ORDER;

        // Split larger block down to target order
        while (current_order > target_order) {
            current_order -= 1;
            const buddy_size = orderToBytes(current_order);
            const buddy_offset = offset + buddy_size;
            const list_idx = current_order - MIN_BUDDY_ORDER;
            self.free_lists[list_idx].append(std.heap.c_allocator, buddy_offset) catch {};
            self.block_orders.put(buddy_offset, current_order) catch {};
        }

        self.block_orders.put(offset, target_order) catch {};
        return .{ .offset = offset, .allocated_bytes = orderToBytes(target_order) };
    }

    pub fn free(self: *BuddyAllocator, offset: usize) usize {
        self.lock.lock();
        defer self.lock.unlock();

        var current_order = self.block_orders.get(offset) orelse MIN_BUDDY_ORDER;
        var current_offset = offset;
        var coalesced_count: usize = 0;

        while (current_order < MAX_BUDDY_ORDER) {
            const block_size = orderToBytes(current_order);
            const buddy_offset = current_offset ^ block_size;
            const list_idx = current_order - MIN_BUDDY_ORDER;

            // Check if buddy is in the free list
            var buddy_found = false;
            for (self.free_lists[list_idx].items, 0..) |f_off, i| {
                if (f_off == buddy_offset) {
                    _ = self.free_lists[list_idx].swapRemove(i);
                    buddy_found = true;
                    break;
                }
            }

            if (!buddy_found) break;

            // Coalesce buddy with current block
            _ = self.block_orders.remove(buddy_offset);
            current_offset = @min(current_offset, buddy_offset);
            current_order += 1;
            coalesced_count += 1;
        }

        const final_idx = current_order - MIN_BUDDY_ORDER;
        self.free_lists[final_idx].append(std.heap.c_allocator, current_offset) catch {};
        self.block_orders.put(current_offset, current_order) catch {};
        return coalesced_count;
    }

    pub fn getMaxContiguousFree(self: *BuddyAllocator) usize {
        self.lock.lock();
        defer self.lock.unlock();

        const max_bytes: usize = 0;
        var i = NUM_ORDERS;
        while (i > 0) {
            i -= 1;
            if (self.free_lists[i].items.len > 0) {
                return orderToBytes(i + MIN_BUDDY_ORDER);
            }
        }
        return max_bytes;
    }

    pub fn getTotalFree(self: *BuddyAllocator) usize {
        self.lock.lock();
        defer self.lock.unlock();

        var total: usize = 0;
        for (0..NUM_ORDERS) |i| {
            const blk_size = orderToBytes(i + MIN_BUDDY_ORDER);
            total += self.free_lists[i].items.len * blk_size;
        }
        return total;
    }
};
