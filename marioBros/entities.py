# =============================================================================
#   SUNDAPY SUPER MARIO BROS - ENTITY SIMULATION & AI ENGINE
# =============================================================================
import level_1_1
import physics

def update_entities(entities, tiles, cam_x, player_x):
    cam_left = cam_x - 32.0
    cam_right = cam_x + 288.0

    walk_speed = 0.0
    next_x = 0.0
    facing_offset = 0.0
    check_x = 0
    check_y = 0
    floor_y = 0
    t_mid = 0
    t_floor = 0
    t_ground = 0
    t_wall = 0
    slide_vx = 0.0
    timer = 0
    base_y = 0.0
    max_y = 0.0
    dist_to_mario = 0.0
    fb_vx = 0.0
    fb_vy = 0.0
    m_vx = 0.0
    m_vy = 0.0
    wall_x = 0
    ex = 0.0
    ey = 0.0
    state = 0
    anim = 0
    facing = 0
    e_type = 0
    i = 0
    j = 0
    o_type = 0
    t_type = 0

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

        # ---------------------------------------------------------------------
        # 1. Little Goombas (type 1)
        # ---------------------------------------------------------------------
        if e_type == 1:
            if state == 0: # Alive & Walking
                if ex >= cam_left and ex <= cam_right:
                    ent[4] = (anim + 1) % 40
                    walk_speed = 0.6 * float(facing)
                    next_x = ex + walk_speed

                    facing_offset = 14.0 if facing > 0 else 2.0
                    check_x = int((next_x + facing_offset) / 16.0)
                    t_mid = physics.get_tile(tiles, check_x, int((ey + 8.0) / 16.0))
                    if physics.is_solid(t_mid):
                        ent[5] = -facing
                    else:
                        ent[1] = next_x

                    floor_y = int((ey + 16.0) / 16.0)
                    t_floor = physics.get_tile(tiles, int((ex + 8.0) / 16.0), floor_y)
                    if physics.is_solid(t_floor) == False:
                        ent[2] += 2.5
                        if ent[2] > 240.0:
                            ent[0] = 0
                            i += 1
                            continue
            elif state == 1: # Squashed
                ent[4] += 1
                if ent[4] >= 24:
                    ent[0] = 0
                    i += 1
                    continue

        # ---------------------------------------------------------------------
        # 2. Bouncing Coin (type 2)
        # ---------------------------------------------------------------------
        elif e_type == 2:
            ent[4] = (anim + 1) % 16
            ent[2] -= 1.6
            ent[3] = state + 1
            if ent[3] >= 22:
                ent[0] = 0
                i += 1
                continue

        # ---------------------------------------------------------------------
        # 3. Koopa Troopas (type 3 - Green Turtles)
        # ---------------------------------------------------------------------
        elif e_type == 3:
            if state == 0: # Walking
                if ex >= cam_left and ex <= cam_right:
                    ent[4] = (anim + 1) % 40
                    walk_speed = 0.5 * float(facing)
                    next_x = ex + walk_speed

                    facing_offset = 14.0 if facing > 0 else 2.0
                    check_x = int((next_x + facing_offset) / 16.0)
                    t_mid = physics.get_tile(tiles, check_x, int((ey + 8.0) / 16.0))
                    if physics.is_solid(t_mid):
                        ent[5] = -facing
                    else:
                        ent[1] = next_x

                    floor_y = int((ey + 16.0) / 16.0)
                    t_floor = physics.get_tile(tiles, int((ex + 8.0) / 16.0), floor_y)
                    if physics.is_solid(t_floor) == False:
                        ent[2] += 2.5
                        if ent[2] > 240.0:
                            ent[0] = 0
                            i += 1
                            continue
            elif state == 1: # Motionless Shell
                floor_y = int((ey + 16.0) / 16.0)
                t_floor = physics.get_tile(tiles, int((ex + 8.0) / 16.0), floor_y)
                if physics.is_solid(t_floor) == False:
                    ent[2] += 2.5
                    if ent[2] > 240.0:
                        ent[0] = 0
                        i += 1
                        continue
            elif state == 2: # Sliding Shell
                slide_vx = ent[6]
                next_x = ex + slide_vx
                facing_offset = 14.0 if slide_vx > 0.0 else 2.0
                check_x = int((next_x + facing_offset) / 16.0)
                t_mid = physics.get_tile(tiles, check_x, int((ey + 8.0) / 16.0))
                if physics.is_solid(t_mid):
                    ent[6] = -slide_vx
                    ent[5] = -facing
                else:
                    ent[1] = next_x

                floor_y = int((ey + 16.0) / 16.0)
                t_floor = physics.get_tile(tiles, int((ex + 8.0) / 16.0), floor_y)
                if physics.is_solid(t_floor) == False:
                    ent[2] += 2.5
                    if ent[2] > 240.0:
                        ent[0] = 0
                        i += 1
                        continue

                # Shell defeats other enemies in path
                j = 0
                while j < len(entities):
                    if j != i:
                        other = entities[j]
                        o_type = other[0]
                        if (o_type == 1 or o_type == 3) and other[3] == 0:
                            if abs(other[1] - ent[1]) < 14.0 and abs(other[2] - ent[2]) < 14.0:
                                other[3] = 1
                    j += 1

        # ---------------------------------------------------------------------
        # 4. Flagpole Cloth (type 4)
        # ---------------------------------------------------------------------
        elif e_type == 4:
            if state == 1:
                if ey < 192.0:
                    ent[2] += 2.5
                else:
                    ent[2] = 192.0
                    ent[3] = 2

        # ---------------------------------------------------------------------
        # 5. Piranha Plants (type 5)
        # ---------------------------------------------------------------------
        elif e_type == 5:
            timer = ent[4]
            base_y = ent[6]
            max_y = ent[7]
            dist_to_mario = abs(player_x - ex)

            if state == 0:
                if timer > 0:
                    ent[4] = timer - 1
                else:
                    if dist_to_mario > 32.0:
                        ent[3] = 1
            elif state == 1:
                ent[2] -= 1.0
                if ent[2] <= max_y:
                    ent[2] = max_y
                    ent[3] = 2
                    ent[4] = 50
            elif state == 2:
                if timer > 0:
                    ent[4] = timer - 1
                else:
                    ent[3] = 3
            elif state == 3:
                ent[2] += 1.0
                if ent[2] >= base_y:
                    ent[2] = base_y
                    ent[3] = 0
                    ent[4] = 60

        # ---------------------------------------------------------------------
        # 6. Fireball (type 6)
        # ---------------------------------------------------------------------
        elif e_type == 6:
            fb_vx = ent[6]
            fb_vy = ent[7]
            ent[1] += fb_vx
            ent[7] += 0.45
            ent[2] += ent[7]

            check_y = int((ent[2] + 8.0) / 16.0)
            check_x = int((ent[1] + 4.0) / 16.0)
            t_ground = physics.get_tile(tiles, check_x, check_y)
            if physics.is_solid(t_ground):
                ent[2] = float(check_y * 16 - 8)
                ent[7] = -3.6

            t_wall = physics.get_tile(tiles, int((ent[1] + (8.0 if fb_vx > 0 else 0.0)) / 16.0), int(ent[2] / 16.0))
            if physics.is_solid(t_wall):
                ent[0] = 0
                i += 1
                continue

            ent[4] += 1
            if ent[4] > 110 or ent[2] > 240.0 or ent[1] < cam_left or ent[1] > cam_right:
                ent[0] = 0
                i += 1
                continue

            j = 0
            while j < len(entities):
                if j != i:
                    target = entities[j]
                    t_type = target[0]
                    if t_type == 1 and target[3] == 0:
                        if abs(target[1] - ent[1]) < 12.0 and abs(target[2] - ent[2]) < 12.0:
                            target[3] = 1
                            ent[0] = 0
                            break
                    elif t_type == 3 and target[3] == 0:
                        if abs(target[1] - ent[1]) < 12.0 and abs(target[2] - ent[2]) < 12.0:
                            target[3] = 1
                            ent[0] = 0
                            break
                    elif t_type == 5 and target[2] < target[6] - 2.0:
                        if abs(target[1] - ent[1]) < 14.0 and abs(target[2] - ent[2]) < 14.0:
                            target[2] = target[6]
                            target[3] = 0
                            target[4] = 120
                            ent[0] = 0
                            break
                j += 1

        # ---------------------------------------------------------------------
        # 7. Super Mushroom (type 7)
        # ---------------------------------------------------------------------
        elif e_type == 7:
            m_vx = ent[6]
            m_vy = ent[7]
            ent[1] += m_vx
            ent[7] += 0.40
            ent[2] += ent[7]

            check_y = int((ent[2] + 16.0) / 16.0)
            check_x = int((ent[1] + 8.0) / 16.0)
            t_floor = physics.get_tile(tiles, check_x, check_y)
            if physics.is_solid(t_floor):
                ent[2] = float(check_y * 16 - 16)
                ent[7] = 0.0

            wall_x = int((ent[1] + (16.0 if m_vx > 0 else 0.0)) / 16.0)
            t_wall = physics.get_tile(tiles, wall_x, int((ent[2] + 8.0) / 16.0))
            if physics.is_solid(t_wall):
                ent[6] = -m_vx

            if ent[2] > 240.0:
                ent[0] = 0
                i += 1
                continue

        # ---------------------------------------------------------------------
        # 8. Fire Flower (type 8)
        # ---------------------------------------------------------------------
        elif e_type == 8:
            ent[4] = (anim + 1) % 30

        i += 1
