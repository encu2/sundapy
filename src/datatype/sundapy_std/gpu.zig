const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");

pub const GpuBuffer = gpu_types.GpuBuffer;
pub const BoundKernel = gpu_types.BoundKernel;
pub const createBoundKernel = gpu_types.createBoundKernel;
pub const bufferLen = gpu_types.bufferLen;
pub const bufferGetItem = gpu_types.bufferGetItem;
pub const bufferSetItem = gpu_types.bufferSetItem;
pub const bufferGetAttribute = gpu_types.bufferGetAttribute;
pub const printBuffer = gpu_types.printBuffer;

extern "c" fn dlopen(filename: ?[*:0]const u8, flag: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;
extern "c" fn dlerror() ?[*:0]const u8;

const RTLD_NOW: c_int = 2;

// ============================================================================
// Phase 2: Multi-Distro Shared Library Discovery
// ============================================================================

pub const DISTRO_CUDA_PATHS = [_][]const u8{
    // Arch Linux / CachyOS / Manjaro
    "/usr/lib/libcuda.so.1",
    "/usr/lib/libcuda.so",
    // Ubuntu / Debian / Pop!_OS / Linux Mint (x86_64)
    "/usr/lib/x86_64-linux-gnu/libcuda.so.1",
    "/usr/lib/x86_64-linux-gnu/libcuda.so",
    // Fedora / RHEL / CentOS / Rocky / Alma Linux
    "/usr/lib64/libcuda.so.1",
    "/usr/lib64/libcuda.so",
    // Alpine Linux / musl
    "/lib/libcuda.so.1",
    "/usr/lib/libcuda.so.1",
    // Debian / Ubuntu ARM64 / NVIDIA Jetson
    "/usr/lib/aarch64-linux-gnu/libcuda.so.1",
    "/usr/lib/aarch64-linux-gnu/libcuda.so",
    // Standalone CUDA Toolkit / Driver installations
    "/usr/local/cuda/lib64/libcuda.so.1",
    "/usr/local/cuda/lib64/libcuda.so",
    "/opt/cuda/lib64/libcuda.so",
    "/usr/local/cuda-12/lib64/libcuda.so.1",
    "/usr/local/cuda-11/lib64/libcuda.so.1",
    // openSUSE / SLES
    "/usr/X11R6/lib64/libcuda.so.1",
    // Generic dynamic loader fallback (uses /etc/ld.so.cache & LD_LIBRARY_PATH)
    "libcuda.so.1",
    "libcuda.so",
};

pub const DISTRO_VULKAN_PATHS = [_][]const u8{
    // Arch / CachyOS / Manjaro
    "/usr/lib/libvulkan.so.1",
    "/usr/lib/libvulkan.so",
    // Ubuntu / Debian / PopOS
    "/usr/lib/x86_64-linux-gnu/libvulkan.so.1",
    "/usr/lib/x86_64-linux-gnu/libvulkan.so",
    // Fedora / RHEL
    "/usr/lib64/libvulkan.so.1",
    "/usr/lib64/libvulkan.so",
    // Alpine
    "/lib/libvulkan.so.1",
    // Generic
    "libvulkan.so.1",
    "libvulkan.so",
};

pub const DISTRO_OPENCL_PATHS = [_][]const u8{
    // Arch / CachyOS / Manjaro
    "/usr/lib/libOpenCL.so.1",
    "/usr/lib/libOpenCL.so",
    // Ubuntu / Debian
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so.1",
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so",
    // Fedora / RHEL
    "/usr/lib64/libOpenCL.so.1",
    "/usr/lib64/libOpenCL.so",
    // Generic
    "libOpenCL.so.1",
    "libOpenCL.so",
};

// ============================================================================
// CUDA Driver API C Definitions
// ============================================================================

pub const CUresult = c_int;
pub const CUDA_SUCCESS: c_int = 0;
pub const CUdevice = c_int;
pub const CUcontext = ?*anyopaque;
pub const CUmodule = ?*anyopaque;
pub const CUfunction = ?*anyopaque;
pub const CUstream = ?*anyopaque;
pub const CUdeviceptr = u64;

pub const CudaApi = struct {
    handle: ?*anyopaque = null,
    cuInit: *const fn (c_uint) callconv(.c) CUresult,
    cuDeviceGetCount: *const fn (*c_int) callconv(.c) CUresult,
    cuDeviceGet: *const fn (*CUdevice, c_int) callconv(.c) CUresult,
    cuDeviceGetName: *const fn ([*]u8, c_int, CUdevice) callconv(.c) CUresult,
    cuDeviceTotalMem: *const fn (*usize, CUdevice) callconv(.c) CUresult,
    cuCtxCreate: *const fn (*CUcontext, c_uint, CUdevice) callconv(.c) CUresult,
    cuCtxDestroy: *const fn (CUcontext) callconv(.c) CUresult,
    cuCtxSynchronize: *const fn () callconv(.c) CUresult,
    cuMemAlloc: *const fn (*CUdeviceptr, usize) callconv(.c) CUresult,
    cuMemFree: *const fn (CUdeviceptr) callconv(.c) CUresult,
    cuMemcpyHtoD: *const fn (CUdeviceptr, ?*const anyopaque, usize) callconv(.c) CUresult,
    cuMemcpyDtoH: *const fn (?*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult,
    cuModuleLoadData: *const fn (*CUmodule, ?*const anyopaque) callconv(.c) CUresult,
    cuModuleGetFunction: *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult,
    cuLaunchKernel: *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, CUstream, ?*?*anyopaque, ?*?*anyopaque) callconv(.c) CUresult,
};

pub const BackendType = enum {
    none,
    cpu_multicore,
    cuda,
    vulkan,
    opencl,
};

pub var active_backend: BackendType = .none;
pub var is_driver_initialized: bool = false;
pub var cuda_api: ?CudaApi = null;
pub var cuda_device: CUdevice = 0;
pub var cuda_context: CUcontext = null;
pub var cuda_device_name: [256]u8 = [_]u8{0} ** 256;
pub var cuda_device_name_len: usize = 0;
pub var detected_lib_path: []const u8 = "";

fn loadSymbol(handle: *anyopaque, comptime T: type, name: [*:0]const u8) ?T {
    const sym = dlsym(handle, name);
    if (sym == null) return null;
    return @ptrCast(sym);
}

fn syncBufferToDevice(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyHtoD(buf.dev_ptr, buf.data.ptr, byte_len);
    }
}

