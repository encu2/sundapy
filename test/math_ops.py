def multiply(a, b):
    return a * b

class Calculator:
    def __init__(self, multiplier):
        self.multiplier = multiplier
        
    def run(self, val):
        return multiply(val, self.multiplier)
