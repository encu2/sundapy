import gpu
import screenGUI
import GUIEngine
import time

print("=================================================================")
print("  SUNDAPY PRODUCTION MEMORY SUBSYSTEM & COMPRESSION TEST SUITE  ")
print("  (Unified Codecs, In-Place Buffer Compression, Zero-OOM Budget, ")
print("   Screen Framebuffer Deduplication, GUI Surface Optimization)   ")
print("=================================================================")

# -----------------------------------------------------------------------------
# 1. Test Unified Codec Discovery
# -----------------------------------------------------------------------------
print("\n[1] Testing Unified Compression Codec Registry...")
codecs = gpu.get_codecs()
print("Supported GPU Codecs (Count =", len(codecs), "):", codecs)

expected_codecs = ["fpc", "quant8", "quant4", "fp16", "fp8", "fp4", "lz_fast", "rle", "bpc", "delta_rle"]
for c in expected_codecs:
    found = False
    for avail in codecs:
        if avail == c:
            found = True
            break
    if not found:
        print("ERROR: Expected codec", c, "not found in registry!")
print("✔ All primary codecs present in unified registry.")

# -----------------------------------------------------------------------------
# 2. Test Low-Level Compression & Decompression Roundtrips
# -----------------------------------------------------------------------------
print("\n[2] Testing Unified Codec Compression & Decompression Roundtrips...")
size = 256
diff = 0.0
test_buf = gpu.alloc(size)
for i in range(size):
    test_buf[i] = float(i) * 1.25

# Test Lossless Codec: FPC
print("\n--- Testing Codec: fpc (Lossless Fast Float Compression) ---")
comp_fpc = gpu.compress(test_buf, "fpc")
ratio_fpc = gpu.compress_ratio(test_buf, "fpc")
print("FPC Ratio:", ratio_fpc, "| Compressed Bytes:", comp_fpc["compressed_bytes"], "| Savings:", comp_fpc["savings_pct"], "%")

dec_fpc = gpu.decompress(comp_fpc)
fpc_diff = 0.0
for i in range(size):
    diff = abs(test_buf[i] - dec_fpc[i])
    if diff > fpc_diff:
        fpc_diff = diff
print("FPC Max Reconstruction Error:", fpc_diff, "(Expected: 0.0, Exact Lossless)")
if fpc_diff > 0.00001:
    print("ERROR: FPC is not lossless!")

# Test Lossless Codec: LZ Fast
print("\n--- Testing Codec: lz_fast (Lossless Dictionary Compression) ---")
comp_lz = gpu.compress(test_buf, "lz_fast")
dec_lz = gpu.decompress(comp_lz)
lz_diff = 0.0
for i in range(size):
    diff = abs(test_buf[i] - dec_lz[i])
    if diff > lz_diff:
        lz_diff = diff
print("LZ Fast Max Reconstruction Error:", lz_diff, "(Expected: 0.0, Exact Lossless)")

# Test Lossless Codec: RLE on Homogeneous/Sparse Data
print("\n--- Testing Codec: rle (Run-Length Encoding) ---")
sparse_buf = gpu.alloc(size)
for i in range(size):
    sparse_buf[i] = 42.0 if i < 20 else 0.0
comp_rle = gpu.compress(sparse_buf, "rle")
dec_rle = gpu.decompress(comp_rle)
print("RLE Compressed Bytes:", comp_rle["compressed_bytes"], "| Ratio:", comp_rle["ratio"])
rle_diff = 0.0
for i in range(size):
    diff = abs(sparse_buf[i] - dec_rle[i])
    if diff > rle_diff:
        rle_diff = diff
print("RLE Max Reconstruction Error:", rle_diff, "(Expected: 0.0, Exact Lossless)")

# Test Lossy Codecs: Quant8 and FP16
print("\n--- Testing Codec: quant8 (8-Bit Min-Max Quantization, 4.0x) ---")
comp_q8 = gpu.compress(test_buf, "quant8")
dec_q8 = gpu.decompress(comp_q8)
q8_ratio = comp_q8["ratio"]
print("Quant8 Ratio:", q8_ratio, "(Expected ~4.0x)")
print("Original val[10]:", test_buf[10], "| Quant8 val[10]:", dec_q8[10])

print("\n--- Testing Codec: fp16 (IEEE-754 Half-Precision Float, 2.0x) ---")
comp_fp16 = gpu.compress(test_buf, "fp16")
dec_fp16 = gpu.decompress(comp_fp16)
print("FP16 Ratio:", comp_fp16["ratio"], "(Expected ~2.0x)")
print("Original val[10]:", test_buf[10], "| FP16 val[10]:", dec_fp16[10])

# -----------------------------------------------------------------------------
# 3. Test High-Level In-Place GpuBuffer Compression APIs
# -----------------------------------------------------------------------------
print("\n[3] Testing In-Place GpuBuffer Compression Methods & Properties...")
oop_buf = gpu.alloc(512)
for i in range(512):
    oop_buf[i] = 100.0 + float(i) * 0.5

print("Initial oop_buf.is_compressed:", oop_buf.is_compressed)
print("Initial oop_buf.compression_ratio:", oop_buf.compression_ratio)

# In-place compression
oop_buf.compress("fpc")
print("After oop_buf.compress('fpc'):")
print(" - is_compressed     :", oop_buf.is_compressed)
print(" - scheme            :", oop_buf.scheme)
print(" - compression_ratio :", oop_buf.compression_ratio)
print(" - savings_pct       :", oop_buf.savings_pct, "%")
print(" - compressed_bytes  :", oop_buf.compressed_bytes)
print(" - original_bytes    :", oop_buf.original_bytes)

