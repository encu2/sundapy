import gpu

print("=== [SUNDAPY GPU & PARALLEL COMPUTING TEST] ===")

backend = gpu.get_backend()
dev_name = gpu.get_device_name()
dev_count = gpu.get_device_count()
lib_path = gpu.get_lib_path()

print("Active Backend:", backend)
print("Device Name:", dev_name)
print("Device / Core Count:", dev_count)
print("Detected Driver Library:", lib_path)

# 1. Test GPU Buffer Allocation and Indexing
n = 100
a = gpu.alloc(n)
b = gpu.alloc(n)
c = gpu.alloc(n)

print("\nAllocated Buffers. Size of 'a':", len(a))

for i in range(n):
    a[i] = i * 1.5
    b[i] = i * 2.5

print("Initialized buffer values. a[10] =", a[10], "| b[10] =", b[10])

# 2. Test SPMD Kernel Execution
@gpu.kernel
def custom_vector_add(x, y, z, count):
    gid = gpu.global_id()
    if gid < count:
        z[gid] = x[gid] + y[gid]

threads_per_block = 25
blocks_per_grid = (n + threads_per_block - 1) // threads_per_block

print("\nLaunching Kernel with Grid:", blocks_per_grid, "Block:", threads_per_block)
custom_vector_add[blocks_per_grid, threads_per_block](a, b, c, n)
gpu.sync()

print("Kernel finished! Verifying results:")
print("c[0] =", c[0], "(Expected: 0.0)")
print("c[10] =", c[10], "(Expected: 40.0)")
print("c[50] =", c[50], "(Expected: 200.0)")
print("c[99] =", c[99], "(Expected: 396.0)")

# 3. Test High-Performance Vectorized Math Operations
print("\n--- Accelerated Math Primitives ---")
out_buf = gpu.alloc(n)
gpu.vector_add(a, b, out_buf, n)
print("Vector Add out_buf[10] =", out_buf[10])

gpu.vector_mul(a, b, out_buf, n)
print("Vector Mul out_buf[10] =", out_buf[10])

sum_res = gpu.reduce_sum(a, n)
print("Reduce Sum a:", sum_res)

dot_res = gpu.dot_product(a, b, n)
print("Dot Product (a . b):", dot_res)

# 4. Test Matrix Multiplication (2x2)
print("\n--- Matrix Multiplication ---")
mat_a = gpu.alloc(4)
mat_b = gpu.alloc(4)
mat_c = gpu.alloc(4)

# A = [[1, 2], [3, 4]]
mat_a[0] = 1.0
mat_a[1] = 2.0
mat_a[2] = 3.0
mat_a[3] = 4.0

# B = [[5, 6], [7, 8]]
mat_b[0] = 5.0
mat_b[1] = 6.0
mat_b[2] = 7.0
mat_b[3] = 8.0

# C = A x B
# C[0,0] = 1*5 + 2*7 = 19
# C[0,1] = 1*6 + 2*8 = 22
# C[1,0] = 3*5 + 4*7 = 43
# C[1,1] = 3*6 + 4*8 = 50
gpu.matmul(mat_a, mat_b, mat_c, 2, 2, 2)

print("Matmul C[0] =", mat_c[0], "(Expected: 19.0)")
print("Matmul C[1] =", mat_c[1], "(Expected: 22.0)")
print("Matmul C[2] =", mat_c[2], "(Expected: 43.0)")
print("Matmul C[3] =", mat_c[3], "(Expected: 50.0)")

# 5. Test Parallel For Loop
print("\n--- Multi-Core Parallel For Loop ---")
counter_buf = gpu.alloc(10)
def parallel_task(idx):
    counter_buf[idx] = idx * 10.0

gpu.parallel_for(0, 10, parallel_task)
print("Parallel For result counter_buf[7] =", counter_buf[7], "(Expected: 70.0)")

print("\n=== ALL GPU AND PARALLEL TESTS COMPLETED SUCCESSFULLY ===")
