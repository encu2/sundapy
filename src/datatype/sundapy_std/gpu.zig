const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");

pub const driver = @import("gpu_driver.zig");
pub const spmd = @import("gpu_spmd.zig");
pub const dispatch = @import("gpu_dispatch.zig");
pub const math = @import("gpu_math.zig");
pub const math3d = @import("gpu_math3d.zig");
pub const earth = @import("gpu_earth.zig");
pub const render3d = @import("gpu_render3d.zig");
pub const render4d = @import("gpu_render4d.zig");
pub const pool = @import("gpu_pool.zig");
pub const arena = @import("gpu_arena.zig");
pub const gpu_field = @import("gpu_field.zig");
pub const gateway = @import("gpu_gateway.zig");
pub const atomic = @import("gpu_atomic.zig");
pub const scan = @import("gpu_scan.zig");
pub const morton = @import("gpu_morton.zig");
pub const shared = @import("gpu_shared.zig");
pub const vulkan = @import("gpu_vulkan.zig");
pub const opencl = @import("gpu_opencl.zig");
pub const extra_attrs = @import("gpu_extra_attrs.zig");

pub const GpuBuffer = gpu_types.GpuBuffer;
pub const BoundKernel = gpu_types.BoundKernel;
pub const createBoundKernel = gpu_types.createBoundKernel;
pub const bufferLen = gpu_types.bufferLen;
pub const bufferGetItem = gpu_types.bufferGetItem;
pub const bufferSetItem = gpu_types.bufferSetItem;
pub const bufferGetAttribute = gpu_types.bufferGetAttribute;
pub const printBuffer = gpu_types.printBuffer;

// Arena exports
pub const arena_alloc = arena.arena_alloc;
pub const arena_reset = arena.arena_reset;

// Field exports
pub const Field = gpu_field.Field;
pub fn field(shape_dyn: Dynamic) anyerror!Dynamic {
    return gpu_field.create_field(&[_]Dynamic{shape_dyn});
}
pub fn create_field(shape_dyn: Dynamic) anyerror!Dynamic {
    return gpu_field.create_field(&[_]Dynamic{shape_dyn});
}

// Gateway exports
pub const to_raw_handle = gateway.to_raw_handle;
pub const from_raw_handle = gateway.from_raw_handle;
pub const get_raw_pointer = gateway.get_raw_pointer;

// Driver exports
pub const BackendType = driver.BackendType;
pub const active_backend = driver.active_backend;
pub const initGpuDriver = driver.initGpuDriver;
pub const get_backend = driver.get_backend;
pub const get_device_name = driver.get_device_name;
pub const get_device_count = driver.get_device_count;
pub const get_lib_path = driver.get_lib_path;

// SPMD exports
pub const thread_idx_x = spmd.thread_idx_x;
pub const thread_idx_y = spmd.thread_idx_y;
pub const thread_idx_z = spmd.thread_idx_z;
pub const block_idx_x = spmd.block_idx_x;
pub const block_idx_y = spmd.block_idx_y;
pub const block_idx_z = spmd.block_idx_z;
pub const block_dim_x = spmd.block_dim_x;
pub const block_dim_y = spmd.block_dim_y;
pub const block_dim_z = spmd.block_dim_z;
pub const grid_dim_x = spmd.grid_dim_x;
pub const grid_dim_y = spmd.grid_dim_y;
pub const grid_dim_z = spmd.grid_dim_z;
pub const thread_id = spmd.thread_id;
pub const block_id = spmd.block_id;
pub const global_id = spmd.global_id;
pub const global_size = spmd.global_size;
pub const syncthreads = spmd.syncthreads;

// Dispatch exports
pub const launch = dispatch.launch;
pub const parallel_for = dispatch.parallel_for;
pub const cpu_parallel = dispatch.cpu_parallel;

// Math exports
pub const vector_add = math.vector_add;
pub const vector_mul = math.vector_mul;
pub const matmul = math.matmul;
pub const reduce_sum = math.reduce_sum;
pub const dot_product = math.dot_product;

// 3D Math exports
pub const mat4_identity = math3d.mat4_identity;
pub const mat4_perspective = math3d.mat4_perspective;
pub const mat4_look_at = math3d.mat4_look_at;
pub const vec3 = math3d.vec3;

