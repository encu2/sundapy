# TEST PURPOSE: Verify that within a #strict scope, dynamic variable declarations (Kasta 2) are completely forbidden.
# EXPECTED RESULT: ERROR (Compile-time Strict Violation Error)

def calculate_tax(amount: float) -> float:
    #strict
    
    # Strict mode requires explicit types.
    # Declaring a dynamic variable 'rate' without a type annotation should trigger a fatal error.
    rate = 0.15 
    
    return amount * rate

tax = calculate_tax(100.0)
print(tax)