fn syncBufferToHost(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyDtoH(buf.data.ptr, buf.dev_ptr, byte_len);
    }
}

fn syncBufferItemSet(buf: *GpuBuffer, idx: usize, val: f32) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const offset = idx * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyHtoD(buf.dev_ptr + offset, &val, @sizeOf(f32));
    }
}

fn freeCudaDevicePtr(dev_ptr: u64) void {
    if (cuda_api) |api| {
        _ = api.cuMemFree(dev_ptr);
    }
}

pub fn initGpuDriver() void {
    if (is_driver_initialized) return;
    is_driver_initialized = true;

    // Register hooks into gpu_types
    gpu_types.launch_fn = launchInternal;
    gpu_types.buffer_free_fn = freeCudaDevicePtr;
    gpu_types.buffer_to_device_fn = syncBufferToDevice;
    gpu_types.buffer_to_host_fn = syncBufferToHost;
    gpu_types.buffer_item_set_fn = null;

    // 1. Try CUDA Driver API across distro paths
    for (DISTRO_CUDA_PATHS) |path| {
        var buf: [512:0]u8 = undefined;
        if (path.len >= 511) continue;
        @memcpy(buf[0..path.len], path);
        buf[path.len] = 0;

        const handle = dlopen(&buf, RTLD_NOW);
        if (handle) |h| {
            const cuInitFn = loadSymbol(h, *const fn (c_uint) callconv(.c) CUresult, "cuInit");
            const cuDeviceGetCountFn = loadSymbol(h, *const fn (*c_int) callconv(.c) CUresult, "cuDeviceGetCount");
            const cuDeviceGetFn = loadSymbol(h, *const fn (*CUdevice, c_int) callconv(.c) CUresult, "cuDeviceGet");
            const cuDeviceGetNameFn = loadSymbol(h, *const fn ([*]u8, c_int, CUdevice) callconv(.c) CUresult, "cuDeviceGetName");
            const cuDeviceTotalMemFn = loadSymbol(h, *const fn (*usize, CUdevice) callconv(.c) CUresult, "cuDeviceTotalMem");
            const cuCtxCreateFn = loadSymbol(h, *const fn (*CUcontext, c_uint, CUdevice) callconv(.c) CUresult, "cuCtxCreate_v2") orelse
                loadSymbol(h, *const fn (*CUcontext, c_uint, CUdevice) callconv(.c) CUresult, "cuCtxCreate");
            const cuCtxDestroyFn = loadSymbol(h, *const fn (CUcontext) callconv(.c) CUresult, "cuCtxDestroy_v2") orelse
                loadSymbol(h, *const fn (CUcontext) callconv(.c) CUresult, "cuCtxDestroy");
            const cuCtxSynchronizeFn = loadSymbol(h, *const fn () callconv(.c) CUresult, "cuCtxSynchronize");
            const cuMemAllocFn = loadSymbol(h, *const fn (*CUdeviceptr, usize) callconv(.c) CUresult, "cuMemAlloc_v2") orelse
                loadSymbol(h, *const fn (*CUdeviceptr, usize) callconv(.c) CUresult, "cuMemAlloc");
            const cuMemFreeFn = loadSymbol(h, *const fn (CUdeviceptr) callconv(.c) CUresult, "cuMemFree_v2") orelse
                loadSymbol(h, *const fn (CUdeviceptr) callconv(.c) CUresult, "cuMemFree");
            const cuMemcpyHtoDFn = loadSymbol(h, *const fn (CUdeviceptr, ?*const anyopaque, usize) callconv(.c) CUresult, "cuMemcpyHtoD_v2") orelse
                loadSymbol(h, *const fn (CUdeviceptr, ?*const anyopaque, usize) callconv(.c) CUresult, "cuMemcpyHtoD");
            const cuMemcpyDtoHFn = loadSymbol(h, *const fn (?*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoH_v2") orelse
                loadSymbol(h, *const fn (?*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoH");
            const cuModuleLoadDataFn = loadSymbol(h, *const fn (*CUmodule, ?*const anyopaque) callconv(.c) CUresult, "cuModuleLoadData");
            const cuModuleGetFunctionFn = loadSymbol(h, *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult, "cuModuleGetFunction");
            const cuLaunchKernelFn = loadSymbol(h, *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, CUstream, ?*?*anyopaque, ?*?*anyopaque) callconv(.c) CUresult, "cuLaunchKernel");

            if (cuInitFn != null and cuDeviceGetCountFn != null and cuDeviceGetFn != null and cuCtxCreateFn != null and cuMemAllocFn != null) {
                if (cuInitFn.?(0) == CUDA_SUCCESS) {
                    var count: c_int = 0;
                    if (cuDeviceGetCountFn.?(&count) == CUDA_SUCCESS and count > 0) {
                        var dev: CUdevice = 0;
                        if (cuDeviceGetFn.?(&dev, 0) == CUDA_SUCCESS) {
                            var ctx: CUcontext = null;
                            if (cuCtxCreateFn.?(&ctx, 0, dev) == CUDA_SUCCESS) {
                                cuda_device = dev;
                                cuda_context = ctx;
                                detected_lib_path = path;

                                if (cuDeviceGetNameFn) |nameFn| {
                                    if (nameFn(&cuda_device_name, 255, dev) == CUDA_SUCCESS) {
                                        cuda_device_name_len = std.mem.indexOfScalar(u8, &cuda_device_name, 0) orelse 255;
                                    }
                                }

                                cuda_api = CudaApi{
                                    .handle = h,
                                    .cuInit = cuInitFn.?,
                                    .cuDeviceGetCount = cuDeviceGetCountFn.?,
                                    .cuDeviceGet = cuDeviceGetFn.?,
                                    .cuDeviceGetName = cuDeviceGetNameFn orelse undefined,
                                    .cuDeviceTotalMem = cuDeviceTotalMemFn orelse undefined,
                                    .cuCtxCreate = cuCtxCreateFn.?,
                                    .cuCtxDestroy = cuCtxDestroyFn orelse undefined,
                                    .cuCtxSynchronize = cuCtxSynchronizeFn orelse undefined,
                                    .cuMemAlloc = cuMemAllocFn.?,
                                    .cuMemFree = cuMemFreeFn orelse undefined,
                                    .cuMemcpyHtoD = cuMemcpyHtoDFn orelse undefined,
                                    .cuMemcpyDtoH = cuMemcpyDtoHFn orelse undefined,
                                    .cuModuleLoadData = cuModuleLoadDataFn orelse undefined,
                                    .cuModuleGetFunction = cuModuleGetFunctionFn orelse undefined,
                                    .cuLaunchKernel = cuLaunchKernelFn orelse undefined,
                                };

                                active_backend = .cuda;
                                return;
                            }
                        }
                    }
                }
            }
            _ = dlclose(h);
        }
    }

    // 2. Fallback to CPU Multi-Core Engine
    active_backend = .cpu_multicore;
}

// ============================================================================
// Thread-Local SPMD Indexing Primitives
// ============================================================================

pub threadlocal var cur_thread_idx_x: usize = 0;
pub threadlocal var cur_thread_idx_y: usize = 0;
pub threadlocal var cur_thread_idx_z: usize = 0;
pub threadlocal var cur_block_idx_x: usize = 0;
pub threadlocal var cur_block_idx_y: usize = 0;
pub threadlocal var cur_block_idx_z: usize = 0;
pub threadlocal var cur_block_dim_x: usize = 1;
pub threadlocal var cur_block_dim_y: usize = 1;
pub threadlocal var cur_block_dim_z: usize = 1;
pub threadlocal var cur_grid_dim_x: usize = 1;
pub threadlocal var cur_grid_dim_y: usize = 1;
pub threadlocal var cur_grid_dim_z: usize = 1;

pub fn thread_idx_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_x)); }
pub fn thread_idx_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_y)); }
pub fn thread_idx_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_z)); }
pub fn block_idx_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_x)); }
pub fn block_idx_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_y)); }
pub fn block_idx_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_z)); }
pub fn block_dim_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_x)); }
pub fn block_dim_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_y)); }
pub fn block_dim_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_dim_z)); }
pub fn grid_dim_x() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_x)); }
pub fn grid_dim_y() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_y)); }
pub fn grid_dim_z() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_grid_dim_z)); }

