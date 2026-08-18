def add(a, b):
    return a + b

class MyHelper:
    def __init__(self, prefix):
        self.prefix = prefix
        
    def greet(self, name):
        return self.prefix + " " + name
