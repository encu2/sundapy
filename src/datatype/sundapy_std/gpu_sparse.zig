const std = @import("std");

// ============================================================================
// Bit-Level Compressed Sparse Row (BCSR) and Column (BCSC) Engine
// 1-bit presence bitmask eliminates 32-bit column index arrays for ultra VRAM compaction.
// Features direct hardware-accelerated SpMV via @ctz / bit-scanning.
// ============================================================================

pub const BitSparseMatrix = struct {
    allocator: std.mem.Allocator,
    rows: usize,
    cols: usize,
    words_per_row: usize,
    nnz: usize,

    row_offsets: []usize, // Length: rows + 1
    bitmasks: []u64,      // Length: rows * words_per_row
    values: []f32,        // Length: nnz

    pub fn deinit(self: *BitSparseMatrix) void {
        self.allocator.free(self.row_offsets);
        self.allocator.free(self.bitmasks);
        self.allocator.free(self.values);
        self.allocator.destroy(self);
    }

    pub fn compressionRatio(self: *const BitSparseMatrix) f32 {
        const dense_bytes = @as(f32, @floatFromInt(self.rows * self.cols * @sizeOf(f32)));
        const compressed_bytes = @as(f32, @floatFromInt(
            (self.rows + 1) * @sizeOf(usize) +
            self.bitmasks.len * @sizeOf(u64) +
            self.values.len * @sizeOf(f32),
        ));
        if (compressed_bytes <= 0.0) return 1.0;
        return dense_bytes / compressed_bytes;
    }

    pub fn sparsity(self: *const BitSparseMatrix) f32 {
        const total = @as(f32, @floatFromInt(self.rows * self.cols));
        if (total <= 0.0) return 0.0;
        const non_zeros = @as(f32, @floatFromInt(self.nnz));
        return (1.0 - (non_zeros / total)) * 100.0;
    }

    pub fn totalBytes(self: *const BitSparseMatrix) usize {
        return (self.rows + 1) * @sizeOf(usize) +
            self.bitmasks.len * @sizeOf(u64) +
            self.values.len * @sizeOf(f32);
    }
};

// --- Compress Dense Matrix to Bit-Level CSR ---

pub fn compress_dense_to_bcsr(
    allocator: std.mem.Allocator,
    dense: []const f32,
    rows: usize,
    cols: usize,
    threshold: f32,
) !*BitSparseMatrix {
    if (dense.len < rows * cols) return error.BufferTooSmall;
    const words_per_row = (cols + 63) / 64;

    // First pass: count non-zeros and populate bitmasks
    const bitmasks = try allocator.alloc(u64, rows * words_per_row);
    errdefer allocator.free(bitmasks);
    @memset(bitmasks, 0);

    const row_offsets = try allocator.alloc(usize, rows + 1);
    errdefer allocator.free(row_offsets);

    var total_nnz: usize = 0;
    for (0..rows) |r| {
        row_offsets[r] = total_nnz;
        const row_start = r * cols;
        for (0..cols) |c| {
            const val = dense[row_start + c];
            if (@abs(val) > threshold) {
                const w_idx = c / 64;
                const b_idx: u6 = @intCast(c % 64);
                bitmasks[r * words_per_row + w_idx] |= (@as(u64, 1) << b_idx);
                total_nnz += 1;
            }
        }
    }
    row_offsets[rows] = total_nnz;

    // Second pass: tightly pack non-zero values
    const values = try allocator.alloc(f32, total_nnz);
    errdefer allocator.free(values);

    var v_idx: usize = 0;
    for (0..rows) |r| {
        const row_start = r * cols;
        for (0..words_per_row) |w| {
            var mask = bitmasks[r * words_per_row + w];
            const col_base = w * 64;
            while (mask != 0) {
                const bit_pos = @ctz(mask);
                const c = col_base + bit_pos;
                if (c < cols and v_idx < total_nnz) {
                    values[v_idx] = dense[row_start + c];
                    v_idx += 1;
                }
                mask &= mask - 1; // Clear lowest set bit
            }
        }
    }

    const self = try allocator.create(BitSparseMatrix);
    self.* = BitSparseMatrix{
        .allocator = allocator,
        .rows = rows,
        .cols = cols,
        .words_per_row = words_per_row,
        .nnz = total_nnz,
        .row_offsets = row_offsets,
        .bitmasks = bitmasks,
        .values = values,
    };
    return self;
}

// --- Decompress Bit-Level CSR back to Dense Slice ---

pub fn decompress_bcsr_to_dense(
    bcsr: *const BitSparseMatrix,
    out_dense: []f32,
) !void {
    if (out_dense.len < bcsr.rows * bcsr.cols) return error.BufferTooSmall;
    @memset(out_dense[0 .. bcsr.rows * bcsr.cols], 0.0);

    for (0..bcsr.rows) |r| {
        const row_start = r * bcsr.cols;
        var val_idx = bcsr.row_offsets[r];
        const end_idx = bcsr.row_offsets[r + 1];

        for (0..bcsr.words_per_row) |w| {
            var mask = bcsr.bitmasks[r * bcsr.words_per_row + w];
            const col_base = w * 64;
            while (mask != 0) {
                const bit_pos = @ctz(mask);
                const c = col_base + bit_pos;
                if (c < bcsr.cols and val_idx < end_idx) {
                    out_dense[row_start + c] = bcsr.values[val_idx];
                    val_idx += 1;
                }
                mask &= mask - 1;
            }
        }
    }
}

