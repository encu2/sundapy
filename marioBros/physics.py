# =============================================================================
#   SUNDAPY SUPER MARIO BROS - 60 FPS AUTHENTIC PHYSICS & INTERACTION ENGINE
# =============================================================================
import level_1_1

# 60 FPS Calibrated NES Physics Constants
GRAVITY = 0.52
MAX_FALL_SPEED = 8.0
ACCEL_WALK = 0.20
ACCEL_RUN = 0.38
FRICTION = 0.85
MAX_WALK = 2.6
MAX_RUN = 4.2
JUMP_IMPULSE = -8.8
BOUNCE_IMPULSE = -6.2

def is_solid(tid):
    # Air, Flagpole, and Gate are non-solid
    if tid == level_1_1.AIR or tid == level_1_1.FLAG_BALL or tid == level_1_1.FLAG_POLE or tid == level_1_1.CASTLE_GATE:
        return False
    return True

def get_tile(tiles, tx, ty):
    if tx < 0 or tx >= level_1_1.LEVEL_WIDTH or ty < 0 or ty >= level_1_1.LEVEL_HEIGHT:
        return level_1_1.AIR
    return tiles[ty * level_1_1.LEVEL_WIDTH + tx]

def set_tile(tiles, tx, ty, tid):
    if tx >= 0 and tx < level_1_1.LEVEL_WIDTH and ty >= 0 and ty < level_1_1.LEVEL_HEIGHT:
        tiles[ty * level_1_1.LEVEL_WIDTH + tx] = tid

