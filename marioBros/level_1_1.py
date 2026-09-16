# =============================================================================
#   SUNDAPY SUPER MARIO BROS - WORLD 1-1 MAP & SPAWN DATA
# =============================================================================
# Authentic NES World 1-1 layout: 224 columns x 15 rows (16x16 pixels per tile)
# Complete with ground sections, pits, pipes, question blocks, bricks, staircases,
# flagpole, Peach's castle, Goombas, Koopa Troopas, and Piranha Plants.
# =============================================================================

LEVEL_WIDTH = 224
LEVEL_HEIGHT = 15

# Tile IDs (matching NES tileset in GUIEngine)
AIR = 0
GROUND = 1
QUESTION = 2
BRICK = 3
PIPE_TL = 4
PIPE_TR = 5
PIPE_BL = 6
PIPE_BR = 7
FLAG_BALL = 8
FLAG_POLE = 9
CASTLE_WALL = 10
CASTLE_TOP = 11
CASTLE_GATE = 12
EMPTY_BLOCK = 13

def set_tile(tiles, tx, ty, tid):
    if tx >= 0 and tx < LEVEL_WIDTH and ty >= 0 and ty < LEVEL_HEIGHT:
        tiles[ty * LEVEL_WIDTH + tx] = tid

def fill_rect(tiles, x1, y1, x2, y2, tid):
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            set_tile(tiles, x, y, tid)

def place_pipe(tiles, x, height):
    top_y = 13 - height
    set_tile(tiles, x, top_y, PIPE_TL)
    set_tile(tiles, x + 1, top_y, PIPE_TR)
    for y in range(top_y + 1, 13):
        set_tile(tiles, x, y, PIPE_BL)
        set_tile(tiles, x + 1, y, PIPE_BR)

def build_world_1_1():
    # Initialize empty 15 x 224 grid (flattened row-major: y * LEVEL_WIDTH + x)
    tiles = [0] * (LEVEL_WIDTH * LEVEL_HEIGHT)

    # 1. Ground Blocks (rows 13 and 14) with authentic pits
    # Ground Section 1: cols 0 to 68
    fill_rect(tiles, 0, 13, 68, 14, GROUND)
    # Pit 1: cols 69 to 70 (Air)
    # Ground Section 2: cols 71 to 85
    fill_rect(tiles, 71, 13, 85, 14, GROUND)
    # Pit 2: cols 86 to 88 (Air)
    # Ground Section 3: cols 89 to 152
    fill_rect(tiles, 89, 13, 152, 14, GROUND)
    # Pit 3: cols 153 to 154 (Air)
    # Ground Section 4: cols 155 to 223
    fill_rect(tiles, 155, 13, 223, 14, GROUND)

    # 2. Warp Pipes
    place_pipe(tiles, 28, 2)  # Pipe 1 (height 2)
    place_pipe(tiles, 38, 3)  # Pipe 2 (height 3 - Piranha Plant)
    place_pipe(tiles, 46, 4)  # Pipe 3 (height 4 - Piranha Plant)
    place_pipe(tiles, 57, 4)  # Pipe 4 (height 4 - Piranha Plant)
    place_pipe(tiles, 163, 2) # Pipe 5 (height 2 - Piranha Plant)
    place_pipe(tiles, 179, 2) # Pipe 6 (height 2 - Piranha Plant)

    # 3. Floating Bricks and Question Blocks
    # Introductory Blocks (col 16 to 24)
    set_tile(tiles, 16, 9, QUESTION) # Coin
    set_tile(tiles, 20, 9, BRICK)
    set_tile(tiles, 21, 9, QUESTION) # Super Mushroom block!
    set_tile(tiles, 22, 9, BRICK)
    set_tile(tiles, 23, 9, QUESTION) # Coin
    set_tile(tiles, 24, 9, BRICK)
    set_tile(tiles, 22, 5, QUESTION) # High Coin block

    # Section after Pipe 4 (cols 64 to 80)
    set_tile(tiles, 64, 8, QUESTION) # Hidden / low block
    set_tile(tiles, 77, 9, BRICK)
    set_tile(tiles, 78, 9, QUESTION) # Super Mushroom / Fire Flower block!
    set_tile(tiles, 79, 9, BRICK)
    fill_rect(tiles, 80, 5, 87, 5, BRICK) # High brick bridge

    # Double-decker Bricks (cols 91 to 102)
    fill_rect(tiles, 91, 5, 93, 5, BRICK)
    set_tile(tiles, 94, 5, QUESTION)
    fill_rect(tiles, 94, 9, 97, 9, BRICK)
    set_tile(tiles, 100, 9, BRICK)
    set_tile(tiles, 101, 9, BRICK)
    set_tile(tiles, 101, 5, BRICK)

    # Trio Question Blocks (cols 105 to 112)
    set_tile(tiles, 106, 9, QUESTION)
    set_tile(tiles, 109, 9, QUESTION) # Fire Flower block!
    set_tile(tiles, 109, 5, QUESTION)
    set_tile(tiles, 112, 9, QUESTION)
    set_tile(tiles, 118, 9, BRICK)
    fill_rect(tiles, 121, 5, 123, 5, BRICK)

    # High platform blocks (cols 128 to 132)
    set_tile(tiles, 128, 5, BRICK)
    set_tile(tiles, 129, 5, QUESTION)
    set_tile(tiles, 130, 5, QUESTION)
    set_tile(tiles, 131, 5, BRICK)

    # 4. Stone Stairs / Pyramids
    # Stair 1 (Ascending 1 to 4) cols 134 to 137
    for step in range(4):
        x = 134 + step
        fill_rect(tiles, x, 13 - (step + 1), x, 12, BRICK)

    # Stair 2 (Descending 4 to 1) cols 140 to 143
    for step in range(4):
        x = 140 + step
        fill_rect(tiles, x, 13 - (4 - step), x, 12, BRICK)

    # Stair 3 (Ascending 1 to 4) cols 148 to 151
    for step in range(4):
        x = 148 + step
        fill_rect(tiles, x, 13 - (step + 1), x, 12, BRICK)
    set_tile(tiles, 152, 9, BRICK)
    set_tile(tiles, 152, 10, BRICK)
    set_tile(tiles, 152, 11, BRICK)
    set_tile(tiles, 152, 12, BRICK)

    # Stair 4 (Descending 4 to 1) cols 155 to 158
    for step in range(4):
        x = 155 + step
        fill_rect(tiles, x, 13 - (4 - step), x, 12, BRICK)

    # Final Flagpole Staircase (height 1 to 8) cols 181 to 188
    for step in range(8):
        x = 181 + step
        fill_rect(tiles, x, 13 - (step + 1), x, 12, BRICK)
    # Platform under pole
    fill_rect(tiles, 189, 5, 189, 12, BRICK)

    # 5. Flagpole (col 198)
    set_tile(tiles, 198, 12, BRICK) # Base block
    for y in range(3, 12):
        set_tile(tiles, 198, y, FLAG_POLE)
    set_tile(tiles, 198, 2, FLAG_BALL) # Golden top ball

    # 6. Peach's Castle (cols 202 to 207)
    # Castle Body
    fill_rect(tiles, 202, 8, 206, 12, CASTLE_WALL)
    # Crenellations / Battlements
    set_tile(tiles, 202, 7, CASTLE_TOP)
    set_tile(tiles, 204, 7, CASTLE_TOP)
    set_tile(tiles, 206, 7, CASTLE_TOP)
    # Tower
    fill_rect(tiles, 203, 5, 205, 6, CASTLE_WALL)
    set_tile(tiles, 203, 4, CASTLE_TOP)
    set_tile(tiles, 205, 4, CASTLE_TOP)
    # Gate Doorway
    set_tile(tiles, 204, 11, CASTLE_GATE)
    set_tile(tiles, 204, 12, CASTLE_GATE)

    return tiles

