# High-Performance 120 FPS Platformer Physics & Collision Engine
import level_1_1

GRAVITY = 0.38
MAX_FALL_SPEED = 7.0
ACCEL_WALK = 0.12
ACCEL_RUN = 0.22
FRICTION = 0.86
MAX_WALK = 2.4
MAX_RUN = 3.8
JUMP_IMPULSE = -7.8
BOUNCE_IMPULSE = -4.8

def is_solid(tid):
    # Air, Flagpole, and Gate are non-solid
    if tid == level_1_1.AIR or tid == level_1_1.FLAG_BALL or tid == level_1_1.FLAG_POLE or tid == level_1_1.CASTLE_GATE:
        return False
    return True

class Player:
    def __init__(self, x=40.0, y=192.0):
        self.x = x
        self.y = y
        self.vx = 0.0
        self.vy = 0.0
        self.facing = 1       # 1 for Right, -1 for Left
        self.on_ground = True
        self.state = 0        # 0: Idle, 1-3: Walk frames, 4: Jump, 5: Skid, 6: Slide, 7: Dead
        self.anim_timer = 0.0
        self.invuln_timer = 0
        self.score = 0
        self.coins = 0
        self.time_left = 400
        self.time_ticker = 0
        self.is_dead = False
        self.is_victory = False
        self.flag_sliding = False
        self.castle_walking = False

    def update(self, input_state, tiles, entities):
        check_x = 0
        check_y = 0
        t1 = 0
        t2 = 0
        t3 = 0
        t_left = 0
        t_right = 0
        tl_x = 0
        tr_x = 0
        hit_tile = False
        hit_x = 0
        m_top = 0.0
        m_bot = 0.0
        m_mid = 0.0
        m_left = 0.0
        m_right = 0.0
        accel = 0.0
        max_spd = 0.0
        is_skidding = False
        walk_idx = 0
        tid = 0
        gx = 0.0
        gy = 0.0

        if self.is_dead:
            # Death arc physics
            self.vy += GRAVITY * 0.8
            self.y += self.vy
            self.state = 7
            return

        if self.flag_sliding:
            # Sliding down flagpole
            self.state = 6
            if self.y < 192.0:
                self.y += 2.0
            else:
                self.y = 192.0
                self.flag_sliding = False
                self.castle_walking = True
                self.facing = 1
            return

        if self.castle_walking:
            # Autowalk into peach's castle
            self.state = 1 + (int(self.x * 0.2) % 3)
            self.x += 1.0
            if self.x >= 3270.0:
                self.is_victory = True
            return

        # Game timer countdown (decrements ~2.5 times per sec at 120 FPS)
        self.time_ticker += 1
        if self.time_ticker >= 48:
            self.time_ticker = 0
            if self.time_left > 0:
                self.time_left -= 1
            else:
                self.is_dead = True

        if self.invuln_timer > 0:
            self.invuln_timer -= 1

        # 1. Horizontal Movement & Acceleration
        accel = ACCEL_RUN if input_state.get("run") else ACCEL_WALK
        max_spd = MAX_RUN if input_state.get("run") else MAX_WALK

        if input_state.get("left"):
            self.vx -= accel
            if self.vx < -max_spd:
                self.vx = -max_spd
            self.facing = -1
        elif input_state.get("right"):
            self.vx += accel
            if self.vx > max_spd:
                self.vx = max_spd
            self.facing = 1
        else:
            self.vx *= FRICTION
            if abs(self.vx) < 0.05:
                self.vx = 0.0

        # Skid detection
        is_skidding = False
        if self.on_ground:
            if (self.vx > 0.8 and input_state.get("left")) or (self.vx < -0.8 and input_state.get("right")):
                is_skidding = True

        # 2. Jump Physics
        if input_state.get("jump") and self.on_ground:
            self.vy = JUMP_IMPULSE
            self.on_ground = False

        # Variable jump height: releasing jump cuts velocity
        if input_state.get("jump") == False and self.vy < -3.0:
            self.vy *= 0.65

        # 3. Apply Gravity
        self.vy += GRAVITY
        if self.vy > MAX_FALL_SPEED:
            self.vy = MAX_FALL_SPEED

        # 4. Horizontal Collision Resolution
        self.x += self.vx
        # Left boundary
        if self.x < 0.0:
            self.x = 0.0
            self.vx = 0.0

        # Tile collision boxes (16x16)
        # Check side collisions
        m_top = self.y + 1.0
        m_bot = self.y + 15.0
        m_mid = self.y + 8.0

        if self.vx > 0.0:
            # Moving Right: check right edge (x + 14)
            check_x = int((self.x + 14.0) / 16.0)
            t1 = get_tile(tiles, check_x, int(m_top / 16.0))
            t2 = get_tile(tiles, check_x, int(m_mid / 16.0))
            t3 = get_tile(tiles, check_x, int(m_bot / 16.0))
            if is_solid(t1) or is_solid(t2) or is_solid(t3):
                self.x = check_x * 16.0 - 14.0
                self.vx = 0.0
        elif self.vx < 0.0:
            # Moving Left: check left edge (x + 2)
            check_x = int((self.x + 2.0) / 16.0)
            t1 = get_tile(tiles, check_x, int(m_top / 16.0))
            t2 = get_tile(tiles, check_x, int(m_mid / 16.0))
            t3 = get_tile(tiles, check_x, int(m_bot / 16.0))
            if is_solid(t1) or is_solid(t2) or is_solid(t3):
                self.x = (check_x + 1) * 16.0 - 2.0
                self.vx = 0.0

        # 5. Vertical Collision Resolution
        self.y += self.vy
        self.on_ground = False

        m_left = self.x + 3.0
        m_right = self.x + 13.0

        if self.vy >= 0.0:
            # Falling Down: check bottom edge (y + 16)
            check_y = int((self.y + 16.0) / 16.0)
            t_left = get_tile(tiles, int(m_left / 16.0), check_y)
            t_right = get_tile(tiles, int(m_right / 16.0), check_y)

            if is_solid(t_left) or is_solid(t_right):
                self.y = check_y * 16.0 - 16.0
                self.vy = 0.0
                self.on_ground = True
        else:
            # Jumping Up: check head bonk (y)
            check_y = int(self.y / 16.0)
            tl_x = int(m_left / 16.0)
            tr_x = int(m_right / 16.0)
            t_left = get_tile(tiles, tl_x, check_y)
            t_right = get_tile(tiles, tr_x, check_y)

            hit_tile = False
            hit_x = tl_x
            if is_solid(t_left):
                hit_tile = True
                hit_x = tl_x
            elif is_solid(t_right):
                hit_tile = True
                hit_x = tr_x

            if hit_tile:
                self.y = (check_y + 1) * 16.0
                self.vy = 0.0
                # Trigger Block Bump
                tid = get_tile(tiles, hit_x, check_y)
                if tid == level_1_1.QUESTION:
                    set_tile(tiles, hit_x, check_y, level_1_1.EMPTY_BLOCK)
                    self.score += 200
                    self.coins += 1

        # 6. Check Flagpole Touch (col 198, x = 3168)
        if self.x >= 3164.0 and self.x <= 3176.0 and self.y < 192.0 and self.flag_sliding == False and self.castle_walking == False:
            self.flag_sliding = True
            self.x = 3168.0
            self.vx = 0.0
            self.vy = 0.0
            self.score += 5000
            # Also find flagpole entity to slide flag
            for ent in entities:
                if ent[0] == 4:
                    ent[3] = 1 # Flag sliding active

        # 7. Pit Death Check
        if self.y > 240.0 and self.is_dead == False:
            self.is_dead = True
            self.vy = -7.0
            self.state = 7

        # 8. Enemy Interaction (Goombas)
        for ent in entities:
            if ent[0] == 1 and ent[3] == 0: # Active Goomba
                gx = ent[1]
                gy = ent[2]
                # AABB overlap
                if (self.x + 12.0 > gx + 2.0 and self.x + 4.0 < gx + 14.0):
                    if (self.y + 16.0 >= gy + 2.0 and self.y + 16.0 <= gy + 12.0 and self.vy > 0.0):
                        # Stomped Goomba!
                        ent[3] = 1 # Squashed
                        self.vy = BOUNCE_IMPULSE
                        self.score += 100
                    elif (self.y + 15.0 > gy + 4.0 and self.y < gy + 14.0):
                        # Side hit -> Player dies
                        if self.invuln_timer <= 0 and self.is_dead == False:
                            self.is_dead = True
                            self.vy = -6.5
                            self.state = 7

        # 9. Animation State Update
        if self.on_ground == False:
            self.state = 4 # Jump
        elif is_skidding:
            self.state = 5 # Skid
        elif abs(self.vx) > 0.1:
            self.anim_timer += abs(self.vx) * 0.08
            walk_idx = (int(self.anim_timer) % 3) + 1
            self.state = walk_idx
        else:
            self.state = 0 # Idle

def get_tile(tiles, tx, ty):
    if tx < 0 or tx >= level_1_1.LEVEL_WIDTH or ty < 0 or ty >= level_1_1.LEVEL_HEIGHT:
        return level_1_1.AIR
    return tiles[ty * level_1_1.LEVEL_WIDTH + tx]

def set_tile(tiles, tx, ty, tid):
    if tx >= 0 and tx < level_1_1.LEVEL_WIDTH and ty >= 0 and ty < level_1_1.LEVEL_HEIGHT:
        tiles[ty * level_1_1.LEVEL_WIDTH + tx] = tid
