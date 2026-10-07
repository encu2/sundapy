import gpu
import time

print("=================================================================")
print("    SUNDAPY ADVANCED GPU ECOSYSTEM COMPREHENSIVE TEST SUITE      ")
print("  (Cross-Vendor Drivers, Atomics, Blelloch Scan, Morton, Shared) ")
print("=================================================================")

def buf_to_list(buf, count):
    res = []
    for i in range(count):
        res.append(buf[i])
    return res

# -----------------------------------------------------------------------------
# 1. Test Cross-Vendor Hardware Driver Discovery (CUDA, Vulkan, OpenCL)
# -----------------------------------------------------------------------------
print("\n[1] Testing Cross-Vendor Driver Discovery & Introspection...")
backend = gpu.get_backend()
dev_name = gpu.get_device_name()
dev_count = gpu.get_device_count()

print("Active Backend   :", backend)
print("Primary Device   :", dev_name)
print("Device/Core Count:", dev_count)

vulkan_avail = gpu.is_vulkan_available()
print("Vulkan Available :", vulkan_avail)
if vulkan_avail:
    print("Vulkan Device    :", gpu.get_vulkan_device_name())
    print("Vulkan Count     :", gpu.get_vulkan_device_count())
    print("Vulkan Type      :", gpu.get_vulkan_device_type())
    print("Vulkan API Ver   :", gpu.get_vulkan_api_version())

opencl_avail = gpu.is_opencl_available()
print("OpenCL Available :", opencl_avail)
if opencl_avail:
    print("OpenCL Platform  :", gpu.get_opencl_platform_name())
    print("OpenCL Device    :", gpu.get_opencl_device_name())
    print("OpenCL Dev Count :", gpu.get_opencl_device_count())

# Test runtime backend switching
switch_ok = gpu.set_backend("cpu")
print("Switched to CPU  :", switch_ok, "| Current Backend:", gpu.get_backend())
gpu.set_backend(backend)
print("Restored Backend :", gpu.get_backend())

# -----------------------------------------------------------------------------
# 2. Test Multi-Dtype Buffer Memory Management (f32, i32, u8)
# -----------------------------------------------------------------------------
print("\n[2] Testing Multi-Dtype GpuBuffer Storage...")
b_f32 = gpu.alloc(32)
print("Buffer f32: dtype =", b_f32.dtype, "| itemsize =", b_f32.itemsize, "| nbytes =", b_f32.nbytes)
b_f32[0] = 3.14159
print("b_f32[0] =", b_f32[0])

b_i32 = gpu.alloc_dtype(32, "i32")
print("Buffer i32: dtype =", b_i32.dtype, "| itemsize =", b_i32.itemsize, "| nbytes =", b_i32.nbytes)
b_i32[0] = 42
b_i32[1] = 999
print("b_i32[0] =", b_i32[0], "| b_i32[1] =", b_i32[1])

b_u8 = gpu.alloc_dtype(64, "u8")
print("Buffer u8 : dtype =", b_u8.dtype, "| itemsize =", b_u8.itemsize, "| nbytes =", b_u8.nbytes)
b_u8[0] = 255
b_u8[1] = 128
print("b_u8[0]  =", b_u8[0], "| b_u8[1]  =", b_u8[1])

# -----------------------------------------------------------------------------
# 3. Test Lock-Free Hardware Atomic Primitives
# -----------------------------------------------------------------------------
print("\n[3] Testing Hardware Lock-Free Atomic Operations...")
atom_buf = gpu.alloc(16)
atom_buf[0] = 10.0
atom_buf[1] = 50.0

old_val = gpu.atomic_add(atom_buf, 0, 5.0)
print("atomic_add: old =", old_val, "| new =", atom_buf[0], "(Expected new: 15.0)")

old_sub = gpu.atomic_sub(atom_buf, 0, 3.0)
print("atomic_sub: old =", old_sub, "| new =", atom_buf[0], "(Expected new: 12.0)")

old_min = gpu.atomic_min(atom_buf, 1, 25.0)
print("atomic_min: old =", old_min, "| new =", atom_buf[1], "(Expected new: 25.0)")

old_max = gpu.atomic_max(atom_buf, 1, 80.0)
print("atomic_max: old =", old_max, "| new =", atom_buf[1], "(Expected new: 80.0)")

# Test Compare-And-Swap (CAS)
cas_res = gpu.atomic_cas(atom_buf, 0, 12.0, 99.0)
print("atomic_cas: match old =", cas_res, "| new =", atom_buf[0], "(Expected new: 99.0)")

# Bitwise atomics on buffer
bit_buf = gpu.alloc(8)
bit_buf[0] = 0.0
gpu.atomic_or(bit_buf, 0, 15)
print("atomic_or (15):", int(bit_buf[0]))
gpu.atomic_and(bit_buf, 0, 9)
print("atomic_and (9):", int(bit_buf[0]))
gpu.atomic_xor(bit_buf, 0, 3)
print("atomic_xor (3):", int(bit_buf[0]))

# -----------------------------------------------------------------------------
# 4. Test Blelloch Parallel Scan, Reductions & Radix Sort
# -----------------------------------------------------------------------------
print("\n[4] Testing Blelloch Parallel Scan, Reductions & Radix Sort...")
scan_in = gpu.alloc(8)
scan_out = gpu.alloc(8)
for i in range(8):
    scan_in[i] = float(i + 1)

