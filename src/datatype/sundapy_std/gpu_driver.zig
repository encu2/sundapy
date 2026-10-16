const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");

pub const core = @import("gpu_driver_core.zig");
pub const cuda = @import("gpu_driver_cuda.zig");
pub const vmm = @import("gpu_driver_vmm.zig");
pub const vulkan = @import("gpu_vulkan.zig");
pub const opencl = @import("gpu_opencl.zig");

// Re-exports from core
pub const dlopen = core.dlopen_fn;
pub const dlsym = core.dlsym_fn;
pub const dlclose = core.dlclose_fn;
pub const dlerror = core.dlerror_fn;
pub const RTLD_NOW = core.RTLD_NOW;
pub const RTLD_GLOBAL = core.RTLD_GLOBAL;
pub const DISTRO_CUDA_PATHS = core.DISTRO_CUDA_PATHS;
pub const DISTRO_VULKAN_PATHS = core.DISTRO_VULKAN_PATHS;
pub const DISTRO_OPENCL_PATHS = core.DISTRO_OPENCL_PATHS;
pub const CUresult = core.CUresult;
pub const CUDA_SUCCESS = core.CUDA_SUCCESS;
pub const CUdevice = core.CUdevice;
pub const CUcontext = core.CUcontext;
pub const CUmodule = core.CUmodule;
pub const CUfunction = core.CUfunction;
pub const CUstream = core.CUstream;
pub const CUdeviceptr = core.CUdeviceptr;
pub const BackendType = core.BackendType;
pub var active_backend: BackendType = .none;
pub var is_driver_initialized: bool = false;
pub var cuda_device: CUdevice = 0;
pub var cuda_context: CUcontext = null;
pub var cuda_device_name: [256]u8 = [_]u8{0} ** 256;
pub var cuda_device_name_len: usize = 0;
pub var detected_lib_path: []const u8 = "";

pub const loadSymbol = core.loadSymbol;
pub const get_backend = core.get_backend;
pub const get_lib_path = core.get_lib_path;

// Re-exports from cuda
pub const CudaApi = cuda.CudaApi;
pub var cuda_api: ?CudaApi = null;
pub const syncBufferToDevice = cuda.syncBufferToDevice;
pub const syncBufferToHost = cuda.syncBufferToHost;
pub const syncBufferItemSet = cuda.syncBufferItemSet;
pub const syncCuda = cuda.syncCuda;
pub const freeCudaDevicePtr = cuda.freeCudaDevicePtr;
pub const allocPinnedHost = cuda.allocPinnedHost;
pub const freePinnedHost = cuda.freePinnedHost;

// Re-exports from vmm
pub const isVmmSupported = vmm.isVmmSupported;
pub fn getVmmGranularity() usize { return vmm.vmm_granularity; }
pub const reserveVirtualAddress = vmm.reserveVirtualAddress;
pub const freeVirtualAddress = vmm.freeVirtualAddress;
pub const createPhysicalAllocation = vmm.createPhysicalAllocation;
pub const releasePhysicalAllocation = vmm.releasePhysicalAllocation;
pub const mapVirtualPage = vmm.mapVirtualPage;
pub const unmapVirtualPage = vmm.unmapVirtualPage;
pub const setVirtualPageAccess = vmm.setVirtualPageAccess;

pub const copyBuffer = cuda.copyBuffer;

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
    gpu_types.buffer_pinned_alloc_fn = allocPinnedHost;
    gpu_types.buffer_pinned_free_fn = freePinnedHost;
    gpu_types.buffer_copy_fn = copyBuffer;

    // 1. Try CUDA Driver API across distro paths
    if (cuda.initCudaDriver()) {
        active_backend = .cuda;
        cuda_api = cuda.cuda_api;
        cuda_device = core.cuda_device;
        cuda_context = core.cuda_context;
        cuda_device_name = core.cuda_device_name;
        cuda_device_name_len = core.cuda_device_name_len;
        detected_lib_path = core.detected_lib_path;
        return;
    }

    // 2. Try Vulkan Compute Hardware Driver
    if (vulkan.initVulkanDriver() and vulkan.vk_device_count > 0) {
        active_backend = .vulkan;
        detected_lib_path = "libvulkan.so.1";
        core.active_backend = .vulkan;
        core.detected_lib_path = detected_lib_path;
        return;
    }

    // 3. Try OpenCL Heterogeneous Driver
    if (opencl.initOpenCLDriver() and opencl.cl_device_count > 0) {
        active_backend = .opencl;
        detected_lib_path = "libOpenCL.so.1";
        core.active_backend = .opencl;
        core.detected_lib_path = detected_lib_path;
        return;
    }

    // 4. Fallback to CPU Multi-Core Engine
    active_backend = .cpu_multicore;
    core.active_backend = .cpu_multicore;
}

pub fn set_backend(backend_dyn: Dynamic) anyerror!Dynamic {
    if (backend_dyn.value != .str_type) return error.TypeError;
    const b = backend_dyn.value.str_type;
    if (std.mem.eql(u8, b, "cuda")) {
        if (cuda_api != null) {
            active_backend = .cuda;
            core.active_backend = .cuda;
            return Dynamic.initBool(true);
        }
    } else if (std.mem.eql(u8, b, "vulkan")) {
        if (vulkan.initVulkanDriver()) {
            active_backend = .vulkan;
            core.active_backend = .vulkan;
            return Dynamic.initBool(true);
        }
    } else if (std.mem.eql(u8, b, "opencl")) {
        if (opencl.initOpenCLDriver()) {
            active_backend = .opencl;
            core.active_backend = .opencl;
            return Dynamic.initBool(true);
        }
    } else if (std.mem.eql(u8, b, "cpu") or std.mem.eql(u8, b, "cpu_multicore")) {
        active_backend = .cpu_multicore;
        core.active_backend = .cpu_multicore;
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
