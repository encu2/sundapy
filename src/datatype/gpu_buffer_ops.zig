const std = @import("std");
const dynamic = @import("dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const quant = @import("numeric/quant.zig");

pub fn parseIndex(self: *const GpuBuffer, index: Dynamic) !usize {
    if (index.value == .i64_type) {
        const i = index.value.i64_type;
        if (i < 0 or i >= self.size) return error.IndexError;
        return @intCast(i);
    } else if (index.value == .tuple_type or index.value == .list_type) {
        const items = if (index.value == .tuple_type) index.value.tuple_type.items else index.value.list_type.items.items;
        if (self.ndim > 0 and items.len == self.ndim) {
            var offset: usize = 0;
            for (items, 0..) |item, dim_i| {
                if (item.value != .i64_type) return error.TypeError;
                const coord = item.value.i64_type;
                if (coord < 0 or coord >= self.shape[dim_i]) return error.IndexError;
                offset += @as(usize, @intCast(coord)) * self.strides[dim_i];
            }
            if (offset >= self.size) return error.IndexError;
            return offset;
        }
        return error.IndexError;
    }
    return error.TypeError;
}

pub const readCompressedItem = @import("gpu_compress_read.zig").readCompressedItem;

pub fn isBufferMethod(attr: []const u8) bool {
    const methods = [_][]const u8{
        "compress", "decompress", "compact", "uncompact", "spmv",
        "stats", "get_stats", "to_raw_handle", "fill", "to_list",
        "to_device", "to_host", "copy_from_list", "copy_to", "copy_from",
        "commit_page", "decommit_page", "is_page_committed", "compress_idle_pages",
        "sparse_stats", "free", "add_kernel", "add_edge", "add_dependency",
        "instantiate", "launch", "benchmark", "destroy",
    };
    for (methods) |m| {
        if (std.mem.eql(u8, attr, m)) return true;
    }
    return false;
}


pub fn getItem(self: *GpuBuffer, index: Dynamic) !Dynamic {
    if (self.is_sparse_vm and self.sparse_vm_ptr != null) {
        const idx = try parseIndex(self, index);
        if (gpu_types.buffer_sparse_get_fn) |gfn| {
            const val = try gfn(self.sparse_vm_ptr.?, idx);
            return Dynamic.initFloat(@floatCast(val));
        }
        return Dynamic.initFloat(0.0);
    }
    const idx = try parseIndex(self, index);
    if (self.compression_info) |ci| {
        if (ci.is_compressed and ci.raw_payload != null) {
            return readCompressedItem(ci, idx);
        }
    }
    return switch (self.dtype) {
        .i32 => Dynamic.initInt(@intCast((@as([*]const i32, @ptrCast(@alignCast(self.data.ptr))))[idx])),
        .u8 => Dynamic.initInt(@intCast((@as([*]const u8, @ptrCast(self.data.ptr)))[idx])),
        .i64 => Dynamic.initInt((@as([*]const i64, @ptrCast(@alignCast(self.data.ptr))))[idx]),
        .f16 => Dynamic.initFloat(@floatCast(quant.f16_to_f32((@as([*]const u16, @ptrCast(@alignCast(self.data.ptr))))[idx]))),
        .bf16 => Dynamic.initFloat(@floatCast(quant.bf16_to_f32((@as([*]const u16, @ptrCast(@alignCast(self.data.ptr))))[idx]))),
        .int8 => Dynamic.initInt(@intCast((@as([*]const i8, @ptrCast(self.data.ptr)))[idx])),
        .fp8_e4m3 => Dynamic.initFloat(@floatCast(quant.fp8_e4m3_to_f32((@as([*]const u8, @ptrCast(self.data.ptr)))[idx]))),
        .fp8_e5m2 => Dynamic.initFloat(@floatCast(quant.fp8_e5m2_to_f32((@as([*]const u8, @ptrCast(self.data.ptr)))[idx]))),
        .fp4_e2m1 => blk: {
            const s: [*]const u8 = @ptrCast(self.data.ptr);
            const b = s[idx / 2];
            const nib: u4 = if ((idx % 2) == 0) @truncate(b >> 4) else @truncate(b & 0x0F);
            break :blk Dynamic.initFloat(@floatCast(quant.fp4_e2m1_to_f32(nib)));
        },
        else => Dynamic.initFloat(@floatCast(self.data[idx])),
    };
}

pub fn setItem(self: *GpuBuffer, index: Dynamic, val: Dynamic) !void {
    if (self.is_sparse_vm and self.sparse_vm_ptr != null) {
        const idx = try parseIndex(self, index);
        const float_val: f32 = switch (val.value) {
            .float_type => |f| @floatCast(f),
            .i64_type => |i| @floatFromInt(i),
            .i32_type => |i| @floatFromInt(i),
            .u32_type => |u| @floatFromInt(u),
            .u64_type => |u| @floatFromInt(u),
            else => 0.0,
        };
        if (gpu_types.buffer_sparse_set_fn) |sfn| {
            try sfn(self.sparse_vm_ptr.?, idx, float_val);
        }
        return;
    }
    const idx = try parseIndex(self, index);
    if (self.compression_info) |ci| {
        if (ci.is_compressed) {
            if (gpu_types.buffer_decompress_hook) |dhook| {
                try dhook(self);
            }
        }
    }
    const float_val: f32 = switch (val.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        .i32_type => |i| @floatFromInt(i),
        .u32_type => |u| @floatFromInt(u),
        .u64_type => |u| @floatFromInt(u),
        else => 0.0,
    };

    switch (self.dtype) {
        .i32 => {
            const s: [*]i32 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = switch (val.value) { .i64_type => |v| @intCast(v), .float_type => |v| @intFromFloat(v), else => 0 };
        },
        .u8 => {
            const s: [*]u8 = @ptrCast(self.data.ptr);
            s[idx] = switch (val.value) { .i64_type => |v| @intCast(v & 0xFF), .float_type => |v| @intFromFloat(@min(255.0, @max(0.0, v))), else => 0 };
        },
        .i64 => {
            const s: [*]i64 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = switch (val.value) { .i64_type => |v| v, .float_type => |v| @intFromFloat(v), else => 0 };
        },
        .f16 => {
            const s: [*]u16 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = quant.f32_to_f16(float_val);
        },
        .bf16 => {
            const s: [*]u16 = @ptrCast(@alignCast(self.data.ptr));
            s[idx] = quant.f32_to_bf16(float_val);
        },
        .int8 => {
            const s: [*]i8 = @ptrCast(self.data.ptr);
            s[idx] = @intCast(std.math.clamp(@as(i64, @intFromFloat(float_val)), -128, 127));
        },
        .fp8_e4m3 => {
            const s: [*]u8 = @ptrCast(self.data.ptr);
            s[idx] = quant.f32_to_fp8_e4m3(float_val);
        },
        .fp8_e5m2 => {
            const s: [*]u8 = @ptrCast(self.data.ptr);
            s[idx] = quant.f32_to_fp8_e5m2(float_val);
        },
        .fp4_e2m1 => {
            const s: [*]u8 = @ptrCast(self.data.ptr);
            const nib = quant.f32_to_fp4_e2m1(float_val);
            const byte_idx = idx / 2;
            if ((idx % 2) == 0) {
                s[byte_idx] = (s[byte_idx] & 0x0F) | (@as(u8, nib) << 4);
            } else {
                s[byte_idx] = (s[byte_idx] & 0xF0) | (@as(u8, nib) & 0x0F);
            }
        },
        else => {
            self.data[idx] = float_val;
            if (gpu_types.buffer_item_set_fn) |fn_ptr| fn_ptr(self, idx, float_val);
        },
    }
}

pub fn copyFromList(self: *GpuBuffer, list_dyn: Dynamic) !void {
    if (list_dyn.value != .list_type) return error.TypeError;
    const items = list_dyn.value.list_type.items.items;
    const count = @min(self.size, items.len);
    for (0..count) |i| {
        try self.setItem(Dynamic.initInt(@intCast(i)), items[i]);
    }
    self.toDevice();
}

fn parsePageIdx(args: []const Dynamic) !usize {
    if (args.len >= 2 and args[0].value == .gpu_buffer_type and args[1].value == .i64_type)
        return @intCast(@max(0, args[1].value.i64_type));
    if (args.len > 0 and args[0].value == .i64_type)
        return @intCast(@max(0, args[0].value.i64_type));
    return error.TypeError;
}

pub fn callMethod(self: *GpuBuffer, alloc_mem: std.mem.Allocator, args: []const Dynamic) anyerror!Dynamic {
    if (self.is_graph and self.graph_ptr != null) {
        if (gpu_types.buffer_graph_call_fn) |gcfn| {
            return gcfn(self.graph_ptr.?, self.last_method, alloc_mem, args);
        }
    }
    if (std.mem.eql(u8, self.last_method, "fill")) {
        var val: f32 = 0.0;
        const arg = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else Dynamic.initNone();
        if (arg.value == .float_type) val = @floatCast(arg.value.float_type) else if (arg.value == .i64_type) val = @floatFromInt(arg.value.i64_type);
        @memset(self.data, val);
        self.toDevice();
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "to_raw_handle")) {
        var dict = Dynamic.initDict(std.heap.c_allocator);
        try dict.value.dict_type.put(Dynamic.initStr("dev_ptr"), Dynamic.initInt(@intCast(self.dev_ptr)));
        try dict.value.dict_type.put(Dynamic.initStr("byte_size"), Dynamic.initInt(@intCast(self.size * self.dtype.sizeOf())));
        try dict.value.dict_type.put(Dynamic.initStr("stride"), Dynamic.initInt(@intCast(self.dtype.sizeOf())));
        try dict.value.dict_type.put(Dynamic.initStr("is_managed"), Dynamic.initBool(self.is_managed));
        try dict.value.dict_type.put(Dynamic.initStr("is_device"), Dynamic.initBool(self.is_device_allocated));
        try dict.value.dict_type.put(Dynamic.initStr("is_sparse"), Dynamic.initBool(self.is_sparse_vm));
        try dict.value.dict_type.put(Dynamic.initStr("is_suballocated"), Dynamic.initBool(self.is_suballocated));
        return dict;
    } else if (std.mem.eql(u8, self.last_method, "to_list")) {
        return self.toList(alloc_mem);
    } else if (std.mem.eql(u8, self.last_method, "to_device")) {
        self.toDevice();
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "to_host")) {
        self.toHost();
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "copy_from_list")) {
        const list_arg = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else Dynamic.initNone();
        try self.copyFromList(list_arg);
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "copy_to")) {
        const dst_arg = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else return error.TypeError;
        if (dst_arg.value != .gpu_buffer_type) return error.TypeError;
        const dst_buf: *GpuBuffer = @ptrCast(@alignCast(dst_arg.value.gpu_buffer_type));
        if (gpu_types.buffer_copy_fn) |cfn| {
            _ = cfn(dst_buf, self);
            return Dynamic.initNone();
        }
        return error.CopyFailed;
    } else if (std.mem.eql(u8, self.last_method, "copy_from")) {
        const src_arg = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else return error.TypeError;
        if (src_arg.value != .gpu_buffer_type) return error.TypeError;
        const src_buf: *GpuBuffer = @ptrCast(@alignCast(src_arg.value.gpu_buffer_type));
        if (gpu_types.buffer_copy_fn) |cfn| {
            _ = cfn(self, src_buf);
            return Dynamic.initNone();
        }
        return error.CopyFailed;
    } else if (std.mem.eql(u8, self.last_method, "compress")) {
        var codec: []const u8 = "fpc";
        if (args.len >= 2 and args[0].value == .gpu_buffer_type and args[1].value == .str_type) {
            codec = args[1].value.str_type;
        } else if (args.len > 0 and args[0].value == .str_type) {
            codec = args[0].value.str_type;
        }
        if (gpu_types.buffer_compress_hook) |chook| {
            try chook(self, codec);
            return self.asDynamic();
        }
        return error.CompressorNotLoaded;
    } else if (std.mem.eql(u8, self.last_method, "decompress")) {
        if (gpu_types.buffer_decompress_hook) |dhook| {
            try dhook(self);
            return self.asDynamic();
        }
        if (gpu_types.buffer_decompress_fn) |dfn| {
            const dec = try dfn(self);
            return dec.asDynamic();
        }
        return error.DecompressorNotLoaded;
    } else if (std.mem.eql(u8, self.last_method, "compact")) {
        if (gpu_types.buffer_compress_hook) |chook| {
            try chook(self, "compact");
            return self.asDynamic();
        }
        return error.CompressorNotLoaded;
    } else if (std.mem.eql(u8, self.last_method, "uncompact")) {
        if (gpu_types.buffer_decompress_hook) |dhook| {
            try dhook(self);
            return self.asDynamic();
        }
        return error.DecompressorNotLoaded;
    } else if (std.mem.eql(u8, self.last_method, "spmv")) {
        const x_dyn = if (args.len >= 2 and args[0].value == .gpu_buffer_type) args[1] else if (args.len > 0) args[0] else return error.TypeError;
        if (x_dyn.value != .gpu_buffer_type) return error.TypeError;
        const x_buf: *GpuBuffer = @ptrCast(@alignCast(x_dyn.value.gpu_buffer_type));
        if (gpu_types.buffer_spmv_fn) |spmv_fn| {
            const y_buf = try spmv_fn(self, x_buf);
            return y_buf.asDynamic();
        }
        return error.SparseNotLoaded;
    } else if (std.mem.eql(u8, self.last_method, "commit_page")) {
        if (!self.is_sparse_vm or self.sparse_vm_ptr == null) return error.NotSparseBuffer;
        const page_idx = try parsePageIdx(args);
        if (gpu_types.buffer_sparse_commit_fn) |cfn| try cfn(self.sparse_vm_ptr.?, page_idx);
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "decommit_page")) {
        if (!self.is_sparse_vm or self.sparse_vm_ptr == null) return error.NotSparseBuffer;
        const page_idx = try parsePageIdx(args);
        if (gpu_types.buffer_sparse_decommit_fn) |dfn| dfn(self.sparse_vm_ptr.?, page_idx);
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "is_page_committed")) {
        if (!self.is_sparse_vm or self.sparse_vm_ptr == null) return error.NotSparseBuffer;
        const page_idx = try parsePageIdx(args);
        if (gpu_types.buffer_sparse_is_committed_fn) |icfn| return Dynamic.initBool(icfn(self.sparse_vm_ptr.?, page_idx));
        return Dynamic.initBool(false);
    } else if (std.mem.eql(u8, self.last_method, "compress_idle_pages")) {
        if (!self.is_sparse_vm or self.sparse_vm_ptr == null) return error.NotSparseBuffer;
        if (gpu_types.buffer_sparse_compress_idle_fn) |cifn| {
            const reclaimed = try cifn(self.sparse_vm_ptr.?);
            return Dynamic.initInt(@intCast(reclaimed));
        }
        return Dynamic.initInt(0);
    } else if (std.mem.eql(u8, self.last_method, "sparse_stats")) {
        if (!self.is_sparse_vm or self.sparse_vm_ptr == null) return error.NotSparseBuffer;
        if (gpu_types.buffer_sparse_stats_fn) |sfn| {
            return sfn(self.sparse_vm_ptr.?);
        }
        return Dynamic.initNone();
    } else if (std.mem.eql(u8, self.last_method, "get_stats") or std.mem.eql(u8, self.last_method, "stats")) {
        return buildStatsDict(self);
    } else if (std.mem.eql(u8, self.last_method, "free")) {
        self.deinit();
        return Dynamic.initNone();
    }
    return Dynamic.initNone();
}
pub fn buildStatsDict(buf: *GpuBuffer) anyerror!Dynamic {
    if (buf.is_sparse_vm and buf.sparse_vm_ptr != null) {
        if (gpu_types.buffer_sparse_stats_fn) |sstats| {
            return sstats(buf.sparse_vm_ptr.?);
        }
    }
    var dict = Dynamic.initDict(std.heap.c_allocator);
    const ci = buf.compression_info;
    const is_comp = if (ci) |c| c.is_compressed else false;
    const scheme = if (ci) |c| c.scheme else "none";
    const comp_b = if (ci) |c| c.compressed_bytes else buf.size * buf.dtype.sizeOf();
    const orig_b = if (ci) |c| c.original_bytes else buf.size * buf.dtype.sizeOf();
    const ratio = if (ci) |c| c.compression_ratio else 1.0;
    const savings = if (ci) |c| c.savings_pct else 0.0;
    const nnz_val = if (ci) |c| c.nnz else buf.size;

    try dict.value.dict_type.put(Dynamic.initStr("is_compressed"), Dynamic.initBool(is_comp));
    try dict.value.dict_type.put(Dynamic.initStr("scheme"), Dynamic.initStr(scheme));
    try dict.value.dict_type.put(Dynamic.initStr("compressed_bytes"), Dynamic.initInt(@intCast(comp_b)));
    try dict.value.dict_type.put(Dynamic.initStr("original_bytes"), Dynamic.initInt(@intCast(orig_b)));
    try dict.value.dict_type.put(Dynamic.initStr("compression_ratio"), Dynamic.initFloat(ratio));
    try dict.value.dict_type.put(Dynamic.initStr("savings_pct"), Dynamic.initFloat(savings));
    try dict.value.dict_type.put(Dynamic.initStr("nnz"), Dynamic.initInt(@intCast(nnz_val)));
    return dict;
}
