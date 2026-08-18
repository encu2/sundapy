#strict
# TEST PURPOSE: Verify that control flow with strict mode catches dynamic type mixing errors.
# EXPECTED RESULT: ERROR (Compilation failure due to type mismatch in strict mode)

def get_status(code: int) -> int:
    status: int = 0
    if code == 1:
        status = 200
    elif code == 2:
        status = 404
    else:
        status = "Unknown"  # Error! Trying to mix int and string in strict mode
        
    return status

print(get_status(1))
