import requests
from bs4 import BeautifulSoup

def run_test():
    url = 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/export'
    
    # Mengambil konten HTML dari URL
    response = requests.get(url)
    if response.status_code != 200:
        print("Failed to fetch URL", response.status_code)
        return

    # Parsing HTML menggunakan BeautifulSoup
    soup = BeautifulSoup(response.text, 'html.parser')
    counter = 0

    # Ekstrak tag h1-h6
    print("Daftar Heading (h1-h6):")
    for i in range(1, 7):
        for heading in soup.find_all(f'h{i}'):
            # print("-", heading.get_text(strip=True))
            counter += 1
    
    print(f"Total head ==> {counter}")

    print("\n------------------\n")

    counter = 0
    # Ekstrak nilai atribut href pada tag a
    print("Daftar Tautan (href):")
    for a_tag in soup.find_all('a', href=True):
        # print("-", a_tag['href'])
        counter += 1
    
    print(f"Total link ==> {counter}")

if __name__ == "__main__":
    run_test()
