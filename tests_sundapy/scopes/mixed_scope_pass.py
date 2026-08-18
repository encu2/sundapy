# TEST PURPOSE: Verify that dynamic (Pythonic) and static (Strict) scopes can coexist in the same file seamlessly.
# EXPECTED RESULT: PASS

# --- Global Scope (Dynamic) ---
counter = 0

def increment_dynamic():
    global counter
    counter = 1
    # Type can change dynamically globally
    counter = "updates"

# --- Isolated Strict Function (Static) ---
def compute_heavy_math(a: i64, b: i64) -> i64:
    #strict
    # This block runs at native C/Rust speed
    result: i64 = a * b
    return result

increment_dynamic()
print("Dynamic Counter:", counter)

# Mixing scopes
fast_result: i64 = compute_heavy_math(1000, 5000)
print("Fast Math Result:", fast_result)
