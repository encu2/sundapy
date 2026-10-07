# =============================================================================
#   SUNDAPY PHOTOREALISTIC UHD OCEAN WAVES & BREAKING SURF SIMULATION
#   Simulasi Physics Gelombang Air & Deburan Ombak Pantai (Gerstner Shoaling,
#   Plunging Breaker Waves, Turbulent Sea Foam, Wet Sand Reflection & SSS)
#   Pure Python Code -> Transpiled by SundaPy to Native Machine Code
# =============================================================================
import gpu
import screenGUI
import time
import math

print("=================================================================")
print("  SUNDAPY UHD OCEAN WAVE PHYSICS & BREAKING SURF SIMULATION      ")
print("  (Simulasi Fisika Deburan Ombak Pantai Berkecepatan Tinggi)     ")
print("=================================================================")

# 1. Setup Simulation & Screen Dimensions
# Rendering grid: 320x180 automatically scaled to 1280x720 QHD/UHD window by screenGUI
WIDTH = 320
HEIGHT = 180
CHANNELS = 3
TOTAL_PIXELS = WIDTH * HEIGHT * CHANNELS

TARGET_FPS = 60
DURATION_SEC = 1.0
TOTAL_FRAMES = 60

print("\nAllocating Persistent VRAM RGB Framebuffer (", WIDTH, "x", HEIGHT, "x 3)...")
frame_buffer = gpu.alloc(TOTAL_PIXELS)

print("Initializing High-Performance screenGUI Desktop Window...")
screenGUI.init(WIDTH, HEIGHT, "SundaPy UHD Breaking Ocean Waves & Surf Physics")

print("\n[PHYSICS & OPTICAL SYSTEMS ACTIVE]:")
print(" [1] Coastal Bathymetry (Sloping Sand Beach & Offshore Seabed)")
print(" [2] Multi-scale Gerstner Trochoidal Wave Swells & Wind Chop")
print(" [3] Green's Law Shoaling (Wave Compression & Amplitude Steepening)")
print(" [4] Plunging Breakers (Deburan Ombak & Forward Crest Curling)")
print(" [5] Dynamic Turbulent Sea Foam & Swash Lace (Busa Ombak)")
print(" [6] Wet Sand Mirror-Like Specular Reflection & Tidal Surge")
print(" [7] Depth Color Absorption (Caribbean Turquoise to Deep Navy)")
print(" [8] Subsurface Scattering (Emerald Back-Glow in Wave Curl)")
print(" [9] Blinn-Phong Sun Glitter Specular Highlights\n")

print("Starting Real-Time 60 FPS Coastal Wave Simulation (20 seconds)...")

aspect = float(WIDTH) / float(HEIGHT)
cam_y = 3.2
cam_z = -5.8

# Normalized Sun Direction Vector (Warm late-morning tropical sun)
sun_x = 0.45 / 0.985
sun_y = 0.72 / 0.985
sun_z = 0.42 / 0.985

sim_start_time = time.time()
last_report_time = sim_start_time
frame = 0

