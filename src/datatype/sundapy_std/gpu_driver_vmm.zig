const std = @import("std");
const core = @import("gpu_driver_core.zig");
const CUresult = core.CUresult;
const CUDA_SUCCESS = core.CUDA_SUCCESS;
const CUdeviceptr = core.CUdeviceptr;
const loadSymbol = core.loadSymbol;

// ============================================================================
// CUDA Hardware Virtual Memory Management (VMM) Types & API
// ============================================================================

pub const CUmemGenericAllocationHandle = u64;

pub const CUmemAllocationType = enum(c_int) {
    invalid = 0,
    pinned = 1,
};

pub const CUmemAllocationHandleType = enum(c_int) {
    none = 0,
    posix_file_descriptor = 1,
    win32 = 2,
    win32_kmt = 4,
};

pub const CUmemLocationType = enum(c_int) {
    invalid = 0,
    device = 1,
    host = 2,
    host_numa = 3,
    device_locality_domain = 4,
};

pub const CUmemLocation = extern struct {
    type: CUmemLocationType = .device,
    id: c_int = 0,
};

pub const CUmemAllocationProp = extern struct {
    type: CUmemAllocationType = .pinned,
    requestedHandleTypes: CUmemAllocationHandleType = .none,
    location: CUmemLocation = .{},
    win32HandleMetaData: ?*anyopaque = null,
    allocFlags: extern struct {
        compressionType: c_ushort = 0,
        gpuDirectRDMACapable: c_ushort = 0,
        usage: c_ushort = 0,
        reserved: [4]u8 = [_]u8{0} ** 4,
    } = .{},
};

pub const CUmemAccess_flags = enum(c_int) {
    prot_none = 0,
    prot_read = 1,
    prot_readwrite = 3,
};

pub const CUmemAccessDesc = extern struct {
    location: CUmemLocation = .{},
    flags: CUmemAccess_flags = .prot_readwrite,
};

pub const CUmemAllocationGranularity_flags = enum(c_int) {
    minimum = 0,
    recommended = 1,
};

pub const CudaVmmApi = struct {
    cuMemAddressReserve: *const fn (*CUdeviceptr, usize, usize, CUdeviceptr, c_ulonglong) callconv(.c) CUresult,
    cuMemAddressFree: *const fn (CUdeviceptr, usize) callconv(.c) CUresult,
    cuMemCreate: *const fn (*CUmemGenericAllocationHandle, usize, *const CUmemAllocationProp, c_ulonglong) callconv(.c) CUresult,
    cuMemRelease: *const fn (CUmemGenericAllocationHandle) callconv(.c) CUresult,
    cuMemMap: *const fn (CUdeviceptr, usize, usize, CUmemGenericAllocationHandle, c_ulonglong) callconv(.c) CUresult,
    cuMemUnmap: *const fn (CUdeviceptr, usize) callconv(.c) CUresult,
    cuMemSetAccess: *const fn (CUdeviceptr, usize, *const CUmemAccessDesc, usize) callconv(.c) CUresult,
    cuMemGetAllocationGranularity: *const fn (*usize, *const CUmemAllocationProp, CUmemAllocationGranularity_flags) callconv(.c) CUresult,
};

pub var vmm_api: ?CudaVmmApi = null;
pub var vmm_granularity: usize = 0;