def get_initial_entities():
    spawns = []

    # 1. Little Goombas (type 1)
    # [type=1, x, y, state=0 (alive), anim=0, facing=-1, vx=-0.6, vy=0.0]
    goomba_cols = [
        22.0, 40.0, 51.0, 52.5,
        80.0, 82.0, 97.0, 98.5,
        114.0, 115.5, 124.0, 125.5,
        128.0, 130.0, 174.0, 175.5
    ]
    for col in goomba_cols:
        spawns.append([1, col * 16.0, 192.0, 0, 0, -1, -0.6, 0.0])

    # 2. Koopa Troopas (type 3 - Green Patrolling Turtle)
    # [type=3, x, y, state=0 (walking), anim=0, facing=-1, vx=-0.5, vy=0.0]
    # Spawns near row of blocks and final staircase
    spawns.append([3, 107.0 * 16.0, 192.0, 0, 0, -1, -0.5, 0.0])
    spawns.append([3, 178.0 * 16.0, 192.0, 0, 0, -1, -0.5, 0.0])

    # 3. Piranha Plants (type 5 - Inside Pipes)
    # [type=5, x, y, state=0 (hidden), timer=0, facing=0, base_y, max_y]
    # Pipes at cols 38 (h=3), 46 (h=4), 57 (h=4), 163 (h=2), 179 (h=2)
    spawns.append([5, 38.0 * 16.0 + 4.0, (13 - 3) * 16.0, 0, 0, 0, (13 - 3) * 16.0, (13 - 3) * 16.0 - 18.0])
    spawns.append([5, 46.0 * 16.0 + 4.0, (13 - 4) * 16.0, 0, 25, 0, (13 - 4) * 16.0, (13 - 4) * 16.0 - 18.0])
    spawns.append([5, 57.0 * 16.0 + 4.0, (13 - 4) * 16.0, 0, 50, 0, (13 - 4) * 16.0, (13 - 4) * 16.0 - 18.0])
    spawns.append([5, 163.0 * 16.0 + 4.0, (13 - 2) * 16.0, 0, 15, 0, (13 - 2) * 16.0, (13 - 2) * 16.0 - 18.0])
    spawns.append([5, 179.0 * 16.0 + 4.0, (13 - 2) * 16.0, 0, 35, 0, (13 - 2) * 16.0, (13 - 2) * 16.0 - 18.0])

    # 4. Flagpole Cloth (type 4)
    # [type=4, x=3168, y=48, state=0 (idle), anim=0, facing=1, 0, 0]
    spawns.append([4, 3168.0, 48.0, 0, 0, 1, 0.0, 0.0])

    return spawns

def get_goomba_spawns():
    return get_initial_entities()

def get_block_spawn_type(col, row, mario_power):
    # Returns entity type to spawn when question block is hit
    # 7: Super Mushroom, 8: Fire Flower, 2: Coin
    if col == 21 and row == 9:
        if mario_power == 0:
            return 7 # Super Mushroom
        else:
            return 8 # Fire Flower
    elif col == 78 and row == 9:
        if mario_power == 0:
            return 7 # Super Mushroom
        else:
            return 8 # Fire Flower
    elif col == 109 and row == 9:
        return 8 # Fire Flower
    return 2 # Bouncing Coin

