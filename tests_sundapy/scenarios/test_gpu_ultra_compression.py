import gpu

def test_ultra_compression():
    print("=================================================================")
    print("   SUNDAPY PRODUCTION GPU VRAM ULTRA-HIGH COMPRESSION SUITE    ")
    print("=================================================================")

    # 1. Codecs Introspection
    codecs = gpu.get_codecs()
    print(f"Supported Compression Codecs: {codecs}")
    assert "fp8" in codecs
    assert "fp8_e5m2" in codecs
    assert "fp4" in codecs
    assert "bf16" in codecs
    assert "nvfp4" in codecs
    assert "compact" in codecs
    assert "quant8" in codecs
    assert "quant4" in codecs
    print("✔ [1/6] Codec registry verification passed.")

    # 2. FP8 (E4M3 Hopper) & FP8 (E5M2 OCP) Quantization
    n = 1000
    b_fp8 = gpu.alloc(n)
    for i in range(n):
        b_fp8[i] = float(i) * 0.1

    print("\n--- Testing FP8 (E4M3 Hopper) Compression ---")
    b_fp8.compress("fp8")
    assert b_fp8.is_compressed == True
    assert b_fp8.scheme == "fp8"
    assert b_fp8.compression_ratio >= 3.8
    assert b_fp8.savings_pct >= 70.0
    print(f"FP8 Ratio: {b_fp8.compression_ratio:.2f}x | Savings: {b_fp8.savings_pct:.1f}%")
    print(f"Original bytes: {b_fp8.original_bytes} | Compressed bytes: {b_fp8.compressed_bytes}")

    # Test random read access directly from compressed buffer
    v0 = b_fp8[0]
    v10 = b_fp8[10]
    v100 = b_fp8[100]
    print(f"Direct compressed read b_fp8[0]: {v0} (expected ~0.0)")
    print(f"Direct compressed read b_fp8[10]: {v10} (expected ~1.0)")
    print(f"Direct compressed read b_fp8[100]: {v100} (expected ~10.0)")
    assert abs(v0 - 0.0) < 0.1
    assert abs(v10 - 1.0) < 0.15
    assert abs(v100 - 10.0) < 0.5

    b_fp8.decompress()
    assert b_fp8.is_compressed == False
    print("FP8 decompress succeeded. Post-decompression value b_fp8[100]:", b_fp8[100])
    print("✔ [2/6] FP8 E4M3 compression & direct random access verified.")

    # 3. FP4 (E2M1 Blackwell) Ultra-Compression (8.0x)
    print("\n--- Testing FP4 (E2M1 Blackwell) 8x Compression ---")
    b_fp4 = gpu.alloc(n)
    for i in range(n):
        b_fp4[i] = float(i % 16) * 0.25

    b_fp4.compress("fp4")
    assert b_fp4.is_compressed == True
    assert b_fp4.compression_ratio >= 7.5
    assert b_fp4.savings_pct >= 85.0
    print(f"FP4 Ratio: {b_fp4.compression_ratio:.2f}x | Savings: {b_fp4.savings_pct:.1f}%")
    print(f"Original: {b_fp4.original_bytes}B -> Compressed: {b_fp4.compressed_bytes}B")

    # Direct read on 4-bit packed nibbles
    fp4_v0 = b_fp4[0]
    fp4_v4 = b_fp4[4]
    print(f"Direct FP4 read b_fp4[0]: {fp4_v0} (expected 0.0)")
    print(f"Direct FP4 read b_fp4[4]: {fp4_v4} (expected ~1.0)")
    assert abs(fp4_v0 - 0.0) < 0.1
    assert abs(fp4_v4 - 1.0) < 0.25

    b_fp4.decompress()
    assert b_fp4.is_compressed == False
    print("✔ [3/6] FP4 E2M1 8x ultra-compression & direct read verified.")

    # 4. BF16 (Brain Floating Point 16) & NVFP4 Microscaling
    print("\n--- Testing BF16 & NVFP4 Microscaling ---")
    b_bf16 = gpu.alloc(n)
    for i in range(n):
        b_bf16[i] = float(i) * 1.5
    b_bf16.compress("bf16")
    assert b_bf16.is_compressed == True
    assert b_bf16.compression_ratio >= 1.9
    assert b_bf16.savings_pct >= 48.0
    print(f"BF16 Ratio: {b_bf16.compression_ratio:.2f}x | Savings: {b_bf16.savings_pct:.1f}%")
    bf16_val = b_bf16[50]
    print(f"Direct BF16 read b_bf16[50]: {bf16_val} (expected 75.0)")
    assert abs(bf16_val - 75.0) < 0.5
    b_bf16.decompress()

    b_nvfp4 = gpu.alloc(512)
    for i in range(512):
        b_nvfp4[i] = float(i % 32) * 2.0
    b_nvfp4.compress("nvfp4")
    assert b_nvfp4.is_compressed == True
    print(f"NVFP4 Microscale Ratio: {b_nvfp4.compression_ratio:.2f}x | Savings: {b_nvfp4.savings_pct:.1f}%")
    assert b_nvfp4.compression_ratio >= 6.8
    nv_val = b_nvfp4[16]
    print(f"Direct NVFP4 read b_nvfp4[16]: {nv_val}")
    b_nvfp4.decompress()
    print("✔ [4/6] BF16 and Blackwell NVFP4 Microscaling verified.")

    # 5. Zero-Copy Cacheline-Aligned Compaction
    print("\n--- Testing Zero-Copy Compaction ---")
    b_sparse = gpu.alloc(1000)
    # Only 50 active non-zero elements out of 1000
    b_sparse[10] = 42.0
    b_sparse[100] = 99.0
    b_sparse[500] = 777.0
    b_sparse[990] = 3.14

    b_sparse.compact(0.00001)
    assert b_sparse.is_compressed == True
    print(f"Compaction Ratio: {b_sparse.compression_ratio:.2f}x | Savings: {b_sparse.savings_pct:.1f}%")
    assert b_sparse.compression_ratio >= 5.0
    assert b_sparse.savings_pct >= 80.0

    # Read active and inactive elements
    assert abs(b_sparse[10] - 42.0) < 0.001
    assert abs(b_sparse[100] - 99.0) < 0.001
    assert abs(b_sparse[500] - 777.0) < 0.001
    assert abs(b_sparse[0] - 0.0) < 0.001

    b_sparse.uncompact()
    assert b_sparse.is_compressed == False
    assert abs(b_sparse[10] - 42.0) < 0.001
    print("✔ [5/6] Zero-Copy cacheline compaction verified.")

    # 6. Bit-Level Compressed Sparse Row (BCSR) and Direct Hardware SpMV
    print("\n--- Testing BCSR & Hardware SpMV ---")
    matrix_dim = 16
    A = gpu.alloc(matrix_dim * matrix_dim)
    # Populate a sparse diagonal matrix with known entries
    for i in range(matrix_dim):
        A[i * matrix_dim + i] = 2.0
        if i + 1 < matrix_dim:
            A[i * matrix_dim + (i + 1)] = 0.5

    x = gpu.alloc(matrix_dim)
    for i in range(matrix_dim):
        x[i] = 1.0

    # SpMV: y = A * x
    # For row i: A[i, i]*x[i] + A[i, i+1]*x[i+1] = 2.0*1.0 + 0.5*1.0 = 2.5 (except last row = 2.0)
    A.ndim = 2
    A.shape = [matrix_dim, matrix_dim]
    y = A.spmv(x)
    print(f"SpMV y[0] = {y[0]} (expected 2.5)")
    print(f"SpMV y[1] = {y[1]} (expected 2.5)")
    print(f"SpMV y[{matrix_dim - 1}] = {y[matrix_dim - 1]} (expected 2.0)")
    assert abs(y[0] - 2.5) < 0.001
    assert abs(y[matrix_dim - 1] - 2.0) < 0.001
    print("✔ [6/6] Bit-Level Compressed Sparse Matrix SpMV verified.")

    # 7. Codec Benchmark Execution
    print("\n--- Running Multi-Codec Compression Benchmark ---")
    bench_results = gpu.benchmark_compression(4096)
    print(f"Benchmark evaluated {len(bench_results)} codecs successfully.")

    print("\n=================================================================")
    print("✔ [PASS] ALL GPU VRAM ULTRA COMPRESSION TESTS PASSED CLEANLY!")
    print("=================================================================")

test_ultra_compression()
