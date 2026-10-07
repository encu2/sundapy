const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
pub const vulkan = @import("gpu_vulkan.zig");
pub const opencl = @import("gpu_opencl.zig");

extern "c" fn dlopen(filename: ?[*:0]const u8, flag: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;
extern "c" fn dlerror() ?[*:0]const u8;

const RTLD_NOW: c_int = 2;
const RTLD_GLOBAL: c_int = 256;

// ============================================================================
// Multi-Distro Shared Library Discovery
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
    // Generic dynamic loader fallback
    "libcuda.so.1",
    "libcuda.so",
};

pub const DISTRO_VULKAN_PATHS = [_][]const u8{
    "/usr/lib/libvulkan.so.1",
    "/usr/lib/libvulkan.so",
    "/usr/lib/x86_64-linux-gnu/libvulkan.so.1",
    "/usr/lib/x86_64-linux-gnu/libvulkan.so",
    "/usr/lib64/libvulkan.so.1",
    "/usr/lib64/libvulkan.so",
    "/lib/libvulkan.so.1",
    "libvulkan.so.1",
    "libvulkan.so",
};

pub const DISTRO_OPENCL_PATHS = [_][]const u8{
    "/usr/lib/libOpenCL.so.1",
    "/usr/lib/libOpenCL.so",
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so.1",
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so",
    "/usr/lib64/libOpenCL.so.1",
    "/usr/lib64/libOpenCL.so",
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
    cuMemAllocManaged: ?*const fn (*CUdeviceptr, usize, c_uint) callconv(.c) CUresult = null,
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

pub fn loadSymbol(handle: *anyopaque, comptime T: type, name: [*:0]const u8) ?T {
    const sym = dlsym(handle, name);
    if (sym == null) return null;
    return @ptrCast(sym);
}

pub fn syncBufferToDevice(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyHtoD(buf.dev_ptr, buf.data.ptr, byte_len);
    }
}

pub fn syncBufferToHost(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyDtoH(buf.data.ptr, buf.dev_ptr, byte_len);
    }
}

pub fn syncBufferItemSet(buf: *GpuBuffer, idx: usize, val: f32) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const offset = idx * @sizeOf(f32);
        _ = cuda_api.?.cuMemcpyHtoD(buf.dev_ptr + offset, &val, @sizeOf(f32));
    }
}

pub fn syncCuda() void {
    if (cuda_api) |api| {
        _ = api.cuCtxSynchronize();
    }
}

pub fn freeCudaDevicePtr(dev_ptr: u64) void {
    if (cuda_api) |api| {
        _ = api.cuMemFree(dev_ptr);
    }
}

pub fn initGpuDriver(launch_fn_ptr: ?gpu_types.LaunchFn) void {
    if (is_driver_initialized) return;
    is_driver_initialized = true;

    // Register hooks into gpu_types
    if (launch_fn_ptr) |lfn| {
        gpu_types.launch_fn = lfn;
    }
    gpu_types.buffer_free_fn = freeCudaDevicePtr;
    gpu_types.buffer_sync_fn = syncCuda;
    gpu_types.buffer_to_device_fn = syncBufferToDevice;
    gpu_types.buffer_to_host_fn = syncBufferToHost;
    gpu_types.buffer_item_set_fn = null;

    // Preload PTX JIT compiler globally: required for cuModuleLoadData on Blackwell sm_120
    const ptxjit_paths = [_][*:0]const u8{
        "/usr/lib/libnvidia-ptxjitcompiler.so.1",
        "/usr/lib/x86_64-linux-gnu/libnvidia-ptxjitcompiler.so.1",
        "/usr/lib64/libnvidia-ptxjitcompiler.so.1",
        "libnvidia-ptxjitcompiler.so.1",
    };
    for (ptxjit_paths) |p| {
        const h = dlopen(p, RTLD_NOW | RTLD_GLOBAL);
        if (h != null) break;
    }

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
            const cuMemAllocManagedFn = loadSymbol(h, *const fn (*CUdeviceptr, usize, c_uint) callconv(.c) CUresult, "cuMemAllocManaged");
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
                                    .cuMemAllocManaged = cuMemAllocManagedFn,
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

    // 2. Try Vulkan Compute Hardware Driver
    if (vulkan.initVulkanDriver() and vulkan.vk_device_count > 0) {
        active_backend = .vulkan;
        detected_lib_path = "libvulkan.so.1";
        return;
    }

    // 3. Try OpenCL Heterogeneous Driver
    if (opencl.initOpenCLDriver() and opencl.cl_device_count > 0) {
        active_backend = .opencl;
        detected_lib_path = "libOpenCL.so.1";
        return;
    }

    // 4. Fallback to CPU Multi-Core Engine
    active_backend = .cpu_multicore;
}

pub fn get_backend() anyerror!Dynamic {
    return switch (active_backend) {
        .cuda => Dynamic.initStr("cuda"),
        .vulkan => Dynamic.initStr("vulkan"),
        .opencl => Dynamic.initStr("opencl"),
        .cpu_multicore => Dynamic.initStr("cpu_multicore"),
        .none => Dynamic.initStr("none"),
    };
}

pub fn set_backend(backend_dyn: Dynamic) anyerror!Dynamic {
    if (backend_dyn.value != .str_type) return error.TypeError;
    const b = backend_dyn.value.str_type;
    if (std.mem.eql(u8, b, "cuda")) {
        if (cuda_api != null) { active_backend = .cuda; return Dynamic.initBool(true); }
    } else if (std.mem.eql(u8, b, "vulkan")) {
        if (vulkan.initVulkanDriver()) { active_backend = .vulkan; return Dynamic.initBool(true); }
    } else if (std.mem.eql(u8, b, "opencl")) {
        if (opencl.initOpenCLDriver()) { active_backend = .opencl; return Dynamic.initBool(true); }
    } else if (std.mem.eql(u8, b, "cpu") or std.mem.eql(u8, b, "cpu_multicore")) {
        active_backend = .cpu_multicore;
        return Dynamic.initBool(true);
    }
    return Dynamic.initBool(false);
}

pub fn get_device_name() anyerror!Dynamic {
    if (active_backend == .cuda and cuda_device_name_len > 0) {
        return Dynamic.initStr(cuda_device_name[0..cuda_device_name_len]);
    } else if (active_backend == .vulkan) {
        return vulkan.get_vulkan_device_name();
    } else if (active_backend == .opencl) {
        return opencl.get_opencl_device_name();
    }
    return Dynamic.initStr("CPU (Multi-Core SIMD Engine)");
}

pub fn get_device_count() anyerror!Dynamic {
    if (active_backend == .cuda and cuda_api != null) {
        var count: c_int = 0;
        if (cuda_api.?.cuDeviceGetCount(&count) == CUDA_SUCCESS) {
            return Dynamic.initInt(@intCast(count));
        }
    } else if (active_backend == .vulkan) {
        return vulkan.get_vulkan_device_count();
    } else if (active_backend == .opencl) {
        return opencl.get_opencl_device_count();
    }
    const cpu_count = std.Thread.getCpuCount() catch 1;
    return Dynamic.initInt(@intCast(cpu_count));
}

pub fn get_lib_path() anyerror!Dynamic {
    return Dynamic.initStr(detected_lib_path);
}
