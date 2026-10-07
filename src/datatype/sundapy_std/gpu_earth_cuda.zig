const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;
const gpu_types = @import("datatype/gpu_types.zig");
const GpuBuffer = gpu_types.GpuBuffer;
const driver = @import("gpu_driver.zig");
const ptx = @import("gpu_earth_ptx.zig");

// ============================================================================
// CUDA GPU Earth Renderer: Launches PTX kernel on NVIDIA hardware
// Textures: NASA Blue Marble (day), Black Marble (night), cloud deck
// ============================================================================

const BLOCK_DIM: u32 = 16;
const TEXTURE_W: usize = 512;
const TEXTURE_H: usize = 256;
const DAY_SIZE: usize = TEXTURE_W * TEXTURE_H * 3;   // 393216 bytes
const NIGHT_SIZE: usize = TEXTURE_W * TEXTURE_H * 3; // 393216 bytes
const CLOUD_SIZE: usize = TEXTURE_W * TEXTURE_H;     // 131072 bytes
const TOTAL_TEX: usize = DAY_SIZE + NIGHT_SIZE + CLOUD_SIZE; // 917504 bytes

// Embedded PTX (null-terminated at compile time)
const EARTH_PTX = ptx.EARTH_PTX;

// Module/function state (initialized once, reused per frame)
var cuda_module: driver.CUmodule = null;
var cuda_earth_fn: driver.CUfunction = null;
var dev_tex_ptr: driver.CUdeviceptr = 0;
var dev_out_ptr: driver.CUdeviceptr = 0;
var current_out_bytes: usize = 0;
var is_initialized: bool = false;
var init_failed: bool = false;

// Texture data buffer (read from disk once)
var tex_buf: [TOTAL_TEX]u8 = undefined;
var tex_loaded: bool = false;

fn loadTexBytes() bool {
    if (tex_loaded) return true;
    const paths = [_][*:0]const u8{
        "assets/earth/earth_packed_512x256.bin",
        "/home/encu/myCode/zigCode/pythonZigZag/assets/earth/earth_packed_512x256.bin",
    };
    for (paths) |p| {
        const rc = std.os.linux.open(p, .{ .ACCMODE = .RDONLY }, 0);
        const fd: i32 = @bitCast(@as(u32, @truncate(rc)));
        if (fd >= 0) {
            defer _ = std.os.linux.close(fd);
            var total: usize = 0;
            while (total < TOTAL_TEX) {
                const n = std.os.linux.read(fd, tex_buf[total..].ptr, TOTAL_TEX - total);
                const sn: isize = @bitCast(n);
                if (sn <= 0) break;
                total += @intCast(sn);
            }
            if (total == TOTAL_TEX) {
                tex_loaded = true;
                return true;
            }
        }
    }
    return false;
}

fn tryInit(api: driver.CudaApi, out_w: u32, out_h: u32) bool {
    // Load PTX module (JIT-compiled by libnvidia-ptxjitcompiler)
    var mod: driver.CUmodule = null;
    const rc_mod = api.cuModuleLoadData(&mod, @ptrCast(EARTH_PTX.ptr));
    if (rc_mod != driver.CUDA_SUCCESS or mod == null) return false;

    // Resolve kernel function
    var fn_h: driver.CUfunction = null;
    const rc_fn = api.cuModuleGetFunction(&fn_h, mod, "earth_kernel");
    if (rc_fn != driver.CUDA_SUCCESS or fn_h == null) return false;

    cuda_module = mod;
    cuda_earth_fn = fn_h;

    // Upload texture atlas to GPU VRAM
    _ = loadTexBytes();
    var dev_tex: driver.CUdeviceptr = 0;
    const rc_tex = api.cuMemAlloc(&dev_tex, TOTAL_TEX);
    if (rc_tex == driver.CUDA_SUCCESS and dev_tex != 0) {
        if (tex_loaded) {
            _ = api.cuMemcpyHtoD(dev_tex, &tex_buf, TOTAL_TEX);
        }
        dev_tex_ptr = dev_tex;
    }

    // Allocate output framebuffer on GPU (32-bit BGRA = 4 bytes/pixel)
    const out_bytes = @as(usize, out_w) * @as(usize, out_h) * 4;
    var dev_out: driver.CUdeviceptr = 0;
    _ = api.cuMemAlloc(&dev_out, out_bytes);
    dev_out_ptr = dev_out;
    current_out_bytes = out_bytes;

    return true;
}

/// Launch CUDA earth kernel on NVIDIA GPU hardware.
/// Returns true if kernel launched successfully.
/// Falls back to CPU automatically on failure.
pub fn launchCudaEarth(
    buf: *GpuBuffer,
    w: u32,
    h: u32,
    t: f32,
    cam_dist: f32,
    cam_lat: f32,
    cam_lon: f32,
) bool {
    if (init_failed) return false;
    const api = driver.cuda_api orelse return false;

    if (!is_initialized) {
        if (tryInit(api, w, h)) {
            is_initialized = true;
        } else {
            init_failed = true;
            return false;
        }
    }

    // Resize device output buffer if resolution changed (4 bytes/pixel)
    const out_bytes = @as(usize, w) * @as(usize, h) * 4;
    if (out_bytes != current_out_bytes) {
        if (dev_out_ptr != 0) _ = api.cuMemFree(dev_out_ptr);
        var dev_out: driver.CUdeviceptr = 0;
        _ = api.cuMemAlloc(&dev_out, out_bytes);
        dev_out_ptr = dev_out;
        current_out_bytes = out_bytes;
    }

    if (dev_out_ptr == 0 or cuda_earth_fn == null) return false;

    // Kernel launch grid: ceil(w/16) x ceil(h/16) blocks of 16x16 threads
    const grid_x: u32 = (w + BLOCK_DIM - 1) / BLOCK_DIM;
    const grid_y: u32 = (h + BLOCK_DIM - 1) / BLOCK_DIM;

    // Kernel parameters (each param passed as pointer to scalar)
    var p_out: u64 = dev_out_ptr;
    var p_w: u32 = w;
    var p_h: u32 = h;
    var p_t: f32 = t;
    var p_cd: f32 = cam_dist;
    var p_clat: f32 = cam_lat;
    var p_clon: f32 = cam_lon;
    var p_tex: u64 = dev_tex_ptr;

    var params = [8]?*anyopaque{
        @ptrCast(&p_out),
        @ptrCast(&p_w),
        @ptrCast(&p_h),
        @ptrCast(&p_t),
        @ptrCast(&p_cd),
        @ptrCast(&p_clat),
        @ptrCast(&p_clon),
        @ptrCast(&p_tex),
    };

    // Launch kernel on GPU hardware
    const rc = api.cuLaunchKernel(
        cuda_earth_fn.?,
        grid_x, grid_y, 1,       // grid dims
        BLOCK_DIM, BLOCK_DIM, 1, // block dims: 16x16=256 threads/block
        0, null,                  // shared mem, stream
        @ptrCast(&params),        // kernel args
        null,                     // extra
    );

    if (rc != driver.CUDA_SUCCESS) return false;

    // Wait for GPU kernel to complete
    _ = api.cuCtxSynchronize();

    // DtoH: direct DMA copy of GPU output 32-bit words into buffer (zero CPU math)
    const raw = std.mem.sliceAsBytes(buf.data);
    if (raw.len >= out_bytes) {
        _ = api.cuMemcpyDtoH(raw.ptr, dev_out_ptr, out_bytes);
    }

    return true;
}
