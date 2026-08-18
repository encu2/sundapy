# TEST PURPOSE: Verify that explicitly typed variables (Kasta 1) reject values of different types.
# EXPECTED RESULT: ERROR (Compile-time Type Error)

# Statically typed integer
age: int = 25
print("Age:", age)

# Attempt to assign a string to an integer variable
age = "Twenty Five" # This line should trigger a type mismatch error during semantic analysis
