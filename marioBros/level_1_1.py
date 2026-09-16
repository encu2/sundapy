# Mario Bros World 1-1 Full Level Map & Spawn Data
# Level Dimensions: 224 columns x 15 rows (each tile is 16x16 pixels)

LEVEL_WIDTH = 224
LEVEL_HEIGHT = 15

# Tile Constants
AIR = 0
GROUND = 1
QUESTION = 2
EMPTY_BLOCK = 3
BRICK = 4
STONE = 5
PIPE_TL = 6
PIPE_TR = 7
PIPE_BL = 8
PIPE_BR = 9
FLAG_BALL = 10
FLAG_POLE = 11
CASTLE_WALL = 12
CASTLE_TOP = 13
CASTLE_GATE = 14

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

    # 1. Ground Blocks (rows 13 and 14)
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
    place_pipe(tiles, 38, 3)  # Pipe 2 (height 3)
    place_pipe(tiles, 46, 4)  # Pipe 3 (height 4)
    place_pipe(tiles, 57, 4)  # Pipe 4 (height 4)
    place_pipe(tiles, 163, 2) # Pipe 5 (height 2)
    place_pipe(tiles, 179, 2) # Pipe 6 (height 2)

    # 3. Floating Bricks and Question Blocks
    # Introductory Blocks (col 16 to 24)
    set_tile(tiles, 16, 9, QUESTION)
    set_tile(tiles, 20, 9, BRICK)
    set_tile(tiles, 21, 9, QUESTION)
    set_tile(tiles, 22, 9, BRICK)
    set_tile(tiles, 23, 9, QUESTION)
    set_tile(tiles, 24, 9, BRICK)
    set_tile(tiles, 22, 5, QUESTION) # High block

    # Section after Pipe 4 (cols 64 to 80)
    set_tile(tiles, 64, 8, QUESTION) # Hidden / low block
    set_tile(tiles, 77, 9, BRICK)
    set_tile(tiles, 78, 9, QUESTION)
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
    set_tile(tiles, 109, 9, QUESTION)
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
        fill_rect(tiles, x, 13 - (step + 1), x, 12, STONE)

    # Stair 2 (Descending 4 to 1) cols 140 to 143
    for step in range(4):
        x = 140 + step
        fill_rect(tiles, x, 13 - (4 - step), x, 12, STONE)

    # Stair 3 (Ascending 1 to 4) cols 148 to 151
    for step in range(4):
        x = 148 + step
        fill_rect(tiles, x, 13 - (step + 1), x, 12, STONE)
    set_tile(tiles, 152, 9, STONE)
    set_tile(tiles, 152, 10, STONE)
    set_tile(tiles, 152, 11, STONE)
    set_tile(tiles, 152, 12, STONE)

    # Stair 4 (Descending 4 to 1) cols 155 to 158
    for step in range(4):
        x = 155 + step
        fill_rect(tiles, x, 13 - (4 - step), x, 12, STONE)

    # Final Flagpole Staircase (height 1 to 8) cols 181 to 188
    for step in range(8):
        x = 181 + step
        fill_rect(tiles, x, 13 - (step + 1), x, 12, STONE)
    # Platform under pole
    fill_rect(tiles, 189, 5, 189, 12, STONE)

    # 5. Flagpole (col 198)
    set_tile(tiles, 198, 12, STONE) # Base block
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

def get_goomba_spawns():
    # World 1-1 Iconic Goomba spawn x-coordinates (in tile columns)
    # Y is placed at ground level (12 * 16 = 192)
    spawn_cols = [
        22, 40, 51, 52.5,
        80, 82, 97, 98.5,
        114, 115.5, 124, 125.5,
        128, 130, 174, 175.5
    ]
    spawns = []
    for col in spawn_cols:
        # [type=1 (Goomba), x, y, state=0 (alive), anim_frame=0, facing=-1]
        spawns.append([1, col * 16.0, 192.0, 0, 0, -1])
    return spawns
