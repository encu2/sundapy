records_processed = 0
errors = 0

def process_record(record):
    global records_processed
    global errors
    try:
        status = record.split("-")[0]
        value = record.split("-")[1]
        
        match status:
            case "OK":
                records_processed = records_processed + 1
                return value.upper()
            case "WARN" | "ERR":
                errors = errors + 1
                return "FAILED"
            case _:
                return "UNKNOWN"
    except Exception as e:
        errors = errors + 1
        return "ERROR"

def get_stats():
    global records_processed
    global errors
    return "Processed " + str(records_processed) + " with " + str(errors) + " errors"

print(process_record("OK-data1"))
print(process_record("WARN-data2"))
print(process_record("ERR-data3"))
print(process_record("INVALID"))
print(get_stats())
