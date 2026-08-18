# TEST PURPOSE: Verify that a #strict scope functions perfectly when all variables are statically typed (Kasta 1).
# EXPECTED RESULT: PASS

def calculate_discount(price: f64) -> f64:
    #strict
    
    # Fully static, zero-overhead variables
    const discount_rate: f64 = 0.20
    discount_amount: f64 = price * discount_rate
    
    return price - discount_amount

final_price: f64 = calculate_discount(500.0)
print("Final Price:", final_price)
