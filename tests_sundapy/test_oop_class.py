class Animal:
    def __init__(self, name):
        self.name = name
    def speak(self):
        return self.name

a: Animal = Animal("Dog")
print(a.speak())