pub fn thread_id() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_thread_idx_x)); }
pub fn block_id() anyerror!Dynamic { return Dynamic.initInt(@intCast(cur_block_idx_x)); }
pub fn global_id() anyerror!Dynamic {
    const gid = cur_thread_idx_x + cur_block_idx_x * cur_block_dim_x;
    return Dynamic.initInt(@intCast(gid));
}
pub fn global_size() anyerror!Dynamic {
    const gsz = cur_grid_dim_x * cur_block_dim_x;
    return Dynamic.initInt(@intCast(gsz));
}
pub fn syncthreads() anyerror!Dynamic { return sync(); }

// ============================================================================
// Multi-Core CPU & GPU Kernel Dispatcher
// ============================================================================

const WorkerPayload = struct {
    kernel_fn: Dynamic,
    start_block: usize,
    end_block: usize,
    grid_x: usize,
    grid_y: usize,
    grid_z: usize,
    block_x: usize,
    block_y: usize,
    block_z: usize,
    args: []const Dynamic,
    alloc: std.mem.Allocator,
};

fn cpuWorker(payload: WorkerPayload) void {
    cur_grid_dim_x = payload.grid_x;
    cur_grid_dim_y = payload.grid_y;
    cur_grid_dim_z = payload.grid_z;
    cur_block_dim_x = payload.block_x;
    cur_block_dim_y = payload.block_y;
    cur_block_dim_z = payload.block_z;

    var b: usize = payload.start_block;
    while (b < payload.end_block) : (b += 1) {
        cur_block_idx_x = b % payload.grid_x;
        cur_block_idx_y = (b / payload.grid_x) % payload.grid_y;
        cur_block_idx_z = b / (payload.grid_x * payload.grid_y);

        var tx: usize = 0;
        while (tx < payload.block_x) : (tx += 1) {
            cur_thread_idx_x = tx;
            var ty: usize = 0;
            while (ty < payload.block_y) : (ty += 1) {
                cur_thread_idx_y = ty;
                var tz: usize = 0;
                while (tz < payload.block_z) : (tz += 1) {
                    cur_thread_idx_z = tz;
                    _ = payload.kernel_fn.builtin_call(payload.alloc, payload.args, null) catch {};
                }
            }
        }
    }
}

