const std = @import("std");
const core = @import("gpu_driver_core.zig");
const vmm = @import("gpu_driver_vmm.zig");
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;

const CUresult = core.CUresult;
const CUDA_SUCCESS = core.CUDA_SUCCESS;
const CUdevice = core.CUdevice;
const CUcontext = core.CUcontext;
const CUmodule = core.CUmodule;
const CUfunction = core.CUfunction;
const CUstream = core.CUstream;
const CUdeviceptr = core.CUdeviceptr;
const loadSymbol = core.loadSymbol;

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
    cuMemcpyDtoD: ?*const fn (CUdeviceptr, CUdeviceptr, usize) callconv(.c) CUresult = null,
    cuModuleLoadData: *const fn (*CUmodule, ?*const anyopaque) callconv(.c) CUresult,
    cuModuleGetFunction: *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult,
    cuLaunchKernel: *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, CUstream, ?*?*anyopaque, ?*?*anyopaque) callconv(.c) CUresult,

    // Pinned Host Memory APIs
    cuMemHostAlloc: ?*const fn (*?*anyopaque, usize, c_uint) callconv(.c) CUresult = null,
    cuMemFreeHost: ?*const fn (?*anyopaque) callconv(.c) CUresult = null,
    cuMemHostGetDevicePointer: ?*const fn (*CUdeviceptr, ?*anyopaque, c_uint) callconv(.c) CUresult = null,

    // CUDA Graph APIs
    cuGraphCreate: ?*const fn (*?*anyopaque, c_uint) callconv(.c) CUresult = null,
    cuGraphDestroy: ?*const fn (?*anyopaque) callconv(.c) CUresult = null,
    cuGraphAddKernelNode: ?*const fn (*?*anyopaque, ?*anyopaque, ?[*]const ?*anyopaque, usize, ?*const anyopaque) callconv(.c) CUresult = null,
    cuGraphAddDependencies: ?*const fn (?*anyopaque, [*]const ?*anyopaque, [*]const ?*anyopaque, usize) callconv(.c) CUresult = null,
    cuGraphInstantiateWithFlags: ?*const fn (*?*anyopaque, ?*anyopaque, c_ulonglong) callconv(.c) CUresult = null,
    cuGraphLaunch: ?*const fn (?*anyopaque, CUstream) callconv(.c) CUresult = null,
    cuGraphExecDestroy: ?*const fn (?*anyopaque) callconv(.c) CUresult = null,
};

pub var cuda_api: ?CudaApi = null;

pub fn syncBufferToDevice(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * buf.dtype.sizeOf();
        _ = cuda_api.?.cuMemcpyHtoD(buf.dev_ptr, buf.data.ptr, byte_len);
    }
}