// 3D and 4D rendering exports
pub const render_3d_object = render3d.render_3d_object;
pub const render_3d = render3d.render_3d_object;
pub const render_3d_earth = earth.render_3d_earth;
pub const render_earth = earth.render_3d_earth;
pub const render_4d_object = render4d.render_4d_object;

// Atomics exports
pub const atomic_add = atomic.atomic_add;
pub const atomic_sub = atomic.atomic_sub;
pub const atomic_min = atomic.atomic_min;
pub const atomic_max = atomic.atomic_max;
pub const atomic_and = atomic.atomic_and;
pub const atomic_or = atomic.atomic_or;
pub const atomic_xor = atomic.atomic_xor;
pub const atomic_cas = atomic.atomic_cas;

// Scan & Sort exports
pub const prefix_sum = scan.prefix_sum;
pub const exclusive_scan = scan.exclusive_scan;
pub const reduce_min = scan.reduce_min;
pub const reduce_max = scan.reduce_max;
pub const reduce_prod = scan.reduce_prod;
pub const argmin = scan.argmin;
pub const argmax = scan.argmax;
pub const radix_sort = scan.radix_sort;

// Morton & Layout exports
pub const morton_encode_2d = morton.morton_encode_2d;
pub const morton_decode_2d = morton.morton_decode_2d;
pub const morton_encode_3d = morton.morton_encode_3d;
pub const morton_decode_3d = morton.morton_decode_3d;
pub const morton_swizzle_2d = morton.morton_swizzle_2d;
pub const morton_unswizzle_2d = morton.morton_unswizzle_2d;
pub const aos_to_soa = morton.aos_to_soa;
pub const soa_to_aos = morton.soa_to_aos;

// Shared & Warp exports
pub const shared_array = shared.shared_array;
pub const grid = shared.grid;
pub const warp_shuffle_down = shared.warp_shuffle_down;
pub const warp_shuffle_xor = shared.warp_shuffle_xor;

// Cross-vendor Driver exports
pub const set_backend = driver.set_backend;
pub const is_vulkan_available = vulkan.is_vulkan_available;
pub const get_vulkan_device_name = vulkan.get_vulkan_device_name;
pub const get_vulkan_device_count = vulkan.get_vulkan_device_count;
pub const get_vulkan_device_type = vulkan.get_vulkan_device_type;
pub const get_vulkan_api_version = vulkan.get_vulkan_api_version;
pub const is_opencl_available = opencl.is_opencl_available;
pub const get_opencl_device_name = opencl.get_opencl_device_name;
pub const get_opencl_device_count = opencl.get_opencl_device_count;
pub const get_opencl_compute_units = opencl.get_opencl_compute_units;
pub const get_opencl_platform_name = opencl.get_opencl_platform_name;

// ============================================================================
// Buffer Allocation & Memory Management
// ============================================================================

pub fn alloc(size: Dynamic) anyerror!Dynamic {
    driver.initGpuDriver(dispatch.launchInternal);
    var s: usize = 0;
    if (size.value == .i64_type) {
        s = @intCast(@max(0, size.value.i64_type));
    } else {
        return error.TypeError;
    }

    const byte_len = s * @sizeOf(f32);
    _ = @import("gpu_budget.zig").autoCompactIfNeeded(byte_len);

    if (driver.active_backend == .cuda and driver.cuda_api != null and driver.cuda_api.?.cuMemAllocManaged != null) {
        var cu_ptr: driver.CUdeviceptr = 0;
        // CU_MEM_ATTACH_GLOBAL = 1
        if (driver.cuda_api.?.cuMemAllocManaged.?(&cu_ptr, byte_len, 1) == driver.CUDA_SUCCESS) {
            const host_slice: [*]f32 = @ptrFromInt(cu_ptr);
            @memset(host_slice[0..s], 0.0);

            const buf = try std.heap.c_allocator.create(GpuBuffer);
            buf.* = GpuBuffer{
                .allocator = std.heap.c_allocator,
                .size = s,
                .data = host_slice[0..s],
                .dev_ptr = cu_ptr,
                .is_device_allocated = true,
                .is_managed = true,
            };
            @import("gpu_budget.zig").registerBuffer(buf);
            return buf.asDynamic();
        }
    }

    const buf = try GpuBuffer.init(std.heap.c_allocator, s);
    if (driver.active_backend == .cuda and driver.cuda_api != null) {
        var cu_ptr: driver.CUdeviceptr = 0;
        if (driver.cuda_api.?.cuMemAlloc(&cu_ptr, byte_len) == driver.CUDA_SUCCESS) {
            buf.dev_ptr = cu_ptr;
            buf.is_device_allocated = true;
            _ = driver.cuda_api.?.cuMemcpyHtoD(cu_ptr, buf.data.ptr, byte_len);
        }
    }
    @import("gpu_budget.zig").registerBuffer(buf);
    return buf.asDynamic();
}