pub fn launchInternal(allocator_mem: std.mem.Allocator, kernel_fn: Dynamic, gx: usize, gy: usize, gz: usize, bx: usize, by: usize, bz: usize, args: []const Dynamic) anyerror!Dynamic {
    initGpuDriver();

    for (args) |arg| {
        if (arg.value == .gpu_buffer_type) {
            const buf: *GpuBuffer = @ptrCast(@alignCast(arg.value.gpu_buffer_type));
            buf.toDevice();
        }
    }

    const total_blocks = gx * gy * gz;
    if (total_blocks == 0) return Dynamic.initNone();

    const cpu_count = std.Thread.getCpuCount() catch 4;
    const num_threads = @min(total_blocks, @max(1, cpu_count));

    if (num_threads <= 1) {
        cpuWorker(WorkerPayload{
            .kernel_fn = kernel_fn,
            .start_block = 0,
            .end_block = total_blocks,
            .grid_x = gx,
            .grid_y = gy,
            .grid_z = gz,
            .block_x = bx,
            .block_y = by,
            .block_z = bz,
            .args = args,
            .alloc = allocator_mem,
        });
    } else {
        var thread_list = try allocator_mem.alloc(std.Thread, num_threads);
        defer allocator_mem.free(thread_list);

        const blocks_per_thread = (total_blocks + num_threads - 1) / num_threads;
        var spawned: usize = 0;
        var start_b: usize = 0;

        for (0..num_threads) |_| {
            if (start_b >= total_blocks) break;
            const end_b = @min(total_blocks, start_b + blocks_per_thread);

            const payload = WorkerPayload{
                .kernel_fn = kernel_fn,
                .start_block = start_b,
                .end_block = end_b,
                .grid_x = gx,
                .grid_y = gy,
                .grid_z = gz,
                .block_x = bx,
                .block_y = by,
                .block_z = bz,
                .args = args,
                .alloc = allocator_mem,
            };

            thread_list[spawned] = try std.Thread.spawn(.{}, cpuWorker, .{payload});
            spawned += 1;
            start_b = end_b;
        }

        for (0..spawned) |i| {
            thread_list[i].join();
        }
    }

    for (args) |arg| {
        if (arg.value == .gpu_buffer_type) {
            const buf: *GpuBuffer = @ptrCast(@alignCast(arg.value.gpu_buffer_type));
            buf.toDevice();
        }
    }

    return Dynamic.initNone();
}

// ============================================================================
// SIMD Vectorized Math Accelerators
// ============================================================================

pub fn vector_add(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, @min(b.size, c.size));

    const Vector8f = @Vector(8, f32);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        const vc: Vector8f = va + vb;
        c.data[i..][0..8].* = vc;
    }
    while (i < n) : (i += 1) {
        c.data[i] = a.data[i] + b.data[i];
    }
    c.toDevice();
    return Dynamic.initNone();
}

pub fn vector_mul(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, @min(b.size, c.size));

    const Vector8f = @Vector(8, f32);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        const vc: Vector8f = va * vb;
        c.data[i..][0..8].* = vc;
    }
    while (i < n) : (i += 1) {
        c.data[i] = a.data[i] * b.data[i];
    }
    c.toDevice();
    return Dynamic.initNone();
}

pub fn matmul(a_dyn: Dynamic, b_dyn: Dynamic, c_dyn: Dynamic, m_dyn: Dynamic, k_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type or c_dyn.value != .gpu_buffer_type) return error.TypeError;
    if (m_dyn.value != .i64_type or k_dyn.value != .i64_type or n_dyn.value != .i64_type) return error.TypeError;

    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const c: *GpuBuffer = @ptrCast(@alignCast(c_dyn.value.gpu_buffer_type));

    const M: usize = @intCast(m_dyn.value.i64_type);
    const K: usize = @intCast(k_dyn.value.i64_type);
    const N: usize = @intCast(n_dyn.value.i64_type);

    var i: usize = 0;
    while (i < M) : (i += 1) {
        var j: usize = 0;
        while (j < N) : (j += 1) {
            var sum: f32 = 0.0;
            var k: usize = 0;
            while (k < K) : (k += 1) {
                sum += a.data[i * K + k] * b.data[k * N + j];
            }
            c.data[i * N + j] = sum;
        }
    }
    c.toDevice();
    return Dynamic.initNone();
}

