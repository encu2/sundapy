import numpy as np

def run_test():
    # Numpy array creation
    a = np.array([10, 20, 30, 40])
    
    # Element-wise math
    b = a * 5
    
    # Validation
    val1 = b[0]
    val2 = b[3]
    
    print("Array length:", 4) # len not supported natively yet on NumpyArray
    print("b[0] = ", val1)
    print("b[3] = ", val2)
    
    if val1 == 50 and val2 == 200:
        print("Numpy native MCU optimization passed!")
    else:
        print("Failed!")

run_test()
