def test_exception():
    try:
        raise "Test Error"
    except Exception as e:
        print("Caught exception!")
        # We don't actually support printing 'e' yet in Dynamic, but parsing 'as e' should work.
    finally:
        print("Cleanup done")

test_exception()