pub fn reduce_sum(buf_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(buf.size, @as(usize, @intCast(n_dyn.value.i64_type))) else buf.size;

    const Vector8f = @Vector(8, f32);
    var acc: Vector8f = @splat(0.0);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const v: Vector8f = buf.data[i..][0..8].*;
        acc += v;
    }
    var sum: f32 = @reduce(.Add, acc);
    while (i < n) : (i += 1) {
        sum += buf.data[i];
    }
    return Dynamic.initFloat(@floatCast(sum));
}

pub fn dot_product(a_dyn: Dynamic, b_dyn: Dynamic, n_dyn: Dynamic) anyerror!Dynamic {
    if (a_dyn.value != .gpu_buffer_type or b_dyn.value != .gpu_buffer_type) return error.TypeError;
    const a: *GpuBuffer = @ptrCast(@alignCast(a_dyn.value.gpu_buffer_type));
    const b: *GpuBuffer = @ptrCast(@alignCast(b_dyn.value.gpu_buffer_type));
    const n = if (n_dyn.value == .i64_type) @min(a.size, @as(usize, @intCast(n_dyn.value.i64_type))) else @min(a.size, b.size);

    const Vector8f = @Vector(8, f32);
    var acc: Vector8f = @splat(0.0);
    var i: usize = 0;
    while (i + 8 <= n) : (i += 8) {
        const va: Vector8f = a.data[i..][0..8].*;
        const vb: Vector8f = b.data[i..][0..8].*;
        acc += va * vb;
    }
    var sum: f32 = @reduce(.Add, acc);
    while (i < n) : (i += 1) {
        sum += a.data[i] * b.data[i];
    }
    return Dynamic.initFloat(@floatCast(sum));
}

