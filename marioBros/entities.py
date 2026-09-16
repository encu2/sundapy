# Entity Update & AI Simulation for Goombas, Coins, and Flag
import level_1_1
import physics

def update_entities(entities, tiles, cam_x):
    # Active range: only update entities within camera screen range
    cam_left = cam_x - 32.0
    cam_right = cam_x + 288.0

    walk_speed = 0.0
    next_x = 0.0
    check_x = 0
    t_mid = 0
    floor_y = 0
    t_floor = 0
    facing_offset = 0.0

    i = 0
    while i < len(entities):
        ent = entities[i]
        e_type = ent[0]
        if e_type == 0:
            i += 1
            continue

        ex = ent[1]
        ey = ent[2]
        state = ent[3]
        anim = ent[4]
        facing = ent[5]

        # 1. Goomba (type 1)
        if e_type == 1:
            if state == 0: # Alive & Walking
                # Check if in camera active zone
                if ex >= cam_left and ex <= cam_right:
                    # Animate waddle
                    ent[4] = (anim + 1) % 40
                    # Horizontal walk: 0.6 pixel per frame
                    walk_speed = 0.6 * float(facing)
                    next_x = ex + walk_speed

                    # Check wall collision ahead
                    facing_offset = 14.0 if facing > 0 else 2.0
                    check_x = int((next_x + facing_offset) / 16.0)
                    t_mid = physics.get_tile(tiles, check_x, int((ey + 8.0) / 16.0))
                    if physics.is_solid(t_mid):
                        # Turn around
                        ent[5] = -facing
                    else:
                        ent[1] = next_x

                    # Gravity / Floor collision
                    floor_y = int((ey + 16.0) / 16.0)
                    t_floor = physics.get_tile(tiles, int((ex + 8.0) / 16.0), floor_y)
                    if physics.is_solid(t_floor) == False:
                        ent[2] += 2.5 # Fall down pit
                        if ent[2] > 240.0:
                            # Pit death, deactivate entity
                            ent[0] = 0
                            i += 1
                            continue
            elif state == 1: # Squashed
                # Stay flat for 30 frames, then remove
                ent[4] += 1
                if ent[4] >= 30:
                    ent[0] = 0
                    i += 1
                    continue

        # 2. Bouncing Coin (type 2)
        elif e_type == 2:
            # Spin coin animation
            ent[4] = (anim + 1) % 16
            # Arc upward then disappear
            ent[2] -= 1.8
            state += 1
            ent[3] = state
            if state >= 24: # Disappear after 24 frames
                ent[0] = 0
                i += 1
                continue

        # 3. Flag (type 4) on Pole
        elif e_type == 4:
            if state == 1: # Sliding down
                if ey < 192.0:
                    ent[2] += 2.0
                else:
                    ent[2] = 192.0
                    ent[3] = 2 # At bottom

        i += 1
