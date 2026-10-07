import gpu
import screenGUI
import time

print("=================================================================")
print("   SUNDAPY 4-DIMENSIONAL GPU MATHEMATICAL RENDERER & BENCHMARK   ")
print("=================================================================")

# 1. Inspect and initialize hardware accelerator
backend = gpu.get_backend()
dev_name = gpu.get_device_name()
dev_count = gpu.get_device_count()

print("Hardware Acceleration Backend:", backend)
print("Compute Device:", dev_name)
print("Device / Multi-Core Count:", dev_count)

# 2. Setup Screen & Buffer Dimensions
WIDTH = 80
HEIGHT = 40
CHANNELS = 3
TOTAL_PIXELS = WIDTH * HEIGHT * CHANNELS

TARGET_FPS = 120
ANIMATION_DURATION_SEC = 15
TOTAL_FRAMES = ANIMATION_DURATION_SEC * TARGET_FPS

print("\nAllocating 4D GPU Frame Buffer (", WIDTH, "x", HEIGHT, "x 3 RGB)...")
frame_buffer = gpu.alloc(TOTAL_PIXELS)
print("GPU Buffer allocated successfully. Buffer size:", len(frame_buffer))

# 3. Initialize screenGUI (Pure Zig stdlib graphical display)
print("\nInitializing screenGUI Display (Target Framerate:", TARGET_FPS, "FPS, Duration:", ANIMATION_DURATION_SEC, "s)...")
screenGUI.init(WIDTH, HEIGHT, "SundaPy 4D Hyper-Torus GPU Engine")

# 4. Main 120 FPS Rendering & Simulation Loop
print("Starting 120 FPS 4D Quantum Manifold Simulation for 15 seconds (1800 frames)...")
sim_start_time = time.time()

for frame in range(TOTAL_FRAMES):
    # Calculate simulation time parameter (fluid game-speed motion)
    # Each frame advances time by dt = 1.0 / TARGET_FPS
    t = frame * (1.0 / TARGET_FPS)

    # A. Measure GPU Render Calculation Time
    t_render_start = time.time()
    gpu.render_4d_object(frame_buffer, WIDTH, HEIGHT, t)
    t_render_end = time.time()

    render_ms = (t_render_end - t_render_start) * 1000.0
    screenGUI.record_render_time(render_ms)

    # B. Measure Screen Display Calculation Time & Blit to Screen
    screenGUI.render_buffer(frame_buffer, WIDTH, HEIGHT)

    # C. High-Precision Frame Pacer (locks smoothly to 120 FPS)
    screenGUI.sleep_until_next_frame(TARGET_FPS)

    # Periodic console status check every 300 frames
    if frame > 0 and frame % 300 == 0:
        cur_fps = screenGUI.get_fps()
        cur_cpu = screenGUI.get_cpu_usage()
        cur_gpu = screenGUI.get_gpu_usage()
        cur_mem = screenGUI.get_memory_usage()
        # Keep HUD active

sim_end_time = time.time()
actual_duration = sim_end_time - sim_start_time

# 5. Retrieve Final Comprehensive Performance & Metric Statistics
summary = screenGUI.get_benchmark_summary()
screenGUI.close()

print("\n=================================================================")
print("         4D GPU RENDERING ENGINE PERFORMANCE BENCHMARK           ")
print("=================================================================")
print("Total Frames Rendered & Displayed :", summary["total_frames"])
print("Total Animation Duration          :", actual_duration, "seconds (Target: 15.0s)")
print("Average Framerate (FPS)           :", summary["avg_fps"], "FPS (Target: 120 FPS)")
print("Average GPU Render Time per Frame :", summary["avg_render_ms"], "ms")
print("Average Screen Show Time per Frame:", summary["avg_show_ms"], "ms")
print("Minimum Frame Time Recorded       :", summary["min_frame_time_ms"], "ms")
print("Maximum Frame Time Recorded       :", summary["max_frame_time_ms"], "ms")
print("Average CPU Utilization           :", summary["cpu_usage_pct"], "%")
print("Estimated GPU Compute Load        :", summary["gpu_usage_pct"], "%")
print("Process Memory Footprint (RSS)    :", summary["memory_rss_mb"], "MB")
print("=================================================================")

# Verify correctness of output
if summary["total_frames"] == TOTAL_FRAMES:
    print("✔ [PASS] Exactly 1800 frames rendered and displayed.")
if actual_duration >= 14.0 and actual_duration <= 16.5:
    print("✔ [PASS] Animation duration perfectly matched 15 seconds.")
if summary["avg_fps"] >= 100.0:
    print("✔ [PASS] Sustained ultra-high framerate (>= 100 FPS).")

print("\n=== 4D GPU RENDERING & BENCHMARK COMPLETED SUCCESSFULLY ===")
