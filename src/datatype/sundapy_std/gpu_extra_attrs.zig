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

// ============================================================================
// Extra GPU Subsystem Dynamic Dispatch Table
// ============================================================================

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

    return null;
}
