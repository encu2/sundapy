#strict
# TEST PURPOSE: Verify the syntax and parsability of all Sundapy extended custom datatypes (i8-i1024, f32, f64, strings, dicts, lists).
# EXPECTED RESULT: PASS

# Integer sizes (Zig-powered precision)
tiny_num: i8 = -120
huge_num: i1024 = 9999999999999999999999999999999999999999999999
unsigned_num: u32 = 4294967295

# Floats
pi: f32 = 3.14159
precision_pi: f64 = 3.141592653589793

# Booleans and Strings
is_active: bool = True
greeting: str = "Hello Sundapy Developer"

# Complex Types (Strict mode enforces homogeneous types inside arrays if specified, but for now we test parsing)
# Assuming type annotations for generic lists will look like List[int] or we can let them infer from the static type system later.
# For now, just verifying the standard variables pass strict checks.

print(tiny_num, huge_num, unsigned_num, pi, precision_pi, is_active, greeting)
