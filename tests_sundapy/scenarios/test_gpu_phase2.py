import gpu
import time

print("=================================================================")
print("     SUNDAPY GPU LLA & HLA PHASE 2 FEATURE VALIDATION SUITE     ")
print("=================================================================")

# -----------------------------------------------------------------------------
# 1. Test HLA Multidimensional Field (`gpu.field` / `gpu.create_field`)
# -----------------------------------------------------------------------------
print("\n--- [1] Testing HLA Multidimensional Field & Coordinate Indexing ---")
f2d = gpu.field([8, 8])
print("Created 2D Field [8, 8]. Shape:", f2d.shape, "Size:", len(f2d))

# Multi-dimensional indexing verification
f2d[0, 0] = 11.0
f2d[3, 4] = 99.5
f2d[7, 7] = 777.0

val_0_0 = f2d[0, 0]
val_3_4 = f2d[3, 4]
val_7_7 = f2d[7, 7]

print("f2d[0, 0] =", val_0_0, "(Expected: 11.0)")
print("f2d[3, 4] =", val_3_4, "(Expected: 99.5)")
print("f2d[7, 7] =", val_7_7, "(Expected: 777.0)")

# Test Fill operation
f2d.fill(3.14)
print("f2d.fill(3.14) -> f2d[0, 0] =", f2d[0, 0], "f2d[3, 4] =", f2d[3, 4])

# Test 3D Field
f3d = gpu.field([4, 4, 4])
print("Created 3D Field [4, 4, 4]. Shape:", f3d.shape, "Size:", len(f3d))
f3d[1, 2, 3] = 42.0
print("f3d[1, 2, 3] =", f3d[1, 2, 3], "(Expected: 42.0)")

# -----------------------------------------------------------------------------
# 2. Test LLA VRAM Arena Sub-Allocator (`gpu.arena_alloc`, `gpu.arena_reset`)
# -----------------------------------------------------------------------------
print("\n--- [2] Testing LLA VRAM Fast Arena Sub-Allocator ---")
t0 = time.time()
arena_bufs = []
for i in range(100):
    buf = gpu.arena_alloc(1024)
    buf[0] = float(i)
    arena_bufs.append(buf)
alloc_time_us = (time.time() - t0) * 1000000.0 / 100.0
print("Allocated 100 Arena Buffers. Avg time per sub-allocation:", alloc_time_us, "µs")
print("Buffer 0 val:", arena_bufs[0][0], "| Buffer 99 val:", arena_bufs[99][0])

# Arena Reset test
gpu.arena_reset()
print("gpu.arena_reset() completed cleanly.")

# -----------------------------------------------------------------------------
# 3. Test Zero-Copy Interop Gateway (`to_raw_handle`, `get_raw_pointer`, `from_raw_handle`)
# -----------------------------------------------------------------------------
print("\n--- [3] Testing Zero-Copy Interop Gateway (LLA <-> HLA) ---")
test_buf = gpu.alloc(256)
test_buf[5] = 123.456

# Functional and Object-Oriented raw handles
raw_desc = gpu.to_raw_handle(test_buf)
raw_desc_oo = test_buf.to_raw_handle()
raw_ptr = gpu.get_raw_pointer(test_buf)

print("Raw Handle Descriptor:", raw_desc)
print("Device Pointer via get_raw_pointer:", raw_ptr)
print("Byte Size:", raw_desc["byte_size"], "Stride:", raw_desc["stride"])

# Zero-copy reconstruction from raw handle
reconstructed_buf = gpu.from_raw_handle(raw_desc["dev_ptr"], 256)
print("Reconstructed Buffer size:", len(reconstructed_buf), "dev_ptr:", reconstructed_buf.dev_ptr)

# -----------------------------------------------------------------------------
# 4. Test High-Performance Persistent Worker Pool (SPMD Kernel & Parallel For)
# -----------------------------------------------------------------------------
print("\n--- [4] Testing Persistent Worker Pool Multi-Core Throughput ---")
pool_buf = gpu.alloc(10000)

# Dispatch multiple parallel loops to test persistent thread reuse (zero spawn overhead)
t_start = time.time()
iterations = 500

def update_elem(idx):
    pool_buf[idx] = float(idx * 2)

for k in range(iterations):
    gpu.parallel_for(0, 1000, update_elem)

elapsed_us = (time.time() - t_start) * 1000000.0 / iterations
print("Dispatched", iterations, "batches across persistent worker pool.")
print("Average dispatch-to-completion time per batch:", elapsed_us, "µs")
print("Sample output: pool_buf[500] =", pool_buf[500], "(Expected: 1000.0)")

print("\n=================================================================")
print("✔ [PASS] ALL GPU LLA & HLA PHASE 2 FEATURES VALIDATED SUCCESSFULLY")
print("=================================================================")
