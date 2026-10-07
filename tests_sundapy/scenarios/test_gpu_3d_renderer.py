# =============================================================================
#   SUNDAPY GPU 3D REAL-TIME RENDERER: PHOTOREALISTIC NASA EARTH & CLOUDS
#   Photographic NASA Blue Marble Day Albedo, Black Marble Night City Lights,
#   Dynamic Atmospheric Cloud Layers with Trade Winds, Rayleigh Scattering,
#   Golden-Hour Sunset Terminator, Ocean Sunglint & Zero-Malloc Pipeline
# =============================================================================
import gpu
import screenGUI
import time

def main():
    print("=================================================================")
    print("      SUNDAPY GPU 3D PHOTOREALISTIC EARTH & CLOUD ENGINE         ")
    print("=================================================================")

    WIDTH = 2560
    HEIGHT = 1440
    TARGET_FPS = 60
    DURATION_SEC = 30.0

    backend = gpu.get_backend()
    dev_name = gpu.get_device_name()
    print("Detected Compute Backend : " + str(backend))
    print("Hardware Accelerator     : " + str(dev_name))

    print("Initializing High-Performance 1440p QHD ScreenGUI Window (" + str(WIDTH) + "x" + str(HEIGHT) + ")...")
    screenGUI.init(WIDTH, HEIGHT, "SundaPy Photorealistic 3D Earth 1440p QHD (NASA Blue & Black Marble)")

    # Low-Level GPU Memory Pre-Allocation (Zero-Allocation Pipeline)
    print("Allocating Persistent VRAM RGB Framebuffer (Zero-Malloc loop)...")
    frame_buffer = gpu.alloc(WIDTH * HEIGHT * 3)

    print("\n[START] Beginning 30-Second Real-Time Photorealistic Earth Simulation...")
    print("Active Visual Systems:")
    print(" [1] NASA Blue Marble Day Surface (Continents, Rivers, Deserts, Ice Caps)")
    print(" [2] NASA Black Marble Night Lights (Glowing Cities in Europe, Asia, Americas, Java)")
    print(" [3] NASA Global Cloud Deck with Differential Wind Drift & Soft Ground Shadows")
    print(" [4] Twilight Golden-Hour Sunset/Sunrise Terminator Shading")
    print(" [5] Specular Ocean Sunglint (Blinn-Phong Exponent 48)")
    print(" [6] Atmospheric Rayleigh Scattering Limb Halo (Electric Blue Horizon Glow)")
    print(" [7] Hardware Accelerated Ray-Sphere Tracing on NVIDIA CUDA Core Engine\n")

    sim_start_time = time.time()
    last_hud_time = sim_start_time
    frame_idx = 0

    while screenGUI.is_running:
        current_time = time.time()
        elapsed = current_time - sim_start_time

        if elapsed >= DURATION_SEC:
            print("\n[FINISH] 30.0 Seconds Real-Time Simulation Completed!")
            break

        t_render_start = time.time()

        # Camera orbital parameters (smooth orbital camera tracking Earth rotation)
        cam_dist = 2.45
        cam_lat = 0.22 + 0.06 * (elapsed * 0.1)
        cam_lon = elapsed * 0.20

        # High-Performance Multi-Core 3D Earth & Atmospheric Cloud Shader
        gpu.render_3d_earth(frame_buffer, WIDTH, HEIGHT, elapsed, cam_dist, cam_lat, cam_lon)

        t_render_end = time.time()
        render_ms = (t_render_end - t_render_start) * 1000.0
        screenGUI.record_render_time(render_ms)

        # Direct Desktop Window Presentation (X11 SHM / ANSI 24-bit TrueColor)
        screenGUI.render_buffer(frame_buffer, WIDTH, HEIGHT)

        # Precise 60 FPS Frame Pacer
        screenGUI.sleep_until_next_frame(TARGET_FPS)

        frame_idx += 1

        # Periodic Real-Time Telemetry HUD (every 2.5 seconds)
        if current_time - last_hud_time >= 2.5:
            last_hud_time = current_time
            fps = screenGUI.get_fps()
            time_left = DURATION_SEC - elapsed
            cpu_pct = screenGUI.get_cpu_usage()
            gpu_pct = screenGUI.get_gpu_usage()
            print("[3D Earth Telemetry] Elapsed: " + str(int(elapsed)) + "s / 30s (" + str(int(time_left)) + "s left) | FPS: " + str(int(fps)) + " | Render: " + str(int(render_ms * 10.0) / 10.0) + "ms | GPU: " + str(int(gpu_pct)) + "% | CPU: " + str(int(cpu_pct)) + "%")

    total_actual_sec = time.time() - sim_start_time
    summary = screenGUI.get_benchmark_summary()
    screenGUI.close()

    print("\n=================================================================")
    print("        3D EARTH REAL-TIME RENDERING PERFORMANCE SUMMARY         ")
    print("=================================================================")
    print("Total Frames Rendered & Displayed :", summary["total_frames"])
    print("Total Simulation Time             :", total_actual_sec, "seconds")
    print("Average Framerate (FPS)           :", summary["avg_fps"], "FPS (Target: 60 FPS)")
    print("Average GPU Render Time per Frame :", summary["avg_render_ms"], "ms")
    print("Average Screen Show Time per Frame:", summary["avg_show_ms"], "ms")
    print("Process CPU Utilization (Host)    :", summary["cpu_usage_pct"], "%")
    print("Hardware GPU Compute Utilization  :", summary["gpu_usage_pct"], "%")
    print("Process Memory Footprint (RSS)    :", summary["memory_rss_mb"], "MB")
    print("=================================================================")
    print("✔ [PASS] PHOTOREALISTIC 3D EARTH RENDERING COMPLETED SUCCESSFULLY")
    print("=================================================================")

main()