pub fn render_4d_object(buf_dyn: Dynamic, w_dyn: Dynamic, h_dyn: Dynamic, time_dyn: Dynamic) anyerror!Dynamic {
    if (buf_dyn.value != .gpu_buffer_type) return error.TypeError;
    const buf: *GpuBuffer = @ptrCast(@alignCast(buf_dyn.value.gpu_buffer_type));

    const w: usize = if (w_dyn.value == .i64_type) @intCast(@max(1, w_dyn.value.i64_type)) else 80;
    const h: usize = if (h_dyn.value == .i64_type) @intCast(@max(1, h_dyn.value.i64_type)) else 40;
    const t: f32 = switch (time_dyn.value) {
        .float_type => |f| @floatCast(f),
        .i64_type => |i| @floatFromInt(i),
        else => 0.0,
    };

    // Precalculate 4D rotation angles
    const a1 = t * 1.3;
    const a2 = t * 0.85;
    const a3 = t * 1.1;
    const a4 = t * 0.7;

    const cos1 = @cos(a1);
    const sin1 = @sin(a1);
    const cos2 = @cos(a2);
    const sin2 = @sin(a2);
    const cos3 = @cos(a3);
    const sin3 = @sin(a3);
    const cos4 = @cos(a4);
    const sin4 = @sin(a4);

    const R1 = 1.25 + 0.30 * @cos(1.8 * t);
    const R2 = 1.25 + 0.30 * @sin(1.4 * t);
    const r_tube_base: f32 = 0.28;

    const RowPayload = struct {
        buf: *GpuBuffer,
        w: usize,
        h: usize,
        start_y: usize,
        end_y: usize,
        t: f32,
        cos1: f32, sin1: f32,
        cos2: f32, sin2: f32,
        cos3: f32, sin3: f32,
        cos4: f32, sin4: f32,
        R1: f32, R2: f32, r_tube_base: f32,
    };

    const rowWorker = struct {
        fn run(p: RowPayload) void {
            var py = p.start_y;
            while (py < p.end_y) : (py += 1) {
                const ndc_y = (2.0 * (@as(f32, @floatFromInt(py)) + 0.5) / @as(f32, @floatFromInt(p.h)) - 1.0);
                var px: usize = 0;
                while (px < p.w) : (px += 1) {
                    const aspect = @as(f32, @floatFromInt(p.w)) / @as(f32, @floatFromInt(p.h));
                    const ndc_x = (2.0 * (@as(f32, @floatFromInt(px)) + 0.5) / @as(f32, @floatFromInt(p.w)) - 1.0) * aspect;

                    const ro_x: f32 = 0.0;
                    const ro_y: f32 = 0.0;
                    const ro_z: f32 = -3.2;
                    const ro_w: f32 = 0.0;

                    const rlen = @sqrt(ndc_x * ndc_x + ndc_y * ndc_y + 4.0);
                    const rd_x: f32 = ndc_x / rlen;
                    const rd_y: f32 = ndc_y / rlen;
                    const rd_z: f32 = 2.0 / rlen;
                    const rd_w: f32 = 0.0;

                    var dist_traveled: f32 = 0.0;
                    var hit: bool = false;
                    var hit_x: f32 = 0.0;
                    var hit_y: f32 = 0.0;
                    var hit_z: f32 = 0.0;
                    var hit_w: f32 = 0.0;
                    var iter: usize = 0;

                    while (iter < 28 and dist_traveled < 6.0) : (iter += 1) {
                        const px_cur = ro_x + rd_x * dist_traveled;
                        const py_cur = ro_y + rd_y * dist_traveled;
                        const pz_cur = ro_z + rd_z * dist_traveled;
                        const pw_cur = ro_w + rd_w * dist_traveled;

                        const x1 = px_cur * p.cos1 - pw_cur * p.sin1;
                        const w1 = px_cur * p.sin1 + pw_cur * p.cos1;

                        const y1 = py_cur * p.cos2 - w1 * p.sin2;
                        const w2 = py_cur * p.sin2 + w1 * p.cos2;

                        const z1 = pz_cur * p.cos3 - w2 * p.sin3;
                        const w3 = pz_cur * p.sin3 + w2 * p.cos3;

                        const x2 = x1 * p.cos4 - z1 * p.sin4;
                        const z2 = x1 * p.sin4 + z1 * p.cos4;

                        const q1 = @sqrt(x2 * x2 + y1 * y1) - p.R1;
                        const q2 = @sqrt(z2 * z2 + w3 * w3) - p.R2;
                        const r_tube = p.r_tube_base + 0.08 * @cos(3.0 * std.math.atan2(y1, x2) + 2.5 * p.t);
                        const d = @sqrt(q1 * q1 + q2 * q2) - r_tube;

                        if (d < 0.006) {
                            hit = true;
                            hit_x = x2;
                            hit_y = y1;
                            hit_z = z2;
                            hit_w = w3;
                            break;
                        }
                        dist_traveled += @max(d * 0.75, 0.01);
                    }

                    const out_idx = (py * p.w + px) * 3;
                    if (hit) {
                        const nx = hit_x;
                        const ny = hit_y;
                        const nz = hit_z;
                        const nlen = @sqrt(nx * nx + ny * ny + nz * nz + 0.001);
                        const norm_x = nx / nlen;
                        const norm_y = ny / nlen;
                        const norm_z = nz / nlen;

                        const lx: f32 = 0.577;
                        const ly: f32 = 0.577;
                        const lz: f32 = -0.577;
                        const diff = @max(0.15, norm_x * lx + norm_y * ly + norm_z * lz);

                        const hx = lx;
                        const hy = ly;
                        const hz = lz - 1.0;
                        const hlen = @sqrt(hx * hx + hy * hy + hz * hz + 0.001);
                        const spec = std.math.pow(f32, @max(0.0, (norm_x * hx + norm_y * hy + norm_z * hz) / hlen), 16.0);

                        const hue = hit_w * 2.2 + p.t * 1.5;
                        const cr = (0.5 + 0.5 * @sin(hue)) * diff * 220.0 + spec * 255.0;
                        const cg = (0.5 + 0.5 * @sin(hue + 2.094)) * diff * 220.0 + spec * 255.0;
                        const cb = (0.5 + 0.5 * @sin(hue + 4.188)) * diff * 220.0 + spec * 255.0;

                        p.buf.data[out_idx] = @min(255.0, cr);
                        p.buf.data[out_idx + 1] = @min(255.0, cg);
                        p.buf.data[out_idx + 2] = @min(255.0, cb);
                    } else {
                        const bg_r: f32 = 10.0 + 6.0 * (1.0 - ndc_y);
                        const bg_g: f32 = 12.0 + 8.0 * (1.0 - ndc_y);
                        const bg_b: f32 = 28.0 + 20.0 * (1.0 - ndc_y);
                        p.buf.data[out_idx] = bg_r;
                        p.buf.data[out_idx + 1] = bg_g;
                        p.buf.data[out_idx + 2] = bg_b;
                    }
                }
            }
        }
    }.run;

    const cpu_count = std.Thread.getCpuCount() catch 4;
    const num_threads = @min(h, @max(1, cpu_count));

    if (num_threads <= 1) {
        rowWorker(RowPayload{
            .buf = buf, .w = w, .h = h, .start_y = 0, .end_y = h, .t = t,
            .cos1 = cos1, .sin1 = sin1, .cos2 = cos2, .sin2 = sin2,
            .cos3 = cos3, .sin3 = sin3, .cos4 = cos4, .sin4 = sin4,
            .R1 = R1, .R2 = R2, .r_tube_base = r_tube_base,
        });
    } else {
        var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
        defer arena.deinit();
        const a = arena.allocator();

        var threads = try a.alloc(std.Thread, num_threads);
        const rows_per_thread = (h + num_threads - 1) / num_threads;
        var start_y: usize = 0;
        var spawned: usize = 0;

        for (0..num_threads) |_| {
            if (start_y >= h) break;
            const end_y = @min(h, start_y + rows_per_thread);
            threads[spawned] = try std.Thread.spawn(.{}, rowWorker, .{RowPayload{
                .buf = buf, .w = w, .h = h, .start_y = start_y, .end_y = end_y, .t = t,
                .cos1 = cos1, .sin1 = sin1, .cos2 = cos2, .sin2 = sin2,
                .cos3 = cos3, .sin3 = sin3, .cos4 = cos4, .sin4 = sin4,
                .R1 = R1, .R2 = R2, .r_tube_base = r_tube_base,
            }});
            spawned += 1;
            start_y = end_y;
        }

        for (0..spawned) |i| {
            threads[i].join();
        }
    }

    buf.toDevice();
    return Dynamic.initNone();
}

