# TEST PURPOSE: Verify that dynamic variables (Kasta 2) can freely change types without error.
# EXPECTED RESULT: PASS

# Initial assignment as Integer
score = 100
print("Score (int):", score)

# Reassign to Float
score = 99.5
print("Score (float):", score)

# Reassign to String
score = "Excellent"
print("Score (string):", score)

# Reassign to List
score = [1, 2, 3]
print("Score (list):", score)