pub fn Buffer(size: Dynamic) anyerror!Dynamic {
    return alloc(size);
}

/// Alias: gpu.zeros(n) -> alloc n f32 elements, all zero-initialised
pub fn zeros(size: Dynamic) anyerror!Dynamic {
    return alloc(size);
}

/// Alias: gpu.ones(n) -> alloc n f32 elements, all set to 1.0
pub fn ones(size: Dynamic) anyerror!Dynamic {
    var s: usize = 0;
    if (size.value == .i64_type) s = @intCast(@max(0, size.value.i64_type)) else return error.TypeError;
    const buf = try GpuBuffer.init(std.heap.c_allocator, s);
    @memset(buf.data, 1.0);
    @import("gpu_budget.zig").registerBuffer(buf);
    return buf.asDynamic();
}

/// Alias: gpu.empty(n) -> alloc n f32 elements (uninitialised)
pub fn empty(size: Dynamic) anyerror!Dynamic {
    return alloc(size);
}

pub fn allocDtype(size: Dynamic, dtype_dyn: Dynamic) anyerror!Dynamic {
    driver.initGpuDriver(dispatch.launchInternal);
    var s: usize = 0;
    if (size.value == .i64_type) {
        s = @intCast(@max(0, size.value.i64_type));
    } else {
        return error.TypeError;
    }

    var dt = gpu_types.GpuDtype.f32;
    if (dtype_dyn.value == .str_type) {
        dt = gpu_types.GpuDtype.fromString(dtype_dyn.value.str_type);
    }
    _ = @import("gpu_budget.zig").autoCompactIfNeeded(s * dt.sizeOf());
    const buf = try GpuBuffer.initWithDtype(std.heap.c_allocator, s, dt);
    @import("gpu_budget.zig").registerBuffer(buf);
    return buf.asDynamic();
}

pub const alloc_dtype = allocDtype;
pub const alloc_typed = allocDtype;

fn alloc_slice(allocator_mem: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = allocator_mem;
    _ = kwargs;
    if (args.len == 0) return error.TypeError;
    if (args.len == 1) return alloc(args[0]);
    return allocDtype(args[0], args[1]);
}

pub fn to_device(buf_or_list: Dynamic) anyerror!Dynamic {
    if (buf_or_list.value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(buf_or_list.value.gpu_buffer_type));
        buf.toDevice();
        return buf_or_list;
    } else if (buf_or_list.value == .list_type) {
        const items = buf_or_list.value.list_type.items.items;
        const b = try alloc(Dynamic.initInt(@intCast(items.len)));
        const buf: *GpuBuffer = @ptrCast(@alignCast(b.value.gpu_buffer_type));
        try buf.copyFromList(buf_or_list);
        return b;
    }
    return error.TypeError;
}

pub fn to_host(buf_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value == .gpu_buffer_type) {
        const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
        return buf.toList(std.heap.c_allocator);
    }
    return error.TypeError;
}

pub fn sync() anyerror!Dynamic {
    driver.syncCuda();
    return Dynamic.initNone();
}

pub fn synchronize() anyerror!Dynamic {
    return sync();
}

pub fn kernel(fn_dyn: Dynamic) anyerror!Dynamic {
    return fn_dyn;
}

pub fn jit(fn_dyn: Dynamic) anyerror!Dynamic {
    return fn_dyn;
}

