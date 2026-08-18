#strict
# TEST PURPOSE: Verify that within a global #strict mode, attempting to re-initialize an existing variable with another type or without a type fails. Also tests that type shadowing/redeclaration is caught.
# EXPECTED RESULT: ERROR (Compile-time Strict Violation / Redeclaration Error)

# Valid static declaration
user_id: u32 = 1001

# Attempting to re-initialize or redeclare the same variable name with a new type
# Strict mode forbids changing types of a variable in the same scope, and explicitly forbids redeclarations.
user_id: str = "ID-1001" # This line should trigger a strict redeclaration/type mismatch error
