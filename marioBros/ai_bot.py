# Frame-Perfect Autonomous Speedrunner AI Agent for World 1-1
import level_1_1

class SpeedrunnerAI:
    def __init__(self):
        self.manual_override = False
        self.jump_hold_timer = 0

    def compute_input(self, px, py, entities, human_input):
        # 1. Check for manual override from player
        if human_input.get("any_key"):
            self.manual_override = True
            return human_input

        if self.manual_override:
            return human_input

        # 2. Autonomous Speedrunner Agent
        cmd = {
            "left": False,
            "right": True,   # Full throttle forward
            "up": False,
            "down": False,
            "jump": False,
            "run": True,     # Sprint active
        }

        should_jump = False

        # A. Pipe Obstacles (timed sprint jumps)
        # Pipe 1 (x=448)
        if px >= 400.0 and px <= 444.0:
            should_jump = True
        # Pipe 2 (x=608)
        elif px >= 550.0 and px <= 604.0:
            should_jump = True
        # Pipe 3 (x=736)
        elif px >= 676.0 and px <= 732.0:
            should_jump = True
        # Pipe 4 (x=912)
        elif px >= 850.0 and px <= 908.0:
            should_jump = True

        # B. Bottomless Pits
        # Pit 1 (cols 69-70, x=1104)
        elif px >= 1070.0 and px <= 1110.0:
            should_jump = True
        # Pit 2 (cols 86-88, x=1376)
        elif px >= 1335.0 and px <= 1380.0:
            should_jump = True

        # C. Question Blocks for bonus coins
        elif px >= 250.0 and px <= 265.0:
            should_jump = True
        elif px >= 340.0 and px <= 360.0:
            should_jump = True

        # D. High Block Bridge Stairways
        # Stairway 1 (x=2144)
        elif px >= 2100.0 and px <= 2140.0:
            should_jump = True
        # Stairway 2 (x=2368)
        elif px >= 2330.0 and px <= 2364.0:
            should_jump = True

        # E. Final Stairway & Flagpole Jump (x=2896 to 3168)
        elif px >= 2880.0 and px <= 2900.0:
            should_jump = True
        elif px >= 2980.0 and px <= 3010.0:
            should_jump = True
        elif px >= 3020.0 and px <= 3030.0: # High leap for top of flagpole!
            should_jump = True

        # F. Goomba Proximity Jump Reaction
        for ent in entities:
            if ent[0] == 1 and ent[3] == 0: # Living Goomba
                gx = ent[1]
                dist = gx - px
                if dist > 0.0 and dist < 36.0:
                    should_jump = True

        # Jump Duration & Holding Logic (for maximum height)
        if should_jump:
            self.jump_hold_timer = 18 # Hold jump button for 18 frames (~150ms)

        if self.jump_hold_timer > 0:
            self.jump_hold_timer -= 1
            cmd["jump"] = True

        return cmd
