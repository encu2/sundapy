
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age
        
    def greet(self):
        return "Hello " + self.name

def main():
    p = Person("Alice", 30)
    print(p.greet())
    
main()
