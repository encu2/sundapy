# =============================================================================
#   SUNDAPY SUPER MARIO BROS - WORLD 1-1 (60 FPS INTERACTIVE GAME ENGINE)
# =============================================================================
import GUIEngine
import gpu
import screenGUI
import time

import level_1_1
import physics
import entities
import ai_bot

def draw_koopa(frame_buffer, width, height, sx, sy, state, facing):
    if sx < -16.0 or sx > float(width) or sy < -16.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    if state == 0: # Walking Turtle
        # Green shell
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 2, iy + 4, 10, 8, 32.0, 180.0, 32.0, True)
        # Yellow belly
        bx = ix + (6 if facing > 0 else 2)
        GUIEngine.draw_rect(frame_buffer, width, height, bx, iy + 7, 4, 5, 252.0, 220.0, 60.0, True)
        # Green head
        hx = ix + (11 if facing > 0 else 0)
        GUIEngine.draw_rect(frame_buffer, width, height, hx, iy + 1, 5, 5, 32.0, 200.0, 32.0, True)
        # White eye
        ex = hx + (3 if facing > 0 else 1)
        GUIEngine.draw_rect(frame_buffer, width, height, ex, iy + 2, 2, 2, 255.0, 255.0, 255.0, True)
        # Feet
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 2, iy + 12, 4, 4, 240.0, 140.0, 32.0, True)
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 8, iy + 12, 4, 4, 240.0, 140.0, 32.0, True)
    elif state == 1 or state == 2: # Shell
        # Green rounded shell
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 2, iy + 6, 12, 10, 32.0, 180.0, 32.0, True)
        # Yellowish rim
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 1, iy + 14, 14, 2, 240.0, 240.0, 200.0, True)
        # Inner pattern
        GUIEngine.draw_rect(frame_buffer, width, height, ix + 5, iy + 8, 6, 4, 20.0, 130.0, 20.0, True)

def draw_piranha(frame_buffer, width, height, sx, sy):
    if sx < -16.0 or sx > float(width) or sy < -24.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    # Green stem
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 6, iy + 10, 4, 8, 0.0, 168.0, 0.0, True)
    # Red head
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 2, iy, 12, 10, 220.0, 30.0, 30.0, True)
    # White polka dots
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 4, iy + 2, 2, 2, 255.0, 255.0, 255.0, True)
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 9, iy + 3, 2, 2, 255.0, 255.0, 255.0, True)
    # White teeth
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 3, iy + 8, 10, 2, 255.0, 255.0, 255.0, True)

def draw_fireball(frame_buffer, width, height, sx, sy):
    if sx < -8.0 or sx > float(width) or sy < -8.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    GUIEngine.draw_circle(frame_buffer, width, height, ix + 4, iy + 4, 4, 252.0, 80.0, 0.0, True)
    GUIEngine.draw_circle(frame_buffer, width, height, ix + 4, iy + 4, 2, 255.0, 240.0, 80.0, True)

def draw_mushroom(frame_buffer, width, height, sx, sy):
    if sx < -16.0 or sx > float(width) or sy < -16.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    # Red cap
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 2, iy + 2, 12, 8, 224.0, 40.0, 20.0, True)
    # White spots
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 4, iy + 4, 3, 3, 255.0, 255.0, 255.0, True)
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 9, iy + 4, 3, 3, 255.0, 255.0, 255.0, True)
    # Stem
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 4, iy + 10, 8, 6, 252.0, 216.0, 168.0, True)
    # Eyes
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 5, iy + 11, 2, 3, 0.0, 0.0, 0.0, True)
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 9, iy + 11, 2, 3, 0.0, 0.0, 0.0, True)

def draw_flower(frame_buffer, width, height, sx, sy, anim_tick):
    if sx < -16.0 or sx > float(width) or sy < -16.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    # Stem
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 7, iy + 8, 2, 8, 0.0, 168.0, 0.0, True)
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 4, iy + 11, 8, 2, 0.0, 168.0, 0.0, True)
    # Flashing petals
    flash = (int(anim_tick * 8.0) % 2 == 0)
    pr = 252.0 if flash else 240.0
    pg = 140.0 if flash else 60.0
    pb = 30.0 if flash else 200.0
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 3, iy + 1, 10, 7, pr, pg, pb, True)
    # White center
    GUIEngine.draw_rect(frame_buffer, width, height, ix + 6, iy + 3, 4, 3, 255.0, 255.0, 255.0, True)