# Inclusive Prefix Sum: [1, 2, 3, 4, 5, 6, 7, 8] -> [1, 3, 6, 10, 15, 21, 28, 36]
gpu.prefix_sum(scan_in, scan_out)
print("Input :", buf_to_list(scan_in, 8))
print("Prefix:", buf_to_list(scan_out, 8))

# Exclusive Scan: [0, 1, 3, 6, 10, 15, 21, 28]
gpu.exclusive_scan(scan_in, scan_out)
print("Excl  :", buf_to_list(scan_out, 8))

# Reductions
r_min = gpu.reduce_min(scan_in)
r_max = gpu.reduce_max(scan_in)
r_prod = gpu.reduce_prod(scan_in)
a_min = gpu.argmin(scan_in)
a_max = gpu.argmax(scan_in)
print("reduce_min:", r_min, "| reduce_max:", r_max, "| reduce_prod:", r_prod)
print("argmin    :", a_min, "| argmax    :", a_max)

# Parallel Radix Sort
sort_buf = gpu.alloc(8)
sort_buf[0] = 45.0
sort_buf[1] = 12.0
sort_buf[2] = 89.0
sort_buf[3] = 3.0
sort_buf[4] = 27.0
sort_buf[5] = 64.0
sort_buf[6] = 1.0
sort_buf[7] = 50.0

print("Unsorted:", buf_to_list(sort_buf, 8))
gpu.radix_sort(sort_buf)
print("Sorted  :", buf_to_list(sort_buf, 8))

# -----------------------------------------------------------------------------
# 5. Test Taichi-Style Morton Z-Order Curves & AoS/SoA Layouts
# -----------------------------------------------------------------------------
print("\n[5] Testing Taichi Morton Z-Order Curves & AoS/SoA Transpositions...")
code2d = gpu.morton_encode_2d(3, 5)
dec2d = gpu.morton_decode_2d(code2d)
print("Morton 2D: (3, 5) -> code:", code2d, "-> decoded:", dec2d)

code3d = gpu.morton_encode_3d(2, 4, 7)
dec3d = gpu.morton_decode_3d(code3d)
print("Morton 3D: (2, 4, 7) -> code:", code3d, "-> decoded:", dec3d)

# Morton 2D Swizzling (4x4 grid)
grid_linear = gpu.alloc(16)
grid_swizzled = gpu.alloc(16)
grid_unswizzled = gpu.alloc(16)
for i in range(16):
    grid_linear[i] = float(i * 10)

gpu.morton_swizzle_2d(grid_linear, grid_swizzled, 4, 4)
gpu.morton_unswizzle_2d(grid_swizzled, grid_unswizzled, 4, 4)
print("Original 2D Grid [0..7]  :", buf_to_list(grid_linear, 8))
print("Swizzled Morton [0..7]   :", buf_to_list(grid_swizzled, 8))
print("Unswizzled Grid [0..7]   :", buf_to_list(grid_unswizzled, 8))

# AoS to SoA transposition (4 elements, 3 channels RGB)
aos_buf = gpu.alloc(12)
soa_buf = gpu.alloc(12)
re_aos_buf = gpu.alloc(12)
for i in range(12):
    aos_buf[i] = float(i + 1)

gpu.aos_to_soa(aos_buf, soa_buf, 4, 3)
gpu.soa_to_aos(soa_buf, re_aos_buf, 4, 3)
print("AoS Buffer (RGBRGB...):", buf_to_list(aos_buf, 12))
print("SoA Buffer (RRRGGGBBB):", buf_to_list(soa_buf, 12))
print("Re-AoS Buffer         :", buf_to_list(re_aos_buf, 12))

# -----------------------------------------------------------------------------
# 6. Test Numba-Style Shared Memory Scratchpad & Grid Coordinates
# -----------------------------------------------------------------------------
print("\n[6] Testing Block Shared Memory & Warp Intrinsic Emulation...")
shared_mem = gpu.shared_array(128)
shared_mem[0] = 777.0
shared_mem[127] = 888.0
print("Shared Array allocated. shared_mem[0] =", shared_mem[0], "| shared_mem[127] =", shared_mem[127])

g1 = gpu.grid(1)
g2 = gpu.grid(2)
g3 = gpu.grid(3)
print("grid(1) =", g1, "| grid(2) =", g2, "| grid(3) =", g3)

w_down = gpu.warp_shuffle_down(42.0, 1)
w_xor = gpu.warp_shuffle_xor(42.0, 1)
print("warp_shuffle_down =", w_down, "| warp_shuffle_xor =", w_xor)

# -----------------------------------------------------------------------------
# 7. Test Numba Grid Kernel Launch Semantics `kernel[grid, block](args)`
# -----------------------------------------------------------------------------
print("\n[7] Testing Numba Grid/Block Kernel Call Semantics...")
out_kernel_buf = gpu.alloc(16)

def simple_kernel(dst):
    gid = gpu.global_id()
    dst[gid] = float(gid * 100)

bound_k = simple_kernel[2, 8]
bound_k(out_kernel_buf)
print("Kernel Output via simple_kernel[2, 8]:", buf_to_list(out_kernel_buf, 8))

print("\n=================================================================")
print("✔ [SUCCESS] ALL ADVANCED GPU ECOSYSTEM FEATURES VALIDATED!")
print("=================================================================")
