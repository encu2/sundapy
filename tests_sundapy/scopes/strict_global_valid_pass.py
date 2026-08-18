#strict
# TEST PURPOSE: Verify that a global #strict directive forces the entire file to use static typing, and valid static code passes.
# EXPECTED RESULT: PASS

const APP_NAME: str = "Sundapy High Performance Mode  "
const VERSION_MAJOR: u8 = 1
const VERSION_MINOR: u8 = 0

def init_system() -> bool:
    is_ready: bool = True
    return is_ready

system_state: bool = init_system()
print(APP_NAME, "Version", VERSION_MAJOR, ".", VERSION_MINOR)
print("System Ready:", system_state)
