
val = "test"
match val:
    case "hello":
        print("1")
    case "test" | "run":
        print("Matched test")
    case _:
        print("Fallback")
