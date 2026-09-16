# =============================================================================
#   SUNDAPY SUPER MARIO BROS - SPEEDRUNNER AI AGENT
# =============================================================================
import level_1_1

class SpeedrunnerAI:
    def __init__(self):
        self.autopilot = False
        self.jump_hold_timer = 0
        self.attack_timer = 0

    def compute_input(self, px, py, entities, human_input):
        # 1. Manual Human Control is primary
        if not self.autopilot:
            return human_input

        # 2. Autonomous Speedrunner Agent (when autopilot toggled on)
        cmd = {
            "left": False,
            "right": True,   # Full throttle forward
            "up": False,
            "down": False,
            "jump": False,
            "run": True,     # Sprint active
            "attack": False,
        }

        should_jump = False

        # A. Pipe Obstacles (timed sprint jumps)
        if px >= 400.0 and px <= 444.0:
            should_jump = True
        elif px >= 550.0 and px <= 604.0:
            should_jump = True
        elif px >= 676.0 and px <= 732.0:
            should_jump = True
        elif px >= 850.0 and px <= 908.0:
            should_jump = True

        # B. Bottomless Pits
        elif px >= 1070.0 and px <= 1110.0:
            should_jump = True
        elif px >= 1335.0 and px <= 1380.0:
            should_jump = True

        # C. Question Blocks
        elif px >= 250.0 and px <= 265.0:
            should_jump = True
        elif px >= 340.0 and px <= 360.0:
            should_jump = True

        # D. High Stairways
        elif px >= 2100.0 and px <= 2140.0:
            should_jump = True
        elif px >= 2330.0 and px <= 2364.0:
            should_jump = True

        # E. Final Stairway & Flagpole Jump
        elif px >= 2880.0 and px <= 2900.0:
            should_jump = True
        elif px >= 2980.0 and px <= 3010.0:
            should_jump = True
        elif px >= 3020.0 and px <= 3030.0:
            should_jump = True

        # F. Enemy Reaction: Jump or Attack
        for ent in entities:
            e_type = ent[0]
            if (e_type == 1 or e_type == 3) and ent[3] == 0:
                dist = ent[1] - px
                if dist > 0.0 and dist < 32.0:
                    should_jump = True
                    cmd["attack"] = True

        # Jump duration holding for 60 FPS
        if should_jump:
            self.jump_hold_timer = 12

        if self.jump_hold_timer > 0:
            self.jump_hold_timer -= 1
            cmd["jump"] = True

        return cmd
