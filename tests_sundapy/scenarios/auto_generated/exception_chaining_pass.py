
def func():
    try:
        raise "Error"
    except Exception as e:
        print("Caught")

func()