// --- Direct Hardware Bit-Scan Sparse Matrix-Vector Multiplication (SpMV) ---
// Computes y = Matrix * x directly from compressed bit-level sparse representation.
// Zero dense decompression, 1-cycle bit traversal using @ctz.

pub fn sparse_spmv(
    bcsr: *const BitSparseMatrix,
    x: []const f32,
    y: []f32,
) !void {
    if (x.len < bcsr.cols or y.len < bcsr.rows) return error.DimensionMismatch;

    for (0..bcsr.rows) |r| {
        var sum: f32 = 0.0;
        var val_idx = bcsr.row_offsets[r];
        const end_val = bcsr.row_offsets[r + 1];

        for (0..bcsr.words_per_row) |w| {
            var mask = bcsr.bitmasks[r * bcsr.words_per_row + w];
            const col_base = w * 64;
            while (mask != 0) {
                const bit_pos = @ctz(mask);
                const c = col_base + bit_pos;
                if (c < bcsr.cols and val_idx < end_val) {
                    sum += bcsr.values[val_idx] * x[c];
                    val_idx += 1;
                }
                mask &= mask - 1;
            }
        }
        y[r] = sum;
    }
}

// --- Bit-Level Compressed Sparse Column (BCSC) ---
// Column-major bit-level sparse representation for dual column-sliced workloads.

pub const BitSparseCsc = struct {
    allocator: std.mem.Allocator,
    rows: usize,
    cols: usize,
    words_per_col: usize,
    nnz: usize,
    col_offsets: []usize, // Length: cols + 1
    bitmasks: []u64,      // Length: cols * words_per_col
    values: []f32,        // Length: nnz

    pub fn deinit(self: *BitSparseCsc) void {
        self.allocator.free(self.col_offsets);
        self.allocator.free(self.bitmasks);
        self.allocator.free(self.values);
        self.allocator.destroy(self);
    }
};

pub fn compress_dense_to_bcsc(
    allocator: std.mem.Allocator,
    dense: []const f32,
    rows: usize,
    cols: usize,
    threshold: f32,
) !*BitSparseCsc {
    if (dense.len < rows * cols) return error.BufferTooSmall;
    const words_per_col = (rows + 63) / 64;

    const bitmasks = try allocator.alloc(u64, cols * words_per_col);
    errdefer allocator.free(bitmasks);
    @memset(bitmasks, 0);

    const col_offsets = try allocator.alloc(usize, cols + 1);
    errdefer allocator.free(col_offsets);

    var total_nnz: usize = 0;
    for (0..cols) |c| {
        col_offsets[c] = total_nnz;
        for (0..rows) |r| {
            const val = dense[r * cols + c];
            if (@abs(val) > threshold) {
                const w_idx = r / 64;
                const b_idx: u6 = @intCast(r % 64);
                bitmasks[c * words_per_col + w_idx] |= (@as(u64, 1) << b_idx);
                total_nnz += 1;
            }
        }
    }
    col_offsets[cols] = total_nnz;

    const values = try allocator.alloc(f32, total_nnz);
    errdefer allocator.free(values);

    var v_idx: usize = 0;
    for (0..cols) |c| {
        for (0..words_per_col) |w| {
            var mask = bitmasks[c * words_per_col + w];
            const row_base = w * 64;
            while (mask != 0) {
                const bit_pos = @ctz(mask);
                const r = row_base + bit_pos;
                if (r < rows and v_idx < total_nnz) {
                    values[v_idx] = dense[r * cols + c];
                    v_idx += 1;
                }
                mask &= mask - 1;
            }
        }
    }

    const self = try allocator.create(BitSparseCsc);
    self.* = BitSparseCsc{
        .allocator = allocator,
        .rows = rows,
        .cols = cols,
        .words_per_col = words_per_col,
        .nnz = total_nnz,
        .col_offsets = col_offsets,
        .bitmasks = bitmasks,
        .values = values,
    };
    return self;
}

const gpu_types = @import("datatype/gpu_types.zig");

pub fn bufferSpmvHook(self: *gpu_types.GpuBuffer, x_buf: *gpu_types.GpuBuffer) anyerror!*gpu_types.GpuBuffer {
    const rows = if (self.ndim >= 2) self.shape[0] else self.size;
    const cols = if (self.ndim >= 2) self.shape[1] else 1;
    const y_buf = try gpu_types.GpuBuffer.init(self.allocator, rows);
    const bcsr = try compress_dense_to_bcsr(self.allocator, self.data, rows, cols, 1e-6);
    defer bcsr.deinit();
    try sparse_spmv(bcsr, x_buf.data[0..cols], y_buf.data[0..rows]);
    return y_buf;
}