class Player:
    def __init__(self, x=40.0, y=192.0):
        self.x = x
        self.y = y
        self.vx = 0.0
        self.vy = 0.0
        self.facing = 1       # 1 for Right, -1 for Left
        self.on_ground = True
        self.state = 0        # 0: Idle, 1-3: Walk frames, 4: Jump, 5: Skid, 6: Slide, 7: Dead, 8: Duck
        self.anim_timer = 0.0
        self.invuln_timer = 0
        self.attack_cooldown = 0
        self.power = 0        # 0: Small Mario, 1: Super Mario, 2: Fire Mario
        self.lives = 3
        self.score = 0
        self.coins = 0
        self.time_left = 400
        self.time_ticker = 0
        self.is_dead = False
        self.is_victory = False
        self.flag_sliding = False
        self.castle_walking = False
        self.crouching = False
        self.shoot_fireball = False
        self.pending_spawn_type = 0
        self.pending_spawn_x = 0.0
        self.pending_spawn_y = 0.0

    def handle_damage_or_death(self, pit):
        if pit:
            self.is_dead = True
            self.vy = -7.5
            self.state = 7
            return

        if self.invuln_timer > 0:
            return

        if self.power > 0:
            # Power down from Fire or Super to Small Mario
            self.power = 0
            self.invuln_timer = 90 # 1.5s invulnerability flashing at 60 FPS
        else:
            # Small Mario dies
            self.is_dead = True
            self.vy = -7.5
            self.state = 7

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
        spawn_type = 0
        e_type = 0
        ex = 0.0
        ey = 0.0
        estate = 0
        gx = 0.0
        gy = 0.0
        kx = 0.0
        ky = 0.0
        k_dir = 0
        base_y = 0.0
        want_jump = False
        want_attack = False
        fb_x = 0.0
        fb_y = 0.0
        fb_vx = 0.0

        # 0. State Handlers: Dead, Flag Slide, Castle Walk
        if self.is_dead:
            self.vy += GRAVITY * 0.8
            self.y += self.vy
            self.state = 7
            return

        if self.flag_sliding:
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
            self.state = 1 + (int(self.x * 0.25) % 3)
            self.x += 1.2
            if self.x >= 3270.0:
                self.is_victory = True
            return

        # Countdown Game Timer (decrements every 24 frames at 60 FPS)
        self.time_ticker += 1
        if self.time_ticker >= 24:
            self.time_ticker = 0
            if self.time_left > 0:
                self.time_left -= 1
            else:
                self.handle_damage_or_death(True)

        if self.invuln_timer > 0:
            self.invuln_timer -= 1

        if self.attack_cooldown > 0:
            self.attack_cooldown -= 1

        # 1. Crouch / Duck Check (S key or Down arrow)
        self.crouching = False
        if input_state.get("down") and self.on_ground:
            self.crouching = True

        # 2. Horizontal Movement & Acceleration
        accel = ACCEL_RUN if input_state.get("run") else ACCEL_WALK
        max_spd = MAX_RUN if input_state.get("run") else MAX_WALK

        if self.crouching:
            # Friction when ducking
            self.vx *= 0.75
            if abs(self.vx) < 0.05:
                self.vx = 0.0
        elif input_state.get("left"):
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
        if self.on_ground and self.crouching == False:
            if (self.vx > 0.8 and input_state.get("left")) or (self.vx < -0.8 and input_state.get("right")):
                is_skidding = True

        # 3. Jump Physics (Up arrow or W or Jump key)
        want_jump = input_state.get("up") or input_state.get("jump")
        if want_jump and self.on_ground and self.crouching == False:
            self.vy = JUMP_IMPULSE
            self.on_ground = False

        # Variable jump height: releasing button cuts upward momentum
        if want_jump == False and self.vy < -3.5:
            self.vy *= 0.65

        # 4. Attack Action (Space key)
        want_attack = input_state.get("attack") or input_state.get("space")
        if want_attack and self.attack_cooldown <= 0 and self.crouching == False:
            self.attack_cooldown = 16
            if self.power == 2:
                self.shoot_fireball = True
            else:
                # Melee strike / kick / stomp attack ahead of Mario
                for ent in entities:
                    e_type = ent[0]
                    if e_type == 1 and ent[3] == 0: # Goomba
                        gx = ent[1]
                        gy = ent[2]
                        if (gx - self.x) * float(self.facing) >= 0.0 and abs(gx - self.x) < 22.0 and abs(gy - self.y) < 18.0:
                            ent[3] = 1 # Squashed!
                            self.score += 100
                    elif e_type == 3: # Koopa Troopa
                        kx = ent[1]
                        ky = ent[2]
                        if (kx - self.x) * float(self.facing) >= 0.0 and abs(kx - self.x) < 22.0 and abs(ky - self.y) < 18.0:
                            if ent[3] == 0:
                                ent[3] = 1 # Retreat into shell
                                self.score += 100
                            elif ent[3] == 1:
                                ent[3] = 2 # Kick sliding shell!
                                ent[5] = self.facing
                                ent[6] = 5.5 * float(self.facing)
                                self.score += 400

        # 5. Apply Gravity
        self.vy += GRAVITY
        if self.vy > MAX_FALL_SPEED:
            self.vy = MAX_FALL_SPEED

        # 6. Horizontal Collision Resolution
        self.x += self.vx
        if self.x < 0.0:
            self.x = 0.0
            self.vx = 0.0

        m_top = self.y + 1.0
        m_bot = self.y + 15.0
        m_mid = self.y + 8.0

        if self.vx > 0.0:
            check_x = int((self.x + 14.0) / 16.0)
            t1 = get_tile(tiles, check_x, int(m_top / 16.0))
            t2 = get_tile(tiles, check_x, int(m_mid / 16.0))
            t3 = get_tile(tiles, check_x, int(m_bot / 16.0))
            if is_solid(t1) or is_solid(t2) or is_solid(t3):
                self.x = check_x * 16.0 - 14.0
                self.vx = 0.0
        elif self.vx < 0.0:
            check_x = int((self.x + 2.0) / 16.0)
            t1 = get_tile(tiles, check_x, int(m_top / 16.0))
            t2 = get_tile(tiles, check_x, int(m_mid / 16.0))
            t3 = get_tile(tiles, check_x, int(m_bot / 16.0))
            if is_solid(t1) or is_solid(t2) or is_solid(t3):
                self.x = (check_x + 1) * 16.0 - 2.0
                self.vx = 0.0

        # 7. Vertical Collision Resolution
        self.y += self.vy
        self.on_ground = False

        m_left = self.x + 3.0
        m_right = self.x + 13.0

        if self.vy >= 0.0:
            # Falling Down
            check_y = int((self.y + 16.0) / 16.0)
            t_left = get_tile(tiles, int(m_left / 16.0), check_y)
            t_right = get_tile(tiles, int(m_right / 16.0), check_y)

            if is_solid(t_left) or is_solid(t_right):
                self.y = check_y * 16.0 - 16.0
                self.vy = 0.0
                self.on_ground = True
        else:
            # Jumping Up: Head Bonk Check
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
                tid = get_tile(tiles, hit_x, check_y)
                if tid == level_1_1.QUESTION:
                    set_tile(tiles, hit_x, check_y, level_1_1.EMPTY_BLOCK)
                    spawn_type = level_1_1.get_block_spawn_type(hit_x, check_y, self.power)
                    self.pending_spawn_type = spawn_type
                    self.pending_spawn_x = float(hit_x * 16)
                    self.pending_spawn_y = float((check_y - 1) * 16)
                    if spawn_type == 2:
                        self.score += 200
                        self.coins += 1
                elif tid == level_1_1.BRICK:
                    if self.power > 0:
                        # Super Mario destroys brick!
                        set_tile(tiles, hit_x, check_y, level_1_1.AIR)
                        self.score += 50

        # 8. Flagpole Touch Check (col 198, x = 3168)
        if self.x >= 3164.0 and self.x <= 3176.0 and self.y < 192.0 and self.flag_sliding == False and self.castle_walking == False:
            self.flag_sliding = True
            self.x = 3168.0
            self.vx = 0.0
            self.vy = 0.0
            self.score += 5000
            for ent in entities:
                if ent[0] == 4:
                    ent[3] = 1 # Trigger flag descend

        # 9. Pit Death Check
        if self.y > 240.0 and self.is_dead == False:
            self.handle_damage_or_death(True)

        # 10. Enemy & Interactive Entity Collisions
        for ent in entities:
            e_type = ent[0]
            if e_type == 0:
                continue

            ex = ent[1]
            ey = ent[2]
            estate = ent[3]

            # A. Goomba Interaction
            if e_type == 1 and estate == 0:
                if self.x + 12.0 > ex + 2.0 and self.x + 4.0 < ex + 14.0:
                    if self.y + 16.0 >= ey + 2.0 and self.y + 16.0 <= ey + 12.0 and self.vy > 0.0:
                        # Stomp Goomba!
                        ent[3] = 1 # Squashed
                        self.vy = BOUNCE_IMPULSE
                        self.score += 100
                    elif self.y + 15.0 > ey + 4.0 and self.y < ey + 14.0:
                        self.handle_damage_or_death(False)

            # B. Koopa Troopa Interaction
            elif e_type == 3:
                if self.x + 14.0 > ex and self.x < ex + 14.0:
                    if estate == 0: # Walking Koopa
                        if self.y + 16.0 >= ey + 2.0 and self.y + 16.0 <= ey + 12.0 and self.vy > 0.0:
                            # Stomp into shell!
                            ent[3] = 1 # Motionless shell
                            ent[6] = 0.0
                            self.vy = BOUNCE_IMPULSE
                            self.score += 100
                        elif self.y + 15.0 > ey + 4.0 and self.y < ey + 14.0:
                            self.handle_damage_or_death(False)
                    elif estate == 1: # Motionless Shell
                        if self.y + 15.0 > ey and self.y < ey + 15.0:
                            # Kick the shell!
                            ent[3] = 2 # Sliding shell
                            k_dir = self.facing
                            if self.x > ex:
                                k_dir = -1
                            elif self.x < ex:
                                k_dir = 1
                            ent[5] = k_dir
                            ent[6] = 5.5 * float(k_dir)
                            self.score += 400
                    elif estate == 2: # Sliding Shell
                        if self.y + 16.0 >= ey + 2.0 and self.y + 16.0 <= ey + 12.0 and self.vy > 0.0:
                            # Stomp on sliding shell to stop it
                            ent[3] = 1
                            ent[6] = 0.0
                            self.vy = BOUNCE_IMPULSE
                            self.score += 200
                        elif self.y + 15.0 > ey + 4.0 and self.y < ey + 14.0:
                            self.handle_damage_or_death(False)

            # C. Piranha Plant Interaction
            elif e_type == 5:
                # Dangerous if emerged out of pipe lip (ey < base_y - 2.0)
                base_y = ent[6]
                if ey < base_y - 2.0:
                    if self.x + 12.0 > ex and self.x + 4.0 < ex + 16.0 and self.y + 15.0 > ey and self.y < ey + 20.0:
                        self.handle_damage_or_death(False)

            # D. Super Mushroom (Collect Power-Up)
            elif e_type == 7:
                if self.x + 14.0 > ex and self.x < ex + 14.0 and self.y + 16.0 > ey and self.y < ey + 16.0:
                    ent[0] = 0 # Despawn
                    if self.power < 1:
                        self.power = 1
                    self.score += 1000

            # E. Fire Flower (Collect Power-Up)
            elif e_type == 8:
                if self.x + 14.0 > ex and self.x < ex + 14.0 and self.y + 16.0 > ey and self.y < ey + 16.0:
                    ent[0] = 0 # Despawn
                    self.power = 2 # Fire Mario!
                    self.score += 1000

        # 11. Animation State Update
        if self.on_ground == False:
            self.state = 4 # Jump
        elif self.crouching == True:
            self.state = 8 # Duck
        elif is_skidding:
            self.state = 5 # Skid
        elif abs(self.vx) > 0.1:
            self.anim_timer += abs(self.vx) * 0.14
            walk_idx = (int(self.anim_timer) % 3) + 1
            self.state = walk_idx
        else:
            self.state = 0 # Idle
