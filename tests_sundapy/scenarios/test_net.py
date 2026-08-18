import socket
import requests

def test_socket():
    print("Testing socket...")
    s = socket.socket(0, socket.SOCK_STREAM)
    s.connect(["example.com", 80])
    s.send("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
    data = s.recv(1024)
    print("Socket received:")
    # Just print the first 15 characters to verify it worked (e.g. HTTP/1.1 200 OK)
    print(data.split("\r\n")[0])
    s.close()

def test_requests():
    print("Testing requests...")
    resp = requests.get("http://example.com")
    print("Status code:")
    print(resp.status_code)
    # Check if text contains "Example Domain"
    if len(resp.text.split("Example Domain")) > 1:
        print("Requests success!")
    else:
        print("Requests failed to get expected text")

def main():
    test_socket()
    test_requests()

main()
