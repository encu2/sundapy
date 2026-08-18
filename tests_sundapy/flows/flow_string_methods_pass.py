def string_methods():
    a = "hello,world"
    
    # split
    parts = a.split(",")
    print(parts)
    
    # join
    joined = "-".join(parts)
    print(joined)
    
    # replace
    replaced = joined.replace("-", " ")
    print(replaced)
    
    # upper
    upper_str = replaced.upper()
    print(upper_str)
    
    # lower
    lower_str = upper_str.lower()
    print(lower_str)

string_methods()