fn matmul_slice(allocator_mem: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = allocator_mem;
    _ = kwargs;
    if (args.len < 6) return error.TypeError;
    return math.matmul(args[0], args[1], args[2], args[3], args[4], args[5]);
}

fn render_3d_slice(allocator_mem: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = allocator_mem;
    _ = kwargs;
    if (args.len < 5) return error.TypeError;
    return render3d.render_3d_object(args[0], args[1], args[2], args[3], args[4]);
}

fn render_earth_slice(allocator_mem: std.mem.Allocator, args: []const Dynamic, kwargs: ?Dynamic) anyerror!Dynamic {
    _ = allocator_mem;
    _ = kwargs;
    if (args.len < 4) return error.TypeError;
    const dist: ?Dynamic = if (args.len > 4) args[4] else null;
    const lat: ?Dynamic = if (args.len > 5) args[5] else null;
    const lon: ?Dynamic = if (args.len > 6) args[6] else null;
    return earth.render_3d_earth(args[0], args[1], args[2], args[3], dist, lat, lon);
}

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (extra_attrs.lookup(attr)) |dyn| return dyn;
    // Buffer Allocation Aliases
    if (std.mem.eql(u8, attr, "alloc") or std.mem.eql(u8, attr, "Buffer")) return Dynamic{ .value = .{ .func_type_slice = alloc_slice } };
    if (std.mem.eql(u8, attr, "zeros")) return @import("datatype/dynamic.zig").toDynamicFunc(zeros);
    if (std.mem.eql(u8, attr, "ones")) return @import("datatype/dynamic.zig").toDynamicFunc(ones);
    if (std.mem.eql(u8, attr, "empty")) return @import("datatype/dynamic.zig").toDynamicFunc(empty);
    if (std.mem.eql(u8, attr, "to_device")) return @import("datatype/dynamic.zig").toDynamicFunc(to_device);
    if (std.mem.eql(u8, attr, "to_host")) return @import("datatype/dynamic.zig").toDynamicFunc(to_host);
    if (std.mem.eql(u8, attr, "sync")) return @import("datatype/dynamic.zig").toDynamicFunc(sync);
    if (std.mem.eql(u8, attr, "synchronize")) return @import("datatype/dynamic.zig").toDynamicFunc(synchronize);
    if (std.mem.eql(u8, attr, "get_backend")) return @import("datatype/dynamic.zig").toDynamicFunc(get_backend);
    if (std.mem.eql(u8, attr, "get_device_name")) return @import("datatype/dynamic.zig").toDynamicFunc(get_device_name);
    if (std.mem.eql(u8, attr, "get_device_count")) return @import("datatype/dynamic.zig").toDynamicFunc(get_device_count);
    if (std.mem.eql(u8, attr, "get_lib_path")) return @import("datatype/dynamic.zig").toDynamicFunc(get_lib_path);
    if (std.mem.eql(u8, attr, "kernel")) return @import("datatype/dynamic.zig").toDynamicFunc(kernel);
    if (std.mem.eql(u8, attr, "jit")) return @import("datatype/dynamic.zig").toDynamicFunc(jit);
    if (std.mem.eql(u8, attr, "vector_add")) return @import("datatype/dynamic.zig").toDynamicFunc(vector_add);
    if (std.mem.eql(u8, attr, "vector_mul")) return @import("datatype/dynamic.zig").toDynamicFunc(vector_mul);
    if (std.mem.eql(u8, attr, "matmul")) return Dynamic{ .value = .{ .func_type_slice = matmul_slice } };
    if (std.mem.eql(u8, attr, "reduce_sum")) return @import("datatype/dynamic.zig").toDynamicFunc(reduce_sum);
    if (std.mem.eql(u8, attr, "dot_product")) return @import("datatype/dynamic.zig").toDynamicFunc(dot_product);
    if (std.mem.eql(u8, attr, "mat4_identity")) return @import("datatype/dynamic.zig").toDynamicFunc(mat4_identity);
    if (std.mem.eql(u8, attr, "mat4_perspective")) return @import("datatype/dynamic.zig").toDynamicFunc(mat4_perspective);
    if (std.mem.eql(u8, attr, "mat4_look_at")) return @import("datatype/dynamic.zig").toDynamicFunc(mat4_look_at);
    if (std.mem.eql(u8, attr, "vec3")) return @import("datatype/dynamic.zig").toDynamicFunc(vec3);
    if (std.mem.eql(u8, attr, "render_3d_object")) return Dynamic{ .value = .{ .func_type_slice = render_3d_slice } };
    if (std.mem.eql(u8, attr, "render_3d")) return Dynamic{ .value = .{ .func_type_slice = render_3d_slice } };
    if (std.mem.eql(u8, attr, "render_3d_earth")) return Dynamic{ .value = .{ .func_type_slice = render_earth_slice } };
    if (std.mem.eql(u8, attr, "render_earth")) return Dynamic{ .value = .{ .func_type_slice = render_earth_slice } };
    if (std.mem.eql(u8, attr, "render_4d_object")) return @import("datatype/dynamic.zig").toDynamicFunc(render_4d_object);
    if (std.mem.eql(u8, attr, "render_mario_frame")) return Dynamic{ .value = .{ .func_type_slice = @import("GUIEngine.zig").render_mario_frame } };
    if (std.mem.eql(u8, attr, "render_game_scene")) return Dynamic{ .value = .{ .func_type_slice = @import("GUIEngine.zig").render_game_scene } };
    if (std.mem.eql(u8, attr, "parallel_for")) return @import("datatype/dynamic.zig").toDynamicFunc(parallel_for);
    if (std.mem.eql(u8, attr, "cpu_parallel")) return @import("datatype/dynamic.zig").toDynamicFunc(cpu_parallel);
    if (std.mem.eql(u8, attr, "global_id")) return @import("datatype/dynamic.zig").toDynamicFunc(global_id);
    if (std.mem.eql(u8, attr, "global_size")) return @import("datatype/dynamic.zig").toDynamicFunc(global_size);
    if (std.mem.eql(u8, attr, "thread_id")) return @import("datatype/dynamic.zig").toDynamicFunc(thread_id);
    if (std.mem.eql(u8, attr, "block_id")) return @import("datatype/dynamic.zig").toDynamicFunc(block_id);
    if (std.mem.eql(u8, attr, "syncthreads")) return @import("datatype/dynamic.zig").toDynamicFunc(syncthreads);

    // Memory Arena Sub-Allocator (LLA)
    if (std.mem.eql(u8, attr, "arena_alloc")) return @import("datatype/dynamic.zig").toDynamicFunc(arena_alloc);
    if (std.mem.eql(u8, attr, "arena_reset")) return @import("datatype/dynamic.zig").toDynamicFunc(arena_reset);

    // Multidimensional Field HLA (Taichi/Numba style)
    if (std.mem.eql(u8, attr, "field")) return @import("datatype/dynamic.zig").toDynamicFunc(field);
    if (std.mem.eql(u8, attr, "create_field")) return @import("datatype/dynamic.zig").toDynamicFunc(create_field);

    // Zero-Copy Interop Gateway (LLA <-> HLA)
    if (std.mem.eql(u8, attr, "to_raw_handle")) return @import("datatype/dynamic.zig").toDynamicFunc(to_raw_handle);
    if (std.mem.eql(u8, attr, "from_raw_handle")) return @import("datatype/dynamic.zig").toDynamicFunc(from_raw_handle);
    if (std.mem.eql(u8, attr, "get_raw_pointer")) return @import("datatype/dynamic.zig").toDynamicFunc(get_raw_pointer);
    return error.AttributeError;
}

pub fn __sundapy_module_init() !void {
    driver.initGpuDriver(dispatch.launchInternal);
    @import("gpu_sparse_vm.zig").initSparseVmBridge();
    @import("gpu_graph.zig").initGraphBridge();
    gpu_types.buffer_compress_hook = @import("gpu_compress.zig").bufferCompressHook;
    gpu_types.buffer_decompress_hook = @import("gpu_compress.zig").bufferDecompressHook;
    gpu_types.buffer_spmv_fn = @import("gpu_sparse.zig").bufferSpmvHook;
    gpu_types.budget_register_fn = @import("gpu_budget.zig").registerBuffer;
    gpu_types.budget_unregister_fn = @import("gpu_budget.zig").unregisterBuffer;
}