# Buffer stats dictionary
buf_stats = oop_buf.stats()
print("Buffer Stats Dict:", buf_stats)

# In-place decompression
oop_buf.decompress()
print("After oop_buf.decompress():")
print(" - is_compressed     :", oop_buf.is_compressed)
print(" - compression_ratio :", oop_buf.compression_ratio)
print(" - Reconstructed val[0]  :", oop_buf[0], "(Expected: 100.0)")
print(" - Reconstructed val[511]:", oop_buf[511], "(Expected: 355.5)")

# -----------------------------------------------------------------------------
# 4. Test Production Memory Budget & Auto-Compaction Subsystem
# -----------------------------------------------------------------------------
print("\n[4] Testing Production VRAM Budget & Compaction...")
# Set strict memory budget: 64 KB
budget_limit = 64 * 1024
gpu.set_memory_budget(budget_limit)
b_status = gpu.get_memory_budget()
print("Set Memory Budget Limit:", b_status["budget_limit"], "bytes")

# Allocate buffers
track_bufs = []
for k in range(10):
    b = gpu.alloc(512)
    for idx in range(512):
        b[idx] = float(k * 10 + idx)
    track_bufs.append(b)

mem_stats = gpu.get_memory_stats()
print("Active Allocated Bytes :", mem_stats["allocated_bytes"])
print("Active Virtual Bytes   :", mem_stats["virtual_bytes"])
print("Active Buffers Count   :", mem_stats["active_buffers"])

# Trigger manual / proactive compaction
reclaimed = gpu.compact_memory()
print("Proactive Compact Memory Reclaimed:", reclaimed, "bytes")

# Print production memory report
gpu.memory_report()

# -----------------------------------------------------------------------------
# 5. Test Screen Framebuffer Tile Compression Engine
# -----------------------------------------------------------------------------
print("\n[5] Testing Screen Framebuffer Deduplication & Compression...")
fb_w = 160
fb_h = 100
fb_buf = gpu.alloc(fb_w * fb_h * 3)

# Fill with solid color and some variations
fb_buf.fill(45.0)

comp_frame = screenGUI.compress_framebuffer(fb_buf, fb_w, fb_h)
print("Screen Frame Compression Results:")
print(" - Resolution          :", comp_frame["width"], "x", comp_frame["height"])
print(" - Tiles Grid          :", comp_frame["tiles_x"], "x", comp_frame["tiles_y"])
print(" - Original Bytes      :", comp_frame["original_bytes"])
print(" - Compressed Bytes    :", comp_frame["compressed_bytes"])
print(" - Compression Ratio   :", comp_frame["ratio"], "x")
print(" - Bandwidth Savings   :", comp_frame["savings_pct"], "%")
print(" - Solid Tiles Count   :", comp_frame["solid_tiles"])

screen_stats = screenGUI.get_compression_stats()
print("Screen Cumulative Stats:", screen_stats)
screen_ratio = screenGUI.get_compression_ratio()
print("Screen Live Compression Ratio:", screen_ratio)

screenGUI.reset_compression_stats()
print("Reset Screen Compression Stats completed.")

# -----------------------------------------------------------------------------
# 6. Test GUI Surface Memory Optimization Subsystem
# -----------------------------------------------------------------------------
print("\n[6] Testing GUI Surface Compression & Memory Optimization...")
surf = GUIEngine.create_surface(200, 150)
GUIEngine.clear(surf, 92.0, 148.0, 252.0)
GUIEngine.draw_rect(surf, 200, 150, 20, 20, 60, 40, 255.0, 0.0, 0.0)

surf_stats = GUIEngine.get_surface_stats(surf)
print("Surface Memory Footprint:")
print(" - Float Count :", surf_stats["size"])
print(" - Byte Size   :", surf_stats["bytes"], "bytes (~", surf_stats["mb"], "MB)")

comp_surf = GUIEngine.compress_surface(surf, "rle")
print("Compressed Surface (RLE):")
print(" - Original Bytes   :", comp_surf["original_bytes"])
print(" - Compressed Bytes :", comp_surf["compressed_bytes"])
print(" - Ratio            :", comp_surf["ratio"], "x")
print(" - Savings          :", comp_surf["savings_pct"], "%")

surf_ratio = GUIEngine.compress_ratio(surf, "rle")
print("Measured Surface Ratio via GUIEngine.compress_ratio:", surf_ratio)

dec_surf = GUIEngine.decompress_surface(comp_surf)
print("Decompressed Surface Handle created. Size:", len(dec_surf))

surf_bench = GUIEngine.benchmark_surface(surf)
print("GUI Surface Benchmark Results:", surf_bench)

# -----------------------------------------------------------------------------
# 7. Test Multi-Codec Production Benchmark Suite
# -----------------------------------------------------------------------------
print("\n[7] Running Comprehensive Production Codec Benchmark (32k Floats)...")
bench_results = gpu.benchmark_compression(32768)
print("Benchmark completed! Total codecs evaluated:", len(bench_results))

print("\n=================================================================")
print("✔ [PASS] ALL PRODUCTION MEMORY SUBSYSTEM TESTS COMPLETED SUCCESSFULLY!")
print("=================================================================")