pub fn syncBufferToHost(buf: *GpuBuffer) void {
    if (buf.is_device_allocated and cuda_api != null and buf.dev_ptr != 0) {
        const byte_len = buf.size * buf.dtype.sizeOf();
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

pub fn allocPinnedHost(bytes: usize) gpu_types.PinnedAllocResult {
    if (cuda_api) |api| {
        if (api.cuMemHostAlloc) |hostAllocFn| {
            var raw: ?*anyopaque = null;
            // Flags: CU_MEMHOSTALLOC_DEVICEMAP = 0x02
            if (hostAllocFn(&raw, bytes, 0x02) == CUDA_SUCCESS and raw != null) {
                var dptr: CUdeviceptr = 0;
                if (api.cuMemHostGetDevicePointer) |getDevPtrFn| {
                    if (getDevPtrFn(&dptr, raw.?, 0) == CUDA_SUCCESS) {
                        return .{ .host_ptr = @ptrCast(raw.?), .dev_ptr = dptr };
                    }
                }
                return .{ .host_ptr = @ptrCast(raw.?), .dev_ptr = 0 };
            }
        }
    }
    return .{};
}

pub fn copyBuffer(dst: *GpuBuffer, src: *GpuBuffer) bool {
    if (cuda_api) |api| {
        const copy_bytes = @min(dst.size * dst.dtype.sizeOf(), src.size * src.dtype.sizeOf());
        if (copy_bytes == 0) return true;

        if (dst.dev_ptr != 0 and src.dev_ptr != 0) {
            if (api.cuMemcpyDtoD) |dtoDFn| {
                if (dtoDFn(dst.dev_ptr, src.dev_ptr, copy_bytes) == CUDA_SUCCESS) return true;
            }
        }
        if (dst.dev_ptr != 0 and src.data.len > 0) {
            if (api.cuMemcpyHtoD(dst.dev_ptr, src.data.ptr, copy_bytes) == CUDA_SUCCESS) return true;
        }
        if (src.dev_ptr != 0 and dst.data.len > 0) {
            if (api.cuMemcpyDtoH(dst.data.ptr, src.dev_ptr, copy_bytes) == CUDA_SUCCESS) return true;
        }
    }
    const byte_len = @min(dst.data.len * @sizeOf(f32), src.data.len * @sizeOf(f32));
    if (byte_len > 0) {
        @memcpy(@as([*]u8, @ptrCast(dst.data.ptr))[0..byte_len], @as([*]const u8, @ptrCast(src.data.ptr))[0..byte_len]);
        return true;
    }
    return false;
}

pub fn freePinnedHost(ptr: ?*anyopaque) void {
    if (cuda_api) |api| {
        if (api.cuMemFreeHost) |freeHostFn| {
            if (ptr != null) {
                _ = freeHostFn(ptr);
            }
        }
    }
}

pub fn initCudaDriver() bool {
    // Preload PTX JIT compiler globally
    const ptxjit_paths = [_][*:0]const u8{
        "/usr/lib/libnvidia-ptxjitcompiler.so.1",
        "/usr/lib/x86_64-linux-gnu/libnvidia-ptxjitcompiler.so.1",
        "/usr/lib64/libnvidia-ptxjitcompiler.so.1",
        "libnvidia-ptxjitcompiler.so.1",
    };
    for (ptxjit_paths) |p| {
        const h = core.dlopen_fn(p, core.RTLD_NOW | core.RTLD_GLOBAL);
        if (h != null) break;
    }

    for (core.DISTRO_CUDA_PATHS) |path| {
        var buf: [512:0]u8 = undefined;
        if (path.len >= 511) continue;
        @memcpy(buf[0..path.len], path);
        buf[path.len] = 0;

        const handle = core.dlopen_fn(&buf, core.RTLD_NOW);
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
            const cuMemcpyDtoDFn = loadSymbol(h, *const fn (CUdeviceptr, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoD_v2") orelse
                loadSymbol(h, *const fn (CUdeviceptr, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoD");
            const cuModuleLoadDataFn = loadSymbol(h, *const fn (*CUmodule, ?*const anyopaque) callconv(.c) CUresult, "cuModuleLoadData");
            const cuModuleGetFunctionFn = loadSymbol(h, *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult, "cuModuleGetFunction");
            const cuLaunchKernelFn = loadSymbol(h, *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, CUstream, ?*?*anyopaque, ?*?*anyopaque) callconv(.c) CUresult, "cuLaunchKernel");

            // Pinned Host Memory APIs
            const cuMemHostAllocFn = loadSymbol(h, *const fn (*?*anyopaque, usize, c_uint) callconv(.c) CUresult, "cuMemHostAlloc");
            const cuMemFreeHostFn = loadSymbol(h, *const fn (?*anyopaque) callconv(.c) CUresult, "cuMemFreeHost");
            const cuMemHostGetDevicePointerFn = loadSymbol(h, *const fn (*CUdeviceptr, ?*anyopaque, c_uint) callconv(.c) CUresult, "cuMemHostGetDevicePointer_v2") orelse
                loadSymbol(h, *const fn (*CUdeviceptr, ?*anyopaque, c_uint) callconv(.c) CUresult, "cuMemHostGetDevicePointer");

            // CUDA Graph APIs
            const cuGraphCreateFn = loadSymbol(h, *const fn (*?*anyopaque, c_uint) callconv(.c) CUresult, "cuGraphCreate");
            const cuGraphDestroyFn = loadSymbol(h, *const fn (?*anyopaque) callconv(.c) CUresult, "cuGraphDestroy");
            const cuGraphAddKernelNodeFn = loadSymbol(h, *const fn (*?*anyopaque, ?*anyopaque, ?[*]const ?*anyopaque, usize, ?*const anyopaque) callconv(.c) CUresult, "cuGraphAddKernelNode");
            const cuGraphAddDependenciesFn = loadSymbol(h, *const fn (?*anyopaque, [*]const ?*anyopaque, [*]const ?*anyopaque, usize) callconv(.c) CUresult, "cuGraphAddDependencies");
            const cuGraphInstantiateWithFlagsFn = loadSymbol(h, *const fn (*?*anyopaque, ?*anyopaque, c_ulonglong) callconv(.c) CUresult, "cuGraphInstantiateWithFlags");
            const cuGraphLaunchFn = loadSymbol(h, *const fn (?*anyopaque, CUstream) callconv(.c) CUresult, "cuGraphLaunch");
            const cuGraphExecDestroyFn = loadSymbol(h, *const fn (?*anyopaque) callconv(.c) CUresult, "cuGraphExecDestroy");

            if (cuInitFn != null and cuDeviceGetCountFn != null and cuDeviceGetFn != null and cuCtxCreateFn != null and cuMemAllocFn != null) {
                if (cuInitFn.?(0) == CUDA_SUCCESS) {
                    var count: c_int = 0;
                    if (cuDeviceGetCountFn.?(&count) == CUDA_SUCCESS and count > 0) {
                        var dev: CUdevice = 0;
                        if (cuDeviceGetFn.?(&dev, 0) == CUDA_SUCCESS) {
                            var ctx: CUcontext = null;
                            if (cuCtxCreateFn.?(&ctx, 0, dev) == CUDA_SUCCESS) {
                                core.cuda_device = dev;
                                core.cuda_context = ctx;
                                core.detected_lib_path = path;

                                if (cuDeviceGetNameFn) |nameFn| {
                                    if (nameFn(&core.cuda_device_name, 255, dev) == CUDA_SUCCESS) {
                                        core.cuda_device_name_len = std.mem.indexOfScalar(u8, &core.cuda_device_name, 0) orelse 255;
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
                                    .cuMemcpyDtoD = cuMemcpyDtoDFn,
                                    .cuModuleLoadData = cuModuleLoadDataFn orelse undefined,
                                    .cuModuleGetFunction = cuModuleGetFunctionFn orelse undefined,
                                    .cuLaunchKernel = cuLaunchKernelFn orelse undefined,
                                    .cuMemHostAlloc = cuMemHostAllocFn,
                                    .cuMemFreeHost = cuMemFreeHostFn,
                                    .cuMemHostGetDevicePointer = cuMemHostGetDevicePointerFn,
                                    .cuGraphCreate = cuGraphCreateFn,
                                    .cuGraphDestroy = cuGraphDestroyFn,
                                    .cuGraphAddKernelNode = cuGraphAddKernelNodeFn,
                                    .cuGraphAddDependencies = cuGraphAddDependenciesFn,
                                    .cuGraphInstantiateWithFlags = cuGraphInstantiateWithFlagsFn,
                                    .cuGraphLaunch = cuGraphLaunchFn,
                                    .cuGraphExecDestroy = cuGraphExecDestroyFn,
                                };

                                _ = vmm.initVmmApi(h, dev);
                                core.active_backend = .cuda;
                                return true;
                            }
                        }
                    }
                }
            }
            _ = core.dlclose_fn(h);
        }
    }
    return false;
}