// ============================================================================
// Exported Python Module APIs
// ============================================================================

pub fn alloc(size: Dynamic) anyerror!Dynamic {
    initGpuDriver();
    var s: usize = 0;
    if (size.value == .i64_type) {
        s = @intCast(@max(0, size.value.i64_type));
    } else {
        return error.TypeError;
    }
    const buf = try GpuBuffer.init(std.heap.c_allocator, s);
    if (active_backend == .cuda and cuda_api != null) {
        var cu_ptr: CUdeviceptr = 0;
        const byte_len = s * @sizeOf(f32);
        if (cuda_api.?.cuMemAlloc(&cu_ptr, byte_len) == CUDA_SUCCESS) {
            buf.dev_ptr = cu_ptr;
            buf.is_device_allocated = true;
            _ = cuda_api.?.cuMemcpyHtoD(cu_ptr, buf.data.ptr, byte_len);
        }
    }
    return buf.asDynamic();
}

pub fn Buffer(size: Dynamic) anyerror!Dynamic {
    return alloc(size);
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
    if (active_backend == .cuda and cuda_api != null) {
        _ = cuda_api.?.cuCtxSynchronize();
    }
    return Dynamic.initNone();
}

pub fn synchronize() anyerror!Dynamic {
    return sync();
}

pub fn get_backend() anyerror!Dynamic {
    initGpuDriver();
    return switch (active_backend) {
        .cuda => Dynamic.initStr("cuda"),
        .vulkan => Dynamic.initStr("vulkan"),
        .opencl => Dynamic.initStr("opencl"),
        .cpu_multicore => Dynamic.initStr("cpu_multicore"),
        .none => Dynamic.initStr("none"),
    };
}

pub fn get_device_name() anyerror!Dynamic {
    initGpuDriver();
    if (active_backend == .cuda and cuda_device_name_len > 0) {
        return Dynamic.initStr(cuda_device_name[0..cuda_device_name_len]);
    }
    return Dynamic.initStr("CPU (Multi-Core SIMD Engine)");
}

pub fn get_device_count() anyerror!Dynamic {
    initGpuDriver();
    if (active_backend == .cuda and cuda_api != null) {
        var count: c_int = 0;
        if (cuda_api.?.cuDeviceGetCount(&count) == CUDA_SUCCESS) {
            return Dynamic.initInt(@intCast(count));
        }
    }
    const cpu_count = std.Thread.getCpuCount() catch 1;
    return Dynamic.initInt(@intCast(cpu_count));
}

pub fn get_lib_path() anyerror!Dynamic {
    initGpuDriver();
    return Dynamic.initStr(detected_lib_path);
}

pub fn kernel(fn_dyn: Dynamic) anyerror!Dynamic {
    return fn_dyn;
}

pub fn jit(fn_dyn: Dynamic) anyerror!Dynamic {
    return fn_dyn;
}

pub fn parallel_for(start_dyn: Dynamic, end_dyn: Dynamic, func: Dynamic) anyerror!Dynamic {
    if (start_dyn.value != .i64_type or end_dyn.value != .i64_type) return error.TypeError;
    const start: i64 = start_dyn.value.i64_type;
    const end: i64 = end_dyn.value.i64_type;
    if (start >= end) return Dynamic.initNone();

    const total: usize = @intCast(end - start);
    const cpu_count = std.Thread.getCpuCount() catch 4;
    const num_threads = @min(total, @max(1, cpu_count));

    const ParForPayload = struct {
        func: Dynamic,
        start_idx: i64,
        end_idx: i64,
    };

    const worker = struct {
        fn run(p: ParForPayload) void {
            var i = p.start_idx;
            while (i < p.end_idx) : (i += 1) {
                const arg = [_]Dynamic{Dynamic.initInt(i)};
                _ = p.func.builtin_call(std.heap.c_allocator, &arg, null) catch {};
            }
        }
    }.run;

    if (num_threads <= 1) {
        worker(ParForPayload{ .func = func, .start_idx = start, .end_idx = end });
    } else {
        var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
        defer arena.deinit();
        const a = arena.allocator();

        var threads = try a.alloc(std.Thread, num_threads);
        const chunk = (total + num_threads - 1) / num_threads;
        var s: i64 = start;
        var spawned: usize = 0;

        for (0..num_threads) |_| {
            if (s >= end) break;
            const e = @min(end, s + @as(i64, @intCast(chunk)));
            threads[spawned] = try std.Thread.spawn(.{}, worker, .{ParForPayload{ .func = func, .start_idx = s, .end_idx = e }});
            spawned += 1;
            s = e;
        }

        for (0..spawned) |idx| {
            threads[idx].join();
        }
    }

    return Dynamic.initNone();
}

pub fn cpu_parallel(start_dyn: Dynamic, end_dyn: Dynamic, func: Dynamic) anyerror!Dynamic {
    return parallel_for(start_dyn, end_dyn, func);
}

