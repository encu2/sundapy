const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const atomic = @import("gpu_atomic.zig");
const scan = @import("gpu_scan.zig");
const morton = @import("gpu_morton.zig");
const shared = @import("gpu_shared.zig");
const vulkan = @import("gpu_vulkan.zig");
const opencl = @import("gpu_opencl.zig");
const driver = @import("gpu_driver.zig");
const slab = @import("gpu_slab.zig");
const sparse_vm = @import("gpu_sparse_vm.zig");
const arena = @import("gpu_arena.zig");
const gateway = @import("gpu_gateway.zig");
const pool = @import("gpu_pool.zig");
const gpu_types = @import("datatype/gpu_types.zig");
const graph = @import("gpu_graph.zig");

// ============================================================================
// Extra GPU Subsystem Dynamic Dispatch Table
// ============================================================================

fn sparse_buffer_slice(_: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    if (args.len == 0) return error.TypeError;
    const size_dyn = args[0];
    var page_size_dyn: ?Dynamic = if (args.len > 1) args[1] else null;
    if (page_size_dyn == null and kwargs != null and kwargs.?.value == .dict_type) {
        if (kwargs.?.value.dict_type.get(Dynamic.initStr("page_size"))) |ps| {
            page_size_dyn = ps;
        }
    }
    return sparse_vm.sparse_buffer(size_dyn, page_size_dyn);
}

fn sparse_compress_idle_slice(_: std.mem.Allocator, args: []const Dynamic, _: ?Dynamic) anyerror!Dynamic {
    if (args.len == 0) return error.TypeError;
    return sparse_vm.sparse_compress_idle(args[0]);
}

fn alloc_pinned_slice(_: std.mem.Allocator, args: []const Dynamic, _: ?Dynamic) anyerror!Dynamic {
    if (args.len == 0) return error.TypeError;
    var s: usize = 0;
    if (args[0].value == .i64_type) {
        s = @intCast(@max(0, args[0].value.i64_type));
    } else return error.TypeError;

    var dt = gpu_types.GpuDtype.f32;
    if (args.len > 1 and args[1].value == .str_type) {
        dt = gpu_types.GpuDtype.fromString(args[1].value.str_type);
    }
    driver.initGpuDriver(null);
    const buf = try gpu_types.GpuBuffer.initPinned(std.heap.c_allocator, s, dt);
    return buf.asDynamic();
}

fn is_vmm_supported_dyn() anyerror!Dynamic {
    driver.initGpuDriver(null);
    return Dynamic.initBool(driver.isVmmSupported());
}

fn vmm_granularity_dyn() anyerror!Dynamic {
    driver.initGpuDriver(null);
    return Dynamic.initInt(@intCast(driver.getVmmGranularity()));
}

fn graph_benchmark_slice(_: std.mem.Allocator, args: []const Dynamic, _: ?Dynamic) anyerror!Dynamic {
    if (args.len == 0) return error.TypeError;
    const iters: ?Dynamic = if (args.len > 1) args[1] else null;
    return graph.graph_benchmark(args[0], iters);
}

fn copy_slice(_: std.mem.Allocator, args: []const Dynamic, _: ?Dynamic) anyerror!Dynamic {
    if (args.len < 2) return error.TypeError;
    if (args[0].value != .gpu_buffer_type or args[1].value != .gpu_buffer_type) return error.TypeError;
    const src: *gpu_types.GpuBuffer = @ptrCast(@alignCast(args[0].value.gpu_buffer_type));
    const dst: *gpu_types.GpuBuffer = @ptrCast(@alignCast(args[1].value.gpu_buffer_type));
    if (gpu_types.buffer_copy_fn) |cfn| {
        _ = cfn(dst, src);
        return Dynamic.initNone();
    }
    return error.CopyFailed;
}