pub fn initVmmApi(handle: *anyopaque, dev_id: c_int) bool {
    const reserveFn = loadSymbol(handle, *const fn (*CUdeviceptr, usize, usize, CUdeviceptr, c_ulonglong) callconv(.c) CUresult, "cuMemAddressReserve");
    const freeVaFn = loadSymbol(handle, *const fn (CUdeviceptr, usize) callconv(.c) CUresult, "cuMemAddressFree");
    const createFn = loadSymbol(handle, *const fn (*CUmemGenericAllocationHandle, usize, *const CUmemAllocationProp, c_ulonglong) callconv(.c) CUresult, "cuMemCreate");
    const releaseFn = loadSymbol(handle, *const fn (CUmemGenericAllocationHandle) callconv(.c) CUresult, "cuMemRelease");
    const mapFn = loadSymbol(handle, *const fn (CUdeviceptr, usize, usize, CUmemGenericAllocationHandle, c_ulonglong) callconv(.c) CUresult, "cuMemMap");
    const unmapFn = loadSymbol(handle, *const fn (CUdeviceptr, usize) callconv(.c) CUresult, "cuMemUnmap");
    const setAccessFn = loadSymbol(handle, *const fn (CUdeviceptr, usize, *const CUmemAccessDesc, usize) callconv(.c) CUresult, "cuMemSetAccess");
    const granFn = loadSymbol(handle, *const fn (*usize, *const CUmemAllocationProp, CUmemAllocationGranularity_flags) callconv(.c) CUresult, "cuMemGetAllocationGranularity");

    if (reserveFn != null and freeVaFn != null and createFn != null and releaseFn != null and mapFn != null and unmapFn != null and setAccessFn != null and granFn != null) {
        vmm_api = CudaVmmApi{
            .cuMemAddressReserve = reserveFn.?,
            .cuMemAddressFree = freeVaFn.?,
            .cuMemCreate = createFn.?,
            .cuMemRelease = releaseFn.?,
            .cuMemMap = mapFn.?,
            .cuMemUnmap = unmapFn.?,
            .cuMemSetAccess = setAccessFn.?,
            .cuMemGetAllocationGranularity = granFn.?,
        };

        var prop = CUmemAllocationProp{
            .type = .pinned,
            .location = .{ .type = .device, .id = dev_id },
        };
        var gran: usize = 0;
        if (vmm_api.?.cuMemGetAllocationGranularity(&gran, &prop, .minimum) == CUDA_SUCCESS and gran > 0) {
            vmm_granularity = gran;
        } else {
            vmm_granularity = 2 * 1024 * 1024; // 2MB fallback
        }
        return true;
    }
    return false;
}

pub fn isVmmSupported() bool {
    return vmm_api != null;
}

pub fn reserveVirtualAddress(size: usize, alignment: usize) !CUdeviceptr {
    if (vmm_api) |api| {
        var dptr: CUdeviceptr = 0;
        const align_val = if (alignment == 0) vmm_granularity else alignment;
        const res = api.cuMemAddressReserve(&dptr, size, align_val, 0, 0);
        if (res == CUDA_SUCCESS and dptr != 0) return dptr;
    }
    return error.GpuVirtualAddressReserveFailed;
}

pub fn freeVirtualAddress(va_ptr: CUdeviceptr, size: usize) void {
    if (vmm_api) |api| {
        if (va_ptr != 0 and size > 0) {
            _ = api.cuMemAddressFree(va_ptr, size);
        }
    }
}

pub fn createPhysicalAllocation(size: usize, device_id: c_int) !CUmemGenericAllocationHandle {
    if (vmm_api) |api| {
        var prop = CUmemAllocationProp{
            .type = .pinned,
            .location = .{ .type = .device, .id = device_id },
        };
        var handle: CUmemGenericAllocationHandle = 0;
        const res = api.cuMemCreate(&handle, size, &prop, 0);
        if (res == CUDA_SUCCESS and handle != 0) return handle;
    }
    return error.GpuPhysicalAllocationFailed;
}

pub fn releasePhysicalAllocation(handle: CUmemGenericAllocationHandle) void {
    if (vmm_api) |api| {
        if (handle != 0) {
            _ = api.cuMemRelease(handle);
        }
    }
}

pub fn mapVirtualPage(va_ptr: CUdeviceptr, size: usize, offset: usize, handle: CUmemGenericAllocationHandle) !void {
    if (vmm_api) |api| {
        const res = api.cuMemMap(va_ptr + offset, size, 0, handle, 0);
        if (res != CUDA_SUCCESS) return error.GpuMemMapFailed;
        return;
    }
    return error.GpuVmmNotAvailable;
}

pub fn unmapVirtualPage(va_ptr: CUdeviceptr, size: usize) void {
    if (vmm_api) |api| {
        if (va_ptr != 0 and size > 0) {
            _ = api.cuMemUnmap(va_ptr, size);
        }
    }
}

pub fn setVirtualPageAccess(va_ptr: CUdeviceptr, size: usize, device_id: c_int) !void {
    if (vmm_api) |api| {
        const desc = CUmemAccessDesc{
            .location = .{ .type = .device, .id = device_id },
            .flags = .prot_readwrite,
        };
        const res = api.cuMemSetAccess(va_ptr, size, &desc, 1);
        if (res != CUDA_SUCCESS) return error.GpuMemSetAccessFailed;
        return;
    }
    return error.GpuVmmNotAvailable;
}
