
def f():
    try:
        print("Try")
        return 1
    except Exception as e:
        pass
    finally:
        print("Finally")

print(f())
