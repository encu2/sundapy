class Dog:
    def bark(self):
        print("Woof")

    def greet(self, name):
        print("Hello")
        print(name)

def test_class_basic():
    d = Dog()
    d.bark()
    d.greet("Sundapy")

test_class_basic()