def draw_flag(frame_buffer, width, height, sx, sy):
    if sx < -16.0 or sx > float(width) or sy < -16.0 or sy > float(height):
        return
    ix = int(sx)
    iy = int(sy)
    GUIEngine.draw_rect(frame_buffer, width, height, ix - 14, iy, 14, 12, 0.0, 168.0, 0.0, True)
    GUIEngine.draw_rect(frame_buffer, width, height, ix - 10, iy + 3, 6, 6, 255.0, 255.0, 255.0, True)

def main():
    print("=================================================================")
    print("     SUNDAPY SUPER MARIO BROS - WORLD 1-1 (60 FPS INTERACTIVE)   ")
    print("=================================================================")

    # 1. Hardware Accelerator Diagnostics
    backend = gpu.get_backend()
    dev_name = gpu.get_device_name()
    dev_count = gpu.get_device_count()

    print("Hardware Acceleration Backend :", backend)
    print("Compute Device                :", dev_name)
    print("Compute Units                 :", dev_count)

    # 2. Authentic NES Dimensions & 60 FPS Calibration
    WIDTH = 256
    HEIGHT = 240
    TARGET_FPS = 60

    print("\nAllocating 60 FPS GPU Frame Buffer (", WIDTH, "x", HEIGHT, "x 3 RGB)...")
    frame_buffer = GUIEngine.create_surface(WIDTH, HEIGHT)

    # 3. Initialize Desktop X11 / Wayland Window (Upscaled 3x to 768x720)
    print("Initializing screenGUI Window (Target:", TARGET_FPS, "FPS)...")
    screenGUI.init(WIDTH, HEIGHT, "SundaPy Super Mario Bros - World 1-1 (60 FPS)")

    # 4. Initialize Game State
    tiles = level_1_1.build_world_1_1()
    all_entities = level_1_1.get_initial_entities()
    player = physics.Player(40.0, 192.0)
    speedrunner = ai_bot.SpeedrunnerAI()

    cam_x = 0.0
    cam_y = 0.0
    frame_count = 0
    anim_time = 0.0
    victory_timer = 0
    p_key_was_pressed = False

    print("\nGame ready! Play indefinitely at 60 FPS!")
    print("Controls:")
    print("  [W / Up Arrow]   : Jump")
    print("  [A / Left Arrow] : Move Left")
    print("  [D / Right Arrow]: Move Right")
    print("  [S / Down Arrow] : Duck / Crouch")
    print("  [Space]          : Attack (Fireball / Strike)")
    print("  [Shift]          : Sprint")
    print("  [P]              : Toggle AI Autopilot")
    print("  [R]              : Restart Level")
    print("  [Q / Esc]        : Quit Game\n")

    game_start_time = time.time()

    # 5. Main 60 FPS Interactive Game Loop (runs indefinitely)
    while screenGUI.poll_events():
        frame_count += 1
        anim_time += 0.016666666666666666 # 1/60th second per frame

        # A. Poll Keyboard Input
        human_keys = screenGUI.get_input()
        if human_keys.get("quit"):
            print("\nQuit requested by user.")
            break

        # Check Space key for Attack
        if human_keys.get("jump"):
            if human_keys.get("up") == False:
                human_keys["attack"] = True
            else:
                human_keys["attack"] = False
        else:
            human_keys["attack"] = False

        # Check 'R' key to Restart Level
        if human_keys.get("restart"):
            print("\nLevel restarted by player.")
            tiles = level_1_1.build_world_1_1()
            all_entities = level_1_1.get_initial_entities()
            player = physics.Player(40.0, 192.0)
            cam_x = 0.0
            continue

        # Direct player interactive control
        current_input = human_keys

        # C. Update Player Physics & Interactions
        player.update(current_input, tiles, all_entities)

        # Spawn Fireball if requested
        if player.shoot_fireball:
            player.shoot_fireball = False
            fb_x = player.x + (14.0 if player.facing > 0 else -6.0)
            fb_y = player.y + 4.0
            fb_vx = 5.0 * float(player.facing)
            all_entities.append([6, fb_x, fb_y, 0, 0, player.facing, fb_vx, 1.2])

        # Spawn Power-Up or Coin from Question Block
        if player.pending_spawn_type > 0:
            st = player.pending_spawn_type
            sx = player.pending_spawn_x
            sy = player.pending_spawn_y
            player.pending_spawn_type = 0
            if st == 7:
                all_entities.append([7, sx, sy, 0, 0, 1, 1.2, -2.0])
            elif st == 8:
                all_entities.append([8, sx, sy, 0, 0, 1, 0.0, 0.0])
            elif st == 2:
                all_entities.append([2, sx + 4.0, sy, 0, 0, 1, 0.0, -3.0])

        # D. Update All Entities (Goombas, Koopas, Piranhas, Fireballs, Mushrooms)
        entities.update_entities(all_entities, tiles, cam_x, player.x)

        # E. Authentic One-Way Camera Tracking
        target_cam_x = player.x - 96.0
        if target_cam_x > cam_x:
            cam_x = target_cam_x
        max_cam_x = float(level_1_1.LEVEL_WIDTH * 16 - WIDTH)
        if cam_x > max_cam_x:
            cam_x = max_cam_x

        # F. Player Death Handling & Respawn / Game Over
        if player.is_dead and player.y > 280.0:
            player.lives -= 1
            if player.lives > 0:
                print("\nMario died! Lives remaining:", player.lives, "- Respawning...")
                # Respawn at camera position or checkpoint
                respawn_x = max(40.0, cam_x + 16.0)
                player.x = respawn_x
                player.y = 192.0
                player.vx = 0.0
                player.vy = 0.0
                player.is_dead = False
                player.invuln_timer = 90
                player.power = 0
                player.state = 0
            else:
                # Lives reached 0: Game Over
                pass

        # G. Render Base Scene via GPU Engine
        mario_list = [
            float(player.x),
            float(player.y),
            float(player.vx),
            float(player.vy),
            player.facing,
            player.on_ground,
            player.is_dead,
            player.state,
        ]

        hud_dict = {
            "score": player.score,
            "coins": player.coins,
            "time": player.time_left,
            "world": "1-1",
        }

        t_r_start = time.time()
        GUIEngine.render_game_scene(
            frame_buffer,
            WIDTH,
            HEIGHT,
            cam_x,
            cam_y,
            mario_list,
            all_entities,
            tiles,
            level_1_1.LEVEL_WIDTH,
            level_1_1.LEVEL_HEIGHT,
            hud_dict,
            anim_time
        )

        # H. Render Authentic Enemies & Power-Ups Overlays
        for ent in all_entities:
            e_type = ent[0]
            if e_type == 0:
                continue
            sx = ent[1] - cam_x
            sy = ent[2] - cam_y

            if e_type == 3: # Koopa Troopa
                draw_koopa(frame_buffer, WIDTH, HEIGHT, sx, sy, ent[3], ent[5])
            elif e_type == 4: # Flagpole Cloth
                draw_flag(frame_buffer, WIDTH, HEIGHT, sx, sy)
            elif e_type == 5: # Piranha Plant
                draw_piranha(frame_buffer, WIDTH, HEIGHT, sx, sy)
            elif e_type == 6: # Fireball
                draw_fireball(frame_buffer, WIDTH, HEIGHT, sx, sy)
            elif e_type == 7: # Super Mushroom
                draw_mushroom(frame_buffer, WIDTH, HEIGHT, sx, sy)
            elif e_type == 8: # Fire Flower
                draw_flower(frame_buffer, WIDTH, HEIGHT, sx, sy, anim_time)

        # I. Render Power-Up Visual Modifications for Mario
        mx = player.x - cam_x
        my = player.y - cam_y
        if player.power == 2: # Fire Mario (white overalls)
            GUIEngine.draw_rect(frame_buffer, WIDTH, HEIGHT, int(mx + 3.0), int(my), 10, 3, 255.0, 255.0, 255.0, True)
            GUIEngine.draw_rect(frame_buffer, WIDTH, HEIGHT, int(mx + 2.0), int(my + 8.0), 4, 4, 255.0, 255.0, 255.0, True)
        elif player.power == 1: # Super Mario (taller red hat)
            GUIEngine.draw_rect(frame_buffer, WIDTH, HEIGHT, int(mx + 2.0), int(my - 2.0), 12, 3, 216.0, 40.0, 0.0, True)

        # J. Render In-Game HUD Extras (Lives & Autopilot Indicator)
        lives_str = "LIVES " + str(player.lives)
        GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, lives_str, 16, 22, 1, 255.0, 255.0, 255.0)

        GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "WORLD 1-1", 100, 22, 1, 255.0, 224.0, 0.0)

        # Bottom control guide
        GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "WASD:MOVE SPACE:ATK R:RETRY", 16, 228, 1, 200.0, 200.0, 200.0)

        # K. Game Over Screen Overlay
        if player.lives <= 0:
            GUIEngine.draw_rect(frame_buffer, WIDTH, HEIGHT, 40, 80, 176, 60, 0.0, 0.0, 0.0, True)
            GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "GAME OVER", 88, 96, 1, 240.0, 40.0, 40.0)
            GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "PRESS R TO RESTART", 54, 116, 1, 255.0, 255.0, 255.0)

        # L. Victory Celebration Screen Overlay
        if player.is_victory:
            victory_timer += 1
            GUIEngine.draw_rect(frame_buffer, WIDTH, HEIGHT, 30, 70, 196, 75, 0.0, 0.0, 0.0, True)
            GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "STAGE CLEAR!", 78, 84, 1, 255.0, 224.0, 0.0)
            GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "CONGRATULATIONS!", 60, 102, 1, 80.0, 240.0, 80.0)
            GUIEngine.draw_text(frame_buffer, WIDTH, HEIGHT, "PRESS R TO PLAY AGAIN", 42, 122, 1, 255.0, 255.0, 255.0)

        t_r_end = time.time()
        render_ms = (t_r_end - t_r_start) * 1000.0
        screenGUI.record_render_time(render_ms)

        # M. Present GPU Buffer to Desktop Window
        screenGUI.render_buffer(frame_buffer, WIDTH, HEIGHT)

        # N. Precise 60 FPS Pacing
        screenGUI.sleep_until_next_frame(TARGET_FPS)

        # Periodic Log Output
        if frame_count > 0 and frame_count % 180 == 0:
            fps = screenGUI.get_fps()
            print("[Mario Telemetry] Frame:", frame_count, "| Pos X:", int(player.x), "Y:", int(player.y), "| Score:", player.score, "| Lives:", player.lives, "| FPS:", int(fps))

    game_end_time = time.time()
    total_sec = game_end_time - game_start_time

    # 6. Retrieve Final Performance Metrics
    summary = screenGUI.get_benchmark_summary()
    screenGUI.close()

    print("\n=================================================================")
    print("         SUPER MARIO BROS 60 FPS ENGINE SUMMARY                  ")
    print("=================================================================")
    print("Total Frames Rendered & Displayed :", summary["total_frames"])
    print("Total Gameplay Time               :", total_sec, "seconds")
    print("Average Framerate (FPS)           :", summary["avg_fps"], "FPS (Target: 60 FPS)")
    print("Average GPU Render Time per Frame :", summary["avg_render_ms"], "ms")
    print("Average Screen Show Time per Frame:", summary["avg_show_ms"], "ms")
    print("Average CPU Utilization           :", summary["cpu_usage_pct"], "%")
    print("Estimated GPU Compute Load        :", summary["gpu_usage_pct"], "%")
    print("Process Memory Footprint (RSS)    :", summary["memory_rss_mb"], "MB")
    print("Final Mario Score                 :", player.score)
    print("Coins Collected                   :", player.coins)
    print("Lives Left                        :", player.lives)
    print("=================================================================")
    print("\n=== MARIO BROS SESSION FINISHED ===")

main()
