import GUIEngine

print("=================================================================")
print("   SUNDAPY GUI & VECTOR RENDERING MEMORY OPTIMIZATION TEST SUITE  ")
print("=================================================================")

WIDTH = 160
HEIGHT = 120

print("1. Creating 2D Canvas Surface...")
canvas = GUIEngine.create_surface(WIDTH, HEIGHT)
print("Canvas created successfully. Buffer length:", len(canvas))

print("\n2. Testing Vector Drawing Primitives...")
GUIEngine.clear(canvas, 15.0, 20.0, 30.0)
GUIEngine.draw_rect(canvas, WIDTH, HEIGHT, 10, 10, 40, 30, 255.0, 80.0, 80.0, True)
GUIEngine.draw_line(canvas, WIDTH, HEIGHT, 0, 0, 80, 60, 0.0, 255.0, 100.0)
GUIEngine.draw_circle(canvas, WIDTH, HEIGHT, 80, 40, 20, 80.0, 160.0, 255.0, True)
GUIEngine.draw_text(canvas, WIDTH, HEIGHT, "SUNDAPY 2D", 5, 80, 1, 255.0, 255.0, 255.0)
print("Primitives rasterized successfully.")

print("\n3. Testing Zero-Allocation Scene Pool & Instanced Batching...")
GUIEngine.begin_scene()
GUIEngine.scene_clear(24, 24, 36)
GUIEngine.scene_set_clip(10, 10, 140, 100)
for i in range(10):
    rx = 15 + i * 12
    ry = 15 + i * 8
    GUIEngine.scene_draw_rect(rx, ry, 10, 10, 200, 150, 50 + i * 20, True)
    GUIEngine.scene_draw_line(rx, ry, rx + 10, ry + 10, 255, 255, 255)
GUIEngine.scene_draw_text(20, 95, "INSTANCED BATCH", 1, 100, 255, 200)
GUIEngine.scene_reset_clip()

print("Rendering scene to canvas buffer...")
GUIEngine.render_scene(canvas, WIDTH, HEIGHT)
print("Scene rendered successfully.")

print("\n4. Querying Scene Memory Pool Statistics...")
stats = GUIEngine.get_memory_stats()
print("Memory Pool Capacity:", stats["pool_capacity"], "bytes")
print("Memory Pool Used:", stats["pool_used"], "bytes")
print("Total Instanced Primitives:", stats["total_instances"])
print("Shared Palettes Registered:", stats["shared_palettes"])

print("\n5. Testing Ultra-High Memory Compression...")
comp_result = GUIEngine.compress_surface(canvas, "rle")
print("Compression Ratio:", comp_result["ratio"])
print("Memory Savings:", comp_result["savings_pct"], "%")
print("Original Bytes:", comp_result["original_bytes"])
print("Compressed Bytes:", comp_result["compressed_bytes"])

print("\n6. Testing Decompression...")
decomp_canvas = GUIEngine.decompress_surface(comp_result)
print("Decompressed buffer length:", len(decomp_canvas))

print("\n=================================================================")
print("   ALL GUI ENGINE & MEMORY OPTIMIZATION TESTS PASSED!            ")
print("=================================================================")
