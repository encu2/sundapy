class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return self.name

class Dog(Animal):
    def bark(self):
        return "Woof!"

class Cat(Animal):
    def speak(self):
        return "Meow!"

d: Dog = Dog("Buddy")
c: Cat = Cat("Kitty")
print(d.name)
print(d.speak())
print(d.bark())
print(c.name)
print(c.speak())