pub fn launch(alloc_unused: std.mem.Allocator, args: []const Dynamic, kwargs_unused: ?Dynamic) anyerror!Dynamic {
    _ = alloc_unused;
    _ = kwargs_unused;
    if (args.len < 3) return error.TypeError;
    const kernel_fn = args[0];
    const grid_dyn = args[1];
    const block_dyn = args[2];
    const kernel_args = if (args.len > 3) args[3..] else &[_]Dynamic{};

    var gx: usize = 1;
    var gy: usize = 1;
    var gz: usize = 1;
    if (grid_dyn.value == .i64_type) {
        gx = @intCast(@max(1, grid_dyn.value.i64_type));
    } else if (grid_dyn.value == .list_type or grid_dyn.value == .tuple_type) {
        const items = if (grid_dyn.value == .list_type) grid_dyn.value.list_type.items.items else grid_dyn.value.tuple_type.items;
        if (items.len > 0 and items[0].value == .i64_type) gx = @intCast(@max(1, items[0].value.i64_type));
        if (items.len > 1 and items[1].value == .i64_type) gy = @intCast(@max(1, items[1].value.i64_type));
        if (items.len > 2 and items[2].value == .i64_type) gz = @intCast(@max(1, items[2].value.i64_type));
    }

    var bx: usize = 1;
    var by: usize = 1;
    var bz: usize = 1;
    if (block_dyn.value == .i64_type) {
        bx = @intCast(@max(1, block_dyn.value.i64_type));
    } else if (block_dyn.value == .list_type or block_dyn.value == .tuple_type) {
        const items = if (block_dyn.value == .list_type) block_dyn.value.list_type.items.items else block_dyn.value.tuple_type.items;
        if (items.len > 0 and items[0].value == .i64_type) bx = @intCast(@max(1, items[0].value.i64_type));
        if (items.len > 1 and items[1].value == .i64_type) by = @intCast(@max(1, items[1].value.i64_type));
        if (items.len > 2 and items[2].value == .i64_type) bz = @intCast(@max(1, items[2].value.i64_type));
    }

    return launchInternal(std.heap.c_allocator, kernel_fn, gx, gy, gz, bx, by, bz, kernel_args);
}

pub fn render_mario_frame(
    buf_dyn: Dynamic,
    w_dyn: Dynamic,
    h_dyn: Dynamic,
    cam_x_dyn: Dynamic,
    cam_y_dyn: Dynamic,
    mario_dyn: Dynamic,
    entities_dyn: Dynamic,
    tiles_dyn: Dynamic,
    map_w_dyn: Dynamic,
    map_h_dyn: Dynamic,
    hud_dyn: Dynamic,
    time_dyn: Dynamic,
) anyerror!Dynamic {
    const args = [_]Dynamic{
        buf_dyn,
        w_dyn,
        h_dyn,
        cam_x_dyn,
        cam_y_dyn,
        mario_dyn,
        entities_dyn,
        tiles_dyn,
        map_w_dyn,
        map_h_dyn,
        hud_dyn,
        time_dyn,
    };
    return @import("GUIEngine.zig").renderGameScene(std.heap.c_allocator, &args, null);
}

pub fn builtin_getattr(attr: []const u8) anyerror!Dynamic {
    if (std.mem.eql(u8, attr, "alloc")) return @import("datatype/dynamic.zig").toDynamicFunc(alloc);
    if (std.mem.eql(u8, attr, "Buffer")) return @import("datatype/dynamic.zig").toDynamicFunc(Buffer);
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
    if (std.mem.eql(u8, attr, "reduce_sum")) return @import("datatype/dynamic.zig").toDynamicFunc(reduce_sum);
    if (std.mem.eql(u8, attr, "dot_product")) return @import("datatype/dynamic.zig").toDynamicFunc(dot_product);
    if (std.mem.eql(u8, attr, "render_4d_object")) return @import("datatype/dynamic.zig").toDynamicFunc(render_4d_object);
    if (std.mem.eql(u8, attr, "render_mario_frame")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame } };
    if (std.mem.eql(u8, attr, "render_game_frame")) return Dynamic{ .value = .{ .func_type_slice = render_mario_frame } };
    if (std.mem.eql(u8, attr, "parallel_for")) return @import("datatype/dynamic.zig").toDynamicFunc(parallel_for);
    if (std.mem.eql(u8, attr, "cpu_parallel")) return @import("datatype/dynamic.zig").toDynamicFunc(cpu_parallel);
    if (std.mem.eql(u8, attr, "global_id")) return @import("datatype/dynamic.zig").toDynamicFunc(global_id);
    if (std.mem.eql(u8, attr, "global_size")) return @import("datatype/dynamic.zig").toDynamicFunc(global_size);
    if (std.mem.eql(u8, attr, "thread_id")) return @import("datatype/dynamic.zig").toDynamicFunc(thread_id);
    if (std.mem.eql(u8, attr, "block_id")) return @import("datatype/dynamic.zig").toDynamicFunc(block_id);
    if (std.mem.eql(u8, attr, "syncthreads")) return @import("datatype/dynamic.zig").toDynamicFunc(syncthreads);
    return error.AttributeError;
}


pub fn _is_abi() void {}
pub fn __sundapy_module_init() !void {
    initGpuDriver();
}
