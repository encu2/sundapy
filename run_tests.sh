#!/usr/bin/env bash

rm -rf .cache/

# Warna untuk output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}      SUNDAPY AUTOMATED TEST SUITE        ${NC}"
echo -e "${CYAN}==========================================${NC}"

# Memastikan binary sundapy tersedia
if [ ! -f "./zig-out/bin/sundapy" ]; then
    echo -e "${YELLOW}[!] Binary sundapy tidak ditemukan. Menjalankan zig build...${NC}"
    zig build
    if [ $? -ne 0 ]; then
        echo -e "${RED}[x] Build gagal. Silakan perbaiki error kompilasi zig.${NC}"
        exit 1
    fi
fi

# Variabel statistik
total_tests=0

# Mencari semua file test di dalam tests_sundapy/
for test_file in $(find tests_sundapy -type f -name "*.py" | sort); do
    total_tests=$((total_tests + 1))
    
    filename=$(basename "$test_file")
    
    echo -e "\n${YELLOW}▶ Testing: ${filename}${NC}"
    
    # Menjalankan eksekusi sundapy
    ./zig-out/bin/sundapy "$test_file" -y
    
    exit_code=$?
    
    is_error_test=false
    if [[ "$filename" == *"_error.py"* ]]; then
        is_error_test=true
    fi
    
    if [ "$is_error_test" = true ]; then
        if [ $exit_code -ne 0 ]; then
            echo -e "${GREEN}✔ Berhasil (Error kompilasi terdeteksi sesuai ekspektasi strict mode).${NC}"
        else
            echo -e "${RED}✖ Gagal: Diekspektasikan error tapi program berhasil jalan.${NC}"
        fi
    else
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✔ Selesai tanpa crash infrastruktur.${NC}"
        else
            echo -e "${RED}✖ Terjadi error infrastruktur (Exit Code: $exit_code).${NC}"
        fi
    fi
done

echo -e "\n${CYAN}==========================================${NC}"
echo -e "${GREEN}Selesai menjalankan $total_tests file test.${NC}"
echo -e "${CYAN}==========================================${NC}"
