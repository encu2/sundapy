const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

extern "c" fn dlopen(filename: ?[*:0]const u8, flag: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;
extern "c" fn dlerror() ?[*:0]const u8;

pub const dlopen_fn = dlopen;
pub const dlsym_fn = dlsym;
pub const dlclose_fn = dlclose;
pub const dlerror_fn = dlerror;

pub const RTLD_NOW: c_int = 2;
pub const RTLD_GLOBAL: c_int = 256;

// ============================================================================
// Multi-Distro Shared Library Discovery
// ============================================================================

pub const DISTRO_CUDA_PATHS = [_][]const u8{
    "/usr/lib/libcuda.so.1",
    "/usr/lib/libcuda.so",
    "/usr/lib/x86_64-linux-gnu/libcuda.so.1",
    "/usr/lib/x86_64-linux-gnu/libcuda.so",
    "/usr/lib64/libcuda.so.1",
    "/usr/lib64/libcuda.so",
    "/lib/libcuda.so.1",
    "/usr/lib/aarch64-linux-gnu/libcuda.so.1",
    "/usr/lib/aarch64-linux-gnu/libcuda.so",
    "/usr/local/cuda/lib64/libcuda.so.1",
    "/usr/local/cuda/lib64/libcuda.so",
    "/opt/cuda/lib64/libcuda.so",
    "/usr/local/cuda-12/lib64/libcuda.so.1",
    "/usr/local/cuda-11/lib64/libcuda.so.1",
    "/usr/X11R6/lib64/libcuda.so.1",
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

pub const BackendType = enum {
    none,
    cpu_multicore,
    cuda,
    vulkan,
    opencl,
};

pub var active_backend: BackendType = .none;
pub var is_driver_initialized: bool = false;
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

pub fn get_backend() anyerror!Dynamic {
    return switch (active_backend) {
        .cuda => Dynamic.initStr("cuda"),
        .vulkan => Dynamic.initStr("vulkan"),
        .opencl => Dynamic.initStr("opencl"),
        .cpu_multicore => Dynamic.initStr("cpu_multicore"),
        .none => Dynamic.initStr("none"),
    };
}

pub fn get_lib_path() anyerror!Dynamic {
    return Dynamic.initStr(detected_lib_path);
}
