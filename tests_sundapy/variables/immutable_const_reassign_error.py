# TEST PURPOSE: Verify that variables declared with 'const' cannot be modified.
# EXPECTED RESULT: ERROR (Compile-time Immutability Error)

const MAX_CONNECTIONS: i32 = 100
print("Max Connections:", MAX_CONNECTIONS)

# Attempt to reassign an immutable constant
MAX_CONNECTIONS = 200 # This line should trigger an immutability violation error
