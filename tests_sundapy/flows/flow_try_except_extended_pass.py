# TEST PURPOSE: Verify robust try/except/finally functionality.
# EXPECTED RESULT: PASS

def test_try_except():
    val = 10
    try:
        raise "Oops"
        val = 20
    except:
        val = 30
    print(val)
    
    status = "running"
    try:
        status = "try_block"
    finally:
        status = "finally_block"
    print(status)

test_try_except()
