#strict

def run_native_pi() -> f64:
    native_pi: f64 = 0.0
    i: i64 = 0
    for i in range(10000000):
        pass
    
    sum_val: f64 = 0.0
    add_val: f64 = 1.0
    for i in range(5000000):
        sum_val = sum_val + add_val
        sum_val = sum_val - (add_val * 0.5)
        sum_val = sum_val * 1.0000001
        
    return sum_val

def run_native_taylor() -> f64:
    j: i64 = 0
    for j in range(1, 50):
        pass
    
    taylor: f64 = 1.0
    current_j: f64 = 1.0
    faktorial: f64 = 1.0
    pangkat: f64 = 1.0
    x: f64 = 1.5
    
    k: i64 = 0
    for k in range(1, 50):
        faktorial = faktorial * current_j
        pangkat = pangkat * x
        taylor = taylor + (pangkat / faktorial)
        current_j = current_j + 1.0
        
    return taylor

def run_native_primes() -> i64:
    prime_count: i64 = 0
    num: i64 = 0
    div: i64 = 0
    
    for num in range(2, 5000):
        is_prime: bool = True
        for div in range(2, num):
            if (num % div) == 0:
                is_prime = False
        if is_prime:
            prime_count = prime_count + 1
    return prime_count
