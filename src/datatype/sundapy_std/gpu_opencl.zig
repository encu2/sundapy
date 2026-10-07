const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

extern "c" fn dlopen(filename: ?[*:0]const u8, flag: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;

const RTLD_NOW: c_int = 2;

// ============================================================================
// OpenCL C-ABI Types & Constants
// ============================================================================

pub const cl_int = c_int;
pub const CL_SUCCESS: cl_int = 0;
pub const cl_platform_id = ?*anyopaque;
pub const cl_device_id = ?*anyopaque;
pub const cl_device_type = u64;

pub const CL_DEVICE_TYPE_DEFAULT: cl_device_type = (1 << 0);
pub const CL_DEVICE_TYPE_CPU: cl_device_type = (1 << 1);
pub const CL_DEVICE_TYPE_GPU: cl_device_type = (1 << 2);
pub const CL_DEVICE_TYPE_ACCELERATOR: cl_device_type = (1 << 3);
pub const CL_DEVICE_TYPE_ALL: cl_device_type = 0xFFFFFFFF;

pub const CL_PLATFORM_NAME: u32 = 0x0902;
pub const CL_PLATFORM_VENDOR: u32 = 0x0903;
pub const CL_PLATFORM_VERSION: u32 = 0x0901;

pub const CL_DEVICE_NAME: u32 = 0x102B;
pub const CL_DEVICE_VENDOR: u32 = 0x102C;
pub const CL_DEVICE_TYPE: u32 = 0x1000;
pub const CL_DEVICE_MAX_COMPUTE_UNITS: u32 = 0x1002;
pub const CL_DEVICE_GLOBAL_MEM_SIZE: u32 = 0x101F;

// ============================================================================
// OpenCL Driver State
// ============================================================================

pub var cl_handle: ?*anyopaque = null;
pub var is_opencl_initialized: bool = false;
pub var cl_platform_name: [256]u8 = [_]u8{0} ** 256;
pub var cl_platform_name_len: usize = 0;
pub var cl_device_name: [256]u8 = [_]u8{0} ** 256;
pub var cl_device_name_len: usize = 0;
pub var cl_compute_units: u32 = 0;
pub var cl_device_count: u32 = 0;

var clGetPlatformIDsFn: ?*const fn (u32, ?[*]cl_platform_id, *u32) callconv(.c) cl_int = null;
var clGetPlatformInfoFn: ?*const fn (cl_platform_id, u32, usize, ?*anyopaque, ?*usize) callconv(.c) cl_int = null;
var clGetDeviceIDsFn: ?*const fn (cl_platform_id, cl_device_type, u32, ?[*]cl_device_id, *u32) callconv(.c) cl_int = null;
var clGetDeviceInfoFn: ?*const fn (cl_device_id, u32, usize, ?*anyopaque, ?*usize) callconv(.c) cl_int = null;

const OPENCL_LIB_PATHS = [_][*:0]const u8{
    "/usr/lib/libOpenCL.so.1",
    "/usr/lib/libOpenCL.so",
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so.1",
    "/usr/lib/x86_64-linux-gnu/libOpenCL.so",
    "/usr/lib64/libOpenCL.so.1",
    "/usr/lib64/libOpenCL.so",
    "libOpenCL.so.1",
    "libOpenCL.so",
};

pub fn initOpenCLDriver() bool {
    if (is_opencl_initialized) return cl_handle != null;
    is_opencl_initialized = true;

    for (OPENCL_LIB_PATHS) |path| {
        const h = dlopen(path, RTLD_NOW);
        if (h) |handle| {
            const getPlatforms = dlsym(handle, "clGetPlatformIDs");
            const getPlatInfo = dlsym(handle, "clGetPlatformInfo");
            const getDevices = dlsym(handle, "clGetDeviceIDs");
            const getDevInfo = dlsym(handle, "clGetDeviceInfo");

            if (getPlatforms != null and getPlatInfo != null and getDevices != null and getDevInfo != null) {
                clGetPlatformIDsFn = @ptrCast(getPlatforms);
                clGetPlatformInfoFn = @ptrCast(getPlatInfo);
                clGetDeviceIDsFn = @ptrCast(getDevices);
                clGetDeviceInfoFn = @ptrCast(getDevInfo);

                var num_platforms: u32 = 0;
                if (clGetPlatformIDsFn.?(0, null, &num_platforms) == CL_SUCCESS and num_platforms > 0) {
                    var platforms: [8]cl_platform_id = undefined;
                    const fetch_plat = @min(num_platforms, 8);
                    if (clGetPlatformIDsFn.?(fetch_plat, &platforms, &num_platforms) == CL_SUCCESS) {
                        cl_handle = handle;

                        // Query primary platform info
                        var size_ret: usize = 0;
                        _ = clGetPlatformInfoFn.?(platforms[0], CL_PLATFORM_NAME, 255, &cl_platform_name, &size_ret);
                        cl_platform_name_len = std.mem.indexOfScalar(u8, &cl_platform_name, 0) orelse @min(size_ret, 255);

                        // Query devices on primary platform
                        var num_devices: u32 = 0;
                        if (clGetDeviceIDsFn.?(platforms[0], CL_DEVICE_TYPE_ALL, 0, null, &num_devices) == CL_SUCCESS and num_devices > 0) {
                            cl_device_count = num_devices;
                            var devices: [16]cl_device_id = undefined;
                            const fetch_dev = @min(num_devices, 16);
                            if (clGetDeviceIDsFn.?(platforms[0], CL_DEVICE_TYPE_ALL, fetch_dev, &devices, &num_devices) == CL_SUCCESS) {
                                _ = clGetDeviceInfoFn.?(devices[0], CL_DEVICE_NAME, 255, &cl_device_name, &size_ret);
                                cl_device_name_len = std.mem.indexOfScalar(u8, &cl_device_name, 0) orelse @min(size_ret, 255);

                                var cus: u32 = 0;
                                if (clGetDeviceInfoFn.?(devices[0], CL_DEVICE_MAX_COMPUTE_UNITS, @sizeOf(u32), &cus, null) == CL_SUCCESS) {
                                    cl_compute_units = cus;
                                }
                            }
                        }
                        return true;
                    }
                }
            }
            _ = dlclose(handle);
        }
    }
    return false;
}

pub fn get_opencl_platform_name() anyerror!Dynamic {
    _ = initOpenCLDriver();
    if (cl_platform_name_len > 0) {
        return Dynamic.initStr(cl_platform_name[0..cl_platform_name_len]);
    }
    return Dynamic.initStr("OpenCL Platform Unavailable");
}

pub fn get_opencl_device_name() anyerror!Dynamic {
    _ = initOpenCLDriver();
    if (cl_device_name_len > 0) {
        return Dynamic.initStr(cl_device_name[0..cl_device_name_len]);
    }
    return Dynamic.initStr("OpenCL Device Unavailable");
}

pub fn get_opencl_device_count() anyerror!Dynamic {
    _ = initOpenCLDriver();
    return Dynamic.initInt(@intCast(cl_device_count));
}

pub fn get_opencl_compute_units() anyerror!Dynamic {
    _ = initOpenCLDriver();
    return Dynamic.initInt(@intCast(cl_compute_units));
}

pub fn is_opencl_available() anyerror!Dynamic {
    return Dynamic.initBool(initOpenCLDriver());
}
