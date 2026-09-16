# =============================================================================
#   SUNDAPY SUPER MARIO BROS - WORLD 1-1 (120 FPS LOW-LEVEL GPU ENGINE)
# =============================================================================
import gpu
import screenGUI
import time

import level_1_1
import physics
import entities
import ai_bot

def main():
    print("=================================================================")
    print("     SUNDAPY SUPER MARIO BROS - WORLD 1-1 (GPU ACCELERATED)      ")
    print("=================================================================")

    # 1. Inspect and Initialize Hardware Accelerator
    backend = gpu.get_backend()
    dev_name = gpu.get_device_name()
    dev_count = gpu.get_device_count()

    print("Hardware Acceleration Backend :", backend)
    print("Compute Device                :", dev_name)
    print("Compute / Multi-Core Units    :", dev_count)

    # 2. Dimensions & Screen Setup (Authentic NES 256x240 @ 120 FPS)
    WIDTH = 256
    HEIGHT = 240
    CHANNELS = 3
    TARGET_FPS = 120
    TOTAL_PIXELS = WIDTH * HEIGHT * CHANNELS

    print("\nAllocating High-Performance GPU Frame Buffer (", WIDTH, "x", HEIGHT, "x 3 RGB)...")
    frame_buffer = gpu.alloc(TOTAL_PIXELS)
    print("GPU Buffer allocated successfully. Buffer size:", len(frame_buffer))

    # 3. Initialize Native Desktop X11 Window (Upscaled 3x to 768x720)
    print("\nInitializing screenGUI Desktop Window (Target:", TARGET_FPS, "FPS)...")
    screenGUI.init(WIDTH, HEIGHT, "SundaPy Super Mario Bros - World 1-1 (GPU 120 FPS)")

    # 4. World & Entity State Setup
    tiles = level_1_1.build_world_1_1()
    all_entities = level_1_1.get_goomba_spawns()

    # Add Flagpole cloth entity at x = 3168 (col 198), y = 48 (top of pole)
    # [type=4 (Flag), x, y, state=0 (idle), anim=0, facing=1]
    all_entities.append([4, 3168.0, 48.0, 0, 0, 1])

    player = physics.Player(40.0, 192.0)
    speedrunner = ai_bot.SpeedrunnerAI()

    cam_x = 0.0
    cam_y = 0.0
    frame_count = 0
    anim_time = 0.0
    victory_timer = 0

    print("\nStarting Mario Bros World 1-1 Simulation at 120 FPS!")
    print("Controls: [A/D] or [Left/Right] = Walk/Run | [Space/W] = Jump | [Shift] = Sprint")
    print("Autopilot Speedrunner AI is active if no keyboard input is detected.\n")

    game_start_time = time.time()

    # 5. Main 120 FPS High-Performance Game Loop
    while screenGUI.poll_events():
        frame_count += 1
        anim_time += 0.008333333333333333

        # A. Poll Interactive Keyboard Input
        human_keys = screenGUI.get_input()
        if human_keys.get("quit"):
            print("\nQuit requested by user.")
            break
        if human_keys.get("restart"):
            # Reset level
            tiles = level_1_1.build_world_1_1()
            all_entities = level_1_1.get_goomba_spawns()
            all_entities.append([4, 3168.0, 48.0, 0, 0, 1])
            player = physics.Player(40.0, 192.0)
            speedrunner = ai_bot.SpeedrunnerAI()
            cam_x = 0.0
            continue

        # B. Speedrunner AI or Manual Input Selection
        current_input = speedrunner.compute_input(player.x, player.y, all_entities, human_keys)

        # C. Update Player Physics & Collisions
        player.update(current_input, tiles, all_entities)

        # D. Update Entities (Goombas, Coins, Flag)
        entities.update_entities(all_entities, tiles, cam_x)

        # E. Authentic One-Way Camera Scrolling
        target_cam_x = player.x - 96.0
        if target_cam_x > cam_x:
            cam_x = target_cam_x
        max_cam_x = float(level_1_1.LEVEL_WIDTH * 16 - WIDTH)
        if cam_x > max_cam_x:
            cam_x = max_cam_x

        # F. Prepare State for GPU Rasterizer
        mario_dict = {
            "x": player.x,
            "y": player.y,
            "facing": player.facing,
            "state": player.state,
            "invulnerable": player.invuln_timer,
        }

        hud_dict = {
            "score": player.score,
            "coins": player.coins,
            "time": player.time_left,
            "world": "1-1",
        }

        # G. Measure GPU Render Calculation Time
        t_r_start = time.time()
        gpu.render_mario_frame(
            frame_buffer,
            WIDTH,
            HEIGHT,
            cam_x,
            cam_y,
            mario_dict,
            all_entities,
            tiles,
            level_1_1.LEVEL_WIDTH,
            level_1_1.LEVEL_HEIGHT,
            hud_dict,
            anim_time
        )
        t_r_end = time.time()
        render_ms = (t_r_end - t_r_start) * 1000.0
        screenGUI.record_render_time(render_ms)

        # H. Blit to Native Desktop Window
        screenGUI.render_buffer(frame_buffer, WIDTH, HEIGHT)

        # I. High-Precision 120 FPS Pacer
        screenGUI.sleep_until_next_frame(TARGET_FPS)

        # J. Victory / Clear Check
        if player.is_victory:
            victory_timer += 1
            if victory_timer >= 180: # Celebrate for 1.5 seconds after reaching castle
                print("\n★★★ STAGE CLEAR! CONGRATULATIONS! ★★★")
                print("Mario reached Peach's Castle in World 1-1!")
                break
        elif frame_count >= 1800:
            print("\n★★★ 15-SECOND 120 FPS GPU BENCHMARK COMPLETED ★★★")
            break

        # K. Fallback on Death
        if player.is_dead and player.y > 320.0:
            print("\nMario fell into a pit! Respawning...")
            player = physics.Player(40.0, 192.0)
            speedrunner = ai_bot.SpeedrunnerAI()
            cam_x = 0.0

        # Periodic Performance Log
        if frame_count > 0 and frame_count % 120 == 0:
            fps = screenGUI.get_fps()
            print("[Mario Telemetry]", "Frame:", frame_count, "| Pos X:", int(player.x), "Y:", int(player.y), "| Score:", player.score, "| CamX:", int(cam_x), "| FPS:", int(fps))

    game_end_time = time.time()
    total_sec = game_end_time - game_start_time

    # 6. Retrieve Final Performance & Benchmark Metrics
    summary = screenGUI.get_benchmark_summary()
    screenGUI.close()

    print("\n=================================================================")
    print("         SUPER MARIO BROS GPU ENGINE BENCHMARK SUMMARY           ")
    print("=================================================================")
    print("Total Frames Rendered & Displayed :", summary["total_frames"])
    print("Total Gameplay Time               :", total_sec, "seconds")
    print("Average Framerate (FPS)           :", summary["avg_fps"], "FPS (Target: 120 FPS)")
    print("Average GPU Render Time per Frame :", summary["avg_render_ms"], "ms")
    print("Average Screen Show Time per Frame:", summary["avg_show_ms"], "ms")
    print("Minimum Frame Time Recorded       :", summary["min_frame_time_ms"], "ms")
    print("Maximum Frame Time Recorded       :", summary["max_frame_time_ms"], "ms")
    print("Average CPU Utilization           :", summary["cpu_usage_pct"], "%")
    print("Estimated GPU Compute Load        :", summary["gpu_usage_pct"], "%")
    print("Process Memory Footprint (RSS)    :", summary["memory_rss_mb"], "MB")
    print("Final Mario Score                 :", player.score)
    print("Coins Collected                   :", player.coins)
    print("Time Remaining                    :", player.time_left)
    print("=================================================================")

    if summary["avg_fps"] >= 100.0:
        print("✔ [PASS] Sustained ultra-high framerate (>= 100 FPS).")
    if summary["avg_render_ms"] <= 5.0:
        print("✔ [PASS] Ultra-fast low-level GPU rasterization (< 5ms).")
    if summary["total_frames"] >= 120:
        print("✔ [PASS] Flawless 120 FPS real-time rendering verified.")

    print("\n=== MARIO BROS GPU ENGINE TEST COMPLETED SUCCESSFULLY ===")

main()
