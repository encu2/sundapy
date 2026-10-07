import gpu

print("=== [TEST GPU MULTI-DIMENSIONAL & BUFFER OPERATIONS] ===")

# Test 2D Grid / Block Kernel
# 2D Grid (2, 2) and 2D Block (4, 4) -> Total 8x8 = 64 elements
width = 8
height = 8
total_elements = width * height

grid_dim = [2, 2]
block_dim = [4, 4]

grid_buf = gpu.alloc(total_elements)

@gpu.kernel
def kernel_2d(out, w, h):
    tx = gpu.thread_idx_x()
    ty = gpu.thread_idx_y()
    bx = gpu.block_idx_x()
    by = gpu.block_idx_y()
    bdim_x = gpu.block_dim_x()
    bdim_y = gpu.block_dim_y()

    gx = bx * bdim_x + tx
    gy = by * bdim_y + ty

    if gx < w:
        if gy < h:
            idx = gy * w + gx
            out[idx] = gy * 100.0 + gx

print("Launching 2D kernel...")
kernel_2d[grid_dim, block_dim](grid_buf, width, height)
gpu.sync()

# Verify corners and center
# (0, 0) -> 0.0
# (7, 7) -> 707.0
# (3, 4) -> 403.0
print("Corner (0,0):", grid_buf[0], "(Expected: 0.0)")
print("Corner (7,7):", grid_buf[7 * width + 7], "(Expected: 707.0)")
print("Point (3,4):", grid_buf[4 * width + 3], "(Expected: 403.0)")

# Test Buffer to List and List to Buffer
host_list = gpu.to_host(grid_buf)
print("Converted to host list, len:", len(host_list))
print("Host list [0]:", host_list[0])
print("Host list [63]:", host_list[63])

# Test CPU Parallelism with cpu_parallel
results = gpu.alloc(8)
def square_worker(idx):
    results[idx] = idx * idx

gpu.cpu_parallel(0, 8, square_worker)
print("CPU Parallel squared results:")
for i in range(8):
    print("idx", i, "=", results[i])

print("=== MULTI-DIMENSIONAL TEST COMPLETED ===")