pub fn lookup(attr: []const u8) ?Dynamic {
    // Hardware Lock-Free Atomics
    if (std.mem.eql(u8, attr, "atomic_add")) return dynamic.toDynamicFunc(atomic.atomic_add);
    if (std.mem.eql(u8, attr, "atomic_sub")) return dynamic.toDynamicFunc(atomic.atomic_sub);
    if (std.mem.eql(u8, attr, "atomic_min")) return dynamic.toDynamicFunc(atomic.atomic_min);
    if (std.mem.eql(u8, attr, "atomic_max")) return dynamic.toDynamicFunc(atomic.atomic_max);
    if (std.mem.eql(u8, attr, "atomic_and")) return dynamic.toDynamicFunc(atomic.atomic_and);
    if (std.mem.eql(u8, attr, "atomic_or")) return dynamic.toDynamicFunc(atomic.atomic_or);
    if (std.mem.eql(u8, attr, "atomic_xor")) return dynamic.toDynamicFunc(atomic.atomic_xor);
    if (std.mem.eql(u8, attr, "atomic_cas")) return dynamic.toDynamicFunc(atomic.atomic_cas);

    // Blelloch Parallel Scan & Reductions
    if (std.mem.eql(u8, attr, "prefix_sum")) return dynamic.toDynamicFunc(scan.prefix_sum);
    if (std.mem.eql(u8, attr, "exclusive_scan")) return dynamic.toDynamicFunc(scan.exclusive_scan);
    if (std.mem.eql(u8, attr, "reduce_min")) return dynamic.toDynamicFunc(scan.reduce_min);
    if (std.mem.eql(u8, attr, "reduce_max")) return dynamic.toDynamicFunc(scan.reduce_max);
    if (std.mem.eql(u8, attr, "reduce_prod")) return dynamic.toDynamicFunc(scan.reduce_prod);
    if (std.mem.eql(u8, attr, "argmin")) return dynamic.toDynamicFunc(scan.argmin);
    if (std.mem.eql(u8, attr, "argmax")) return dynamic.toDynamicFunc(scan.argmax);
    if (std.mem.eql(u8, attr, "radix_sort")) return dynamic.toDynamicFunc(scan.radix_sort);

    // Taichi Morton Z-Order & Layout Transpositions
    if (std.mem.eql(u8, attr, "morton_encode_2d")) return dynamic.toDynamicFunc(morton.morton_encode_2d);
    if (std.mem.eql(u8, attr, "morton_decode_2d")) return dynamic.toDynamicFunc(morton.morton_decode_2d);
    if (std.mem.eql(u8, attr, "morton_encode_3d")) return dynamic.toDynamicFunc(morton.morton_encode_3d);
    if (std.mem.eql(u8, attr, "morton_decode_3d")) return dynamic.toDynamicFunc(morton.morton_decode_3d);
    if (std.mem.eql(u8, attr, "morton_swizzle_2d")) return dynamic.toDynamicFunc(morton.morton_swizzle_2d);
    if (std.mem.eql(u8, attr, "morton_unswizzle_2d")) return dynamic.toDynamicFunc(morton.morton_unswizzle_2d);
    if (std.mem.eql(u8, attr, "aos_to_soa")) return dynamic.toDynamicFunc(morton.aos_to_soa);
    if (std.mem.eql(u8, attr, "soa_to_aos")) return dynamic.toDynamicFunc(morton.soa_to_aos);

    // Numba Block Shared Memory & Warp Shuffles
    if (std.mem.eql(u8, attr, "shared_array")) return dynamic.toDynamicFunc(shared.shared_array);
    if (std.mem.eql(u8, attr, "grid")) return dynamic.toDynamicFunc(shared.grid);
    if (std.mem.eql(u8, attr, "warp_shuffle_down")) return dynamic.toDynamicFunc(shared.warp_shuffle_down);
    if (std.mem.eql(u8, attr, "warp_shuffle_xor")) return dynamic.toDynamicFunc(shared.warp_shuffle_xor);

    // Cross-Vendor Driver Query & Controls
    if (std.mem.eql(u8, attr, "set_backend")) return dynamic.toDynamicFunc(driver.set_backend);
    if (std.mem.eql(u8, attr, "is_vulkan_available")) return dynamic.toDynamicFunc(vulkan.is_vulkan_available);
    if (std.mem.eql(u8, attr, "get_vulkan_device_name")) return dynamic.toDynamicFunc(vulkan.get_vulkan_device_name);
    if (std.mem.eql(u8, attr, "get_vulkan_device_count")) return dynamic.toDynamicFunc(vulkan.get_vulkan_device_count);
    if (std.mem.eql(u8, attr, "get_vulkan_device_type")) return dynamic.toDynamicFunc(vulkan.get_vulkan_device_type);
    if (std.mem.eql(u8, attr, "get_vulkan_api_version")) return dynamic.toDynamicFunc(vulkan.get_vulkan_api_version);

    if (std.mem.eql(u8, attr, "is_opencl_available")) return dynamic.toDynamicFunc(opencl.is_opencl_available);
    if (std.mem.eql(u8, attr, "get_opencl_device_name")) return dynamic.toDynamicFunc(opencl.get_opencl_device_name);
    if (std.mem.eql(u8, attr, "get_opencl_device_count")) return dynamic.toDynamicFunc(opencl.get_opencl_device_count);
    if (std.mem.eql(u8, attr, "get_opencl_compute_units")) return dynamic.toDynamicFunc(opencl.get_opencl_compute_units);
    if (std.mem.eql(u8, attr, "get_opencl_platform_name")) return dynamic.toDynamicFunc(opencl.get_opencl_platform_name);

    if (std.mem.eql(u8, attr, "alloc_dtype") or std.mem.eql(u8, attr, "alloc_typed")) return dynamic.toDynamicFunc(@import("gpu.zig").alloc_dtype);

    // Pinned Host Memory (Zero-Staging DMA) & Direct DMA Buffer Copy
    if (std.mem.eql(u8, attr, "alloc_pinned") or std.mem.eql(u8, attr, "pinned_buffer")) return Dynamic{ .value = .{ .func_type_slice = alloc_pinned_slice } };
    if (std.mem.eql(u8, attr, "copy") or std.mem.eql(u8, attr, "copy_buffer")) return Dynamic{ .value = .{ .func_type_slice = copy_slice } };

    // Hardware Virtual Memory Management (VMM)
    if (std.mem.eql(u8, attr, "is_vmm_supported")) return dynamic.toDynamicFunc(is_vmm_supported_dyn);
    if (std.mem.eql(u8, attr, "vmm_granularity")) return dynamic.toDynamicFunc(vmm_granularity_dyn);

    // Targeted CUDA Graph Execution Engine
    if (std.mem.eql(u8, attr, "create_graph") or std.mem.eql(u8, attr, "Graph")) return dynamic.toDynamicFunc(graph.create_graph);
    if (std.mem.eql(u8, attr, "graph_instantiate")) return dynamic.toDynamicFunc(graph.graph_instantiate);
    if (std.mem.eql(u8, attr, "graph_launch")) return dynamic.toDynamicFunc(graph.graph_launch);
    if (std.mem.eql(u8, attr, "graph_benchmark")) return Dynamic{ .value = .{ .func_type_slice = graph_benchmark_slice } };

    // VRAM Slab & Buddy Sub-Allocator
    if (std.mem.eql(u8, attr, "slab_alloc")) return dynamic.toDynamicFunc(slab.slab_alloc);
    if (std.mem.eql(u8, attr, "slab_free")) return dynamic.toDynamicFunc(slab.slab_free);
    if (std.mem.eql(u8, attr, "slab_stats")) return dynamic.toDynamicFunc(slab.slab_stats);
    if (std.mem.eql(u8, attr, "defragment")) return dynamic.toDynamicFunc(slab.defragment);

    // Sparse Virtual Memory & Page Table Paging
    if (std.mem.eql(u8, attr, "sparse_buffer") or std.mem.eql(u8, attr, "sparse_alloc")) return Dynamic{ .value = .{ .func_type_slice = sparse_buffer_slice } };
    if (std.mem.eql(u8, attr, "sparse_stats")) return dynamic.toDynamicFunc(sparse_vm.sparse_stats);
    if (std.mem.eql(u8, attr, "sparse_commit")) return dynamic.toDynamicFunc(sparse_vm.sparse_commit);
    if (std.mem.eql(u8, attr, "sparse_decommit")) return dynamic.toDynamicFunc(sparse_vm.sparse_decommit);
    if (std.mem.eql(u8, attr, "sparse_compress_idle")) return Dynamic{ .value = .{ .func_type_slice = sparse_compress_idle_slice } };

    // Memory Arena Sub-Allocator Enhancements
    if (std.mem.eql(u8, attr, "arena_stats")) return dynamic.toDynamicFunc(arena.arena_stats);
    if (std.mem.eql(u8, attr, "arena_defragment")) return dynamic.toDynamicFunc(arena.arena_defragment);
    if (std.mem.eql(u8, attr, "arena_sparse_alloc")) return dynamic.toDynamicFunc(arena.arena_sparse_alloc);

    // Interop Gateway & Sparse Page Mapping
    if (std.mem.eql(u8, attr, "sparse_page_map")) return dynamic.toDynamicFunc(gateway.sparse_page_map);
    if (std.mem.eql(u8, attr, "commit_virtual_range")) return dynamic.toDynamicFunc(gateway.commit_virtual_range);

    // High-Throughput Worker Pool
    if (std.mem.eql(u8, attr, "pool_stats")) return dynamic.toDynamicFunc(pool.pool_stats);
    if (std.mem.eql(u8, attr, "pool_parallel_zero")) return dynamic.toDynamicFunc(pool.pool_parallel_zero);

    if (@import("gpu_compress.zig").lookup(attr)) |dyn| return dyn;

    return null;
}