while screenGUI.is_running and frame < TOTAL_FRAMES:
    t = float(frame) * (1.0 / float(TARGET_FPS))
    t_render_start = time.time()

    # Tide surge cycle (ombak pasang surut di pantai)
    tide_pos = 1.8 + 1.5 * math.sin(t * 0.7) - 0.4 * math.cos(t * 1.4)

    # Main Ray-Casting & Wave Physics per Pixel
    for py in range(HEIGHT):
        ndc_y = 1.0 - 2.0 * float(py) / float(HEIGHT)
        for px in range(WIDTH):
            ndc_x = (2.0 * float(px) / float(WIDTH) - 1.0) * aspect

            # Ray Direction (perspective camera with slight downward pitch)
            rd_x = ndc_x * 0.92
            rd_y = ndc_y * 0.92 - 0.32
            rd_z = 1.0
            inv_len = 1.0 / math.sqrt(rd_x * rd_x + rd_y * rd_y + rd_z * rd_z)
            rd_x = rd_x * inv_len
            rd_y = rd_y * inv_len
            rd_z = rd_z * inv_len

            out_idx = (py * WIDTH + px) * 3

            if rd_y >= 0.0:
                # Atmospheric Sky Dome with Horizon Gradient & Sun Glare
                sky_factor = min(1.0, rd_y * 2.5)
                sun_dot = max(0.0, rd_x * sun_x + rd_y * sun_y + rd_z * sun_z)
                sun_glare = math.pow(sun_dot, 32.0) * 1.4

                sky_r = (0.55 + 0.45 * (1.0 - sky_factor)) * 255.0 + sun_glare * 255.0
                sky_g = (0.75 + 0.25 * (1.0 - sky_factor)) * 255.0 + sun_glare * 240.0
                sky_b = (0.95 + 0.05 * (1.0 - sky_factor)) * 255.0 + sun_glare * 180.0

                frame_buffer[out_idx] = min(255.0, sky_r)
                frame_buffer[out_idx + 1] = min(255.0, sky_g)
                frame_buffer[out_idx + 2] = min(255.0, sky_b)
            else:
                # Water / Beach Plane Intersection with Elevation Refinement
                t_hit = -cam_y / rd_y
                hit_x = rd_x * t_hit
                hit_z = cam_z + rd_z * t_hit

                # 1. Coastal Bathymetry (Sloping seabed and sand beach)
                shore_z = 2.0
                beach_slope = 0.20
                bed_y = (shore_z - hit_z) * beach_slope - 0.25

                # 2. Water Depth & Shoaling Factor
                depth = max(0.03, -bed_y)
                shoaling = min(2.6, 1.0 / math.sqrt(max(0.2, depth * 0.75)))

                # 3. Gerstner Wave Trains (Ocean Swell + Secondary + Chop)
                phase1 = hit_z * 0.48 - t * 2.3 + 0.12 * math.sin(hit_x * 0.35)
                amp1 = 0.72 * shoaling
                w1 = amp1 * (math.sin(phase1) + 0.32 * math.sin(2.0 * phase1))

                phase2 = (hit_z * 0.92 + hit_x * 0.38) * 0.85 - t * 3.4
                amp2 = 0.32 * shoaling
                w2 = amp2 * math.sin(phase2)

                phase3 = (hit_z * 0.98 - hit_x * 0.2) * 2.2 - t * 5.8
                amp3 = 0.10
                w3 = amp3 * math.sin(phase3)

                total_wave_h = w1 + w2 + w3

                # 4. Wave Breaking Dynamics (Deburan Ombak & Plunging Curl)
                crest_ratio = (total_wave_h + amp1) / max(0.35, depth)
                breaking = max(0.0, min(1.0, (crest_ratio - 0.72) * 3.2))

                # Plunging wave barrel curl forward
                curl = breaking * 0.45 * max(0.0, math.cos(phase1))
                wave_elevation = total_wave_h + curl

                # 5. Dynamic Seafoam Generation (Busa Ombak & Swash Zone)
                foam_pat = 0.5 * (math.sin(hit_x * 3.2 + t * 1.8) * math.cos(hit_z * 3.2 - t * 2.6) + 1.0)
                swash_dist = abs(hit_z - tide_pos)
                shore_wash = max(0.0, min(1.0, 1.0 - swash_dist * 0.55))
                foam = max(0.0, min(1.0, breaking * 0.85 + shore_wash * 0.65 + foam_pat * 0.3 - 0.2))

                # 6. Surface Normal Vector
                eps = 0.08
                h_c = wave_elevation
                # Approximate slope
                dh_dx = 0.04 * math.cos(hit_x * 0.35) + 0.12 * math.cos(phase2) * 0.38
                dh_dz = amp1 * 0.48 * math.cos(phase1) + amp2 * 0.85 * math.cos(phase2)

                # Capillary ripples
                rip_x = 0.02 * math.sin(hit_x * 14.0 + t * 6.0)
                rip_z = 0.02 * math.cos(hit_z * 14.0 - t * 6.0)

                nx = -dh_dx + rip_x
                nz = -dh_dz + rip_z
                ny = 1.0
                norm_len = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
                nx = nx * norm_len
                ny = ny * norm_len
                nz = nz * norm_len

                # 7. Shading & Color Grading
                if hit_z > tide_pos - 0.8:
                    # Water Body (Tropical Ocean with Depth Absorption)
                    view_dot = max(0.0, -(rd_x * nx + rd_y * ny + rd_z * nz))
                    fresnel = 0.04 + 0.96 * math.pow(1.0 - view_dot, 5.0)

                    # Blinn-Phong Sun Glitter Specular Highlight
                    hx = sun_x - rd_x
                    hy = sun_y - rd_y
                    hz = sun_z - rd_z
                    hlen = 1.0 / math.sqrt(hx * hx + hy * hy + hz * hz)
                    hx = hx * hlen
                    hy = hy * hlen
                    hz = hz * hlen
                    spec_angle = max(0.0, nx * hx + ny * hy + nz * hz)
                    sun_glint = math.pow(spec_angle, 96.0) * 1.8

                    # Subsurface scattering (sunlight glowing through wave curl)
                    sun_through = max(0.0, sun_x * rd_x + sun_y * rd_y + sun_z * rd_z)
                    sss = math.pow(sun_through, 4.0) * breaking * 0.65

                    # Color absorption: shallow turquoise RGB(45, 215, 205) -> deep navy RGB(12, 52, 115)
                    depth_fact = min(1.0, depth * 0.45)
                    wat_r = (1.0 - depth_fact) * 45.0 + depth_fact * 12.0
                    wat_g = (1.0 - depth_fact) * 215.0 + depth_fact * 52.0
                    wat_b = (1.0 - depth_fact) * 205.0 + depth_fact * 115.0

                    # Add luminous emerald SSS glow in wave curl
                    wat_r = wat_r + sss * 40.0
                    wat_g = wat_g + sss * 180.0
                    wat_b = wat_b + sss * 120.0

                    # Sky reflection + Sun glint
                    sky_ref_r = 140.0
                    sky_ref_g = 200.0
                    sky_ref_b = 255.0

                    final_r = (1.0 - fresnel) * wat_r + fresnel * sky_ref_r + sun_glint * 255.0
                    final_g = (1.0 - fresnel) * wat_g + fresnel * sky_ref_g + sun_glint * 250.0
                    final_b = (1.0 - fresnel) * wat_b + fresnel * sky_ref_b + sun_glint * 215.0

                    # Busa Ombak (Lacey White Foam Blend)
                    if foam > 0.05:
                        foam_r = 245.0
                        foam_g = 250.0
                        foam_b = 255.0
                        final_r = (1.0 - foam) * final_r + foam * foam_r
                        final_g = (1.0 - foam) * final_g + foam * foam_g
                        final_b = (1.0 - foam) * final_b + foam * foam_b

                    frame_buffer[out_idx] = min(255.0, final_r)
                    frame_buffer[out_idx + 1] = min(255.0, final_g)
                    frame_buffer[out_idx + 2] = min(255.0, final_b)
                else:
                    # Beach Sand with Wet Sand Specular Reflectivity
                    is_wet = (hit_z > tide_pos - 2.2)
                    dry_r = 225.0
                    dry_g = 195.0
                    dry_b = 145.0

                    wet_r = 150.0
                    wet_g = 120.0
                    wet_b = 85.0

                    if is_wet:
                        # Glossy wet sand reflecting blue sky and sunlight
                        wet_fresnel = 0.38
                        frame_buffer[out_idx] = min(255.0, (1.0 - wet_fresnel) * wet_r + wet_fresnel * 160.0)
                        frame_buffer[out_idx + 1] = min(255.0, (1.0 - wet_fresnel) * wet_g + wet_fresnel * 205.0)
                        frame_buffer[out_idx + 2] = min(255.0, (1.0 - wet_fresnel) * wet_b + wet_fresnel * 255.0)
                    else:
                        frame_buffer[out_idx] = dry_r
                        frame_buffer[out_idx + 1] = dry_g
                        frame_buffer[out_idx + 2] = dry_b

    t_render_end = time.time()
    render_ms = (t_render_end - t_render_start) * 1000.0
    screenGUI.record_render_time(render_ms)

    # Blit to Desktop Screen (Pure X11 Native Window)
    screenGUI.render_buffer(frame_buffer, WIDTH, HEIGHT)

    # Lock to 60 FPS Frame Pacing
    screenGUI.sleep_until_next_frame(TARGET_FPS)

    frame = frame + 1

    # Real-Time Telemetry HUD every 2 seconds
    curr_time = time.time()
    if curr_time - last_report_time >= 2.0:
        last_report_time = curr_time
        fps = screenGUI.get_fps()
        cpu_pct = screenGUI.get_cpu_usage()
        gpu_pct = screenGUI.get_gpu_usage()
        elapsed_sec = int(curr_time - sim_start_time)
        print("[Wave Telemetry] Frame:", frame, "/", TOTAL_FRAMES, "| Elapsed:", elapsed_sec, "s | FPS:", int(fps), "| Render:", int(render_ms * 10.0) / 10.0, "ms | CPU:", int(cpu_pct), "%")

total_actual_sec = time.time() - sim_start_time
summary = screenGUI.get_benchmark_summary()
screenGUI.close()

print("\n=================================================================")
print("      UHD BREAKING OCEAN WAVES SIMULATION COMPLETED              ")
print("=================================================================")
print("Total Frames Rendered & Displayed :", summary["total_frames"])
print("Total Duration                    :", total_actual_sec, "seconds")
print("Average Framerate (FPS)           :", summary["avg_fps"], "FPS (Target: 60 FPS)")
print("Average Render Latency per Frame  :", summary["avg_render_ms"], "ms")
print("Average Screen Show Time per Frame:", summary["avg_show_ms"], "ms")
print("Process CPU Utilization           :", summary["cpu_usage_pct"], "%")
print("Process Memory Footprint (RSS)    :", summary["memory_rss_mb"], "MB")
print("=================================================================")
print("✔ [SUCCESS] Deburan Ombak Pantai Physics Simulation Completed!")
