#strict
# TEST PURPOSE: Verify that strict mode catches functions returning different types in different branches.
# EXPECTED RESULT: ERROR (Compilation failure)

def risky_return(x: int) -> int:
    if x > 10:
        return 100
    else:
        return "Small" # Error: returning string instead of int

print(risky_return(5))
