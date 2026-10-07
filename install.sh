#!/usr/bin/env bash
# ==============================================================================
#           SundaPy Compiler & Runtime Installer
# ==============================================================================
# Skrip instalasi dan kompilasi mandiri untuk SundaPy & SundaFetch.
# Mendukung berbagai profil optimasi rilis (ReleaseSmall, ReleaseFast, Debug).
# ==============================================================================

set -e

# Warna Terminal
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Default Konfigurasi
OPTIMIZE_MODE=""
AUTO_YES=false
INSTALL_DIR="$HOME/.local/bin"

show_help() {
    echo -e "${BOLD}Penggunaan:${NC}"
    echo -e "  ./install.sh [OPSI...]\n"
    echo -e "${BOLD}Opsi Profil Rilis:${NC}"
    echo -e "  -s, --small, --release-small   Kompilasi mode ReleaseSmall (${GREEN}Rekomendasi default${NC}, binary ~1.1 MB)"
    echo -e "  -f, --fast,  --release-fast    Kompilasi mode ReleaseFast (Kecepatan eksekusi maksimal, binary ~1.8 MB)"
    echo -e "  -d, --debug                    Kompilasi mode Debug (Sertakan DWARF stack trace, binary ~33 MB)\n"
    echo -e "${BOLD}Opsi Instalasi:${NC}"
    echo -e "  -y, --yes                      Instal otomatis ke direktori target tanpa prompt konfirmasi"
    echo -e "  -p, --prefix <DIR>             Tentukan direktori target instalasi (Default: ~/.local/bin)"
    echo -e "  -h, --help                     Tampilkan panduan bantuan ini\n"
    echo -e "${BOLD}Contoh Penggunaan:${NC}"
    echo -e "  ./install.sh                           # Mode interaktif (pilih profil via menu)"
    echo -e "  ./install.sh -s -y                     # Instal otomatis mode ReleaseSmall (~1.1 MB)"
    echo -e "  ./install.sh -f -y                     # Instal otomatis mode ReleaseFast (~1.8 MB)"
    echo -e "  ./install.sh -d                        # Kompilasi mode Debug untuk pengembangan"
    echo -e "  ./install.sh -p /usr/local/bin -y      # Instal ke direktori sistem (butuh izin write)"
    exit 0
}

# Parsing Argumen CLI
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--small|--release-small)
            OPTIMIZE_MODE="ReleaseSmall"
            shift
            ;;
        -f|--fast|--release-fast)
            OPTIMIZE_MODE="ReleaseFast"
            shift
            ;;
        -d|--debug)
            OPTIMIZE_MODE="Debug"
            shift
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -p|--prefix)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}[x] Opsi tidak dikenal: $1${NC}"
            echo -e "Gunakan ${YELLOW}./install.sh --help${NC} untuk melihat daftar opsi yang tersedia."
            exit 1
            ;;
    esac
done

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}${BOLD}       SundaPy Compiler Builder & Installer${NC}"
echo -e "${CYAN}======================================================${NC}"

# 1. Cek dependencies
echo -e "\n${BOLD}[1/4] Memeriksa Prasyarat Sistem...${NC}"
if ! command -v zig &> /dev/null; then
    echo -e "${RED}[!] Zig compiler tidak ditemukan! Harap pasang Zig (versi 0.16.0 direkomendasikan).${NC}"
    exit 1
fi
ZIG_VER=$(zig version)
echo -e "  ${GREEN}✔${NC} Zig Compiler: ${CYAN}v${ZIG_VER}${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[!] Python3 tidak ditemukan! Harap pasang Python 3.${NC}"
    exit 1
fi
PY_VER=$(python3 --version | cut -d' ' -f2)
echo -e "  ${GREEN}✔${NC} Python: ${CYAN}v${PY_VER}${NC}"

# 2. Pemilihan Mode Optimasi (Jika belum ditentukan lewat argumen)
if [ -z "$OPTIMIZE_MODE" ]; then
    echo -e "\n${BOLD}Pilih Profil Optimasi Kompilasi:${NC}"
    echo -e "  ${GREEN}1) ReleaseSmall${NC} [Default] -> Ukuran binary terkecil (${BOLD}~1.1 MB${NC}), auto-strip"
    echo -e "  ${CYAN}2) ReleaseFast${NC}          -> Kecepatan eksekusi CPU/GPU maksimal (${BOLD}~1.8 MB${NC})"
    echo -e "  ${YELLOW}3) Debug${NC}                -> Stack trace lengkap untuk developer (${BOLD}~33 MB${NC})"
    read -rp "Masukkan pilihan [1/2/3] (Default: 1): " user_choice
    case "$user_choice" in
        2) OPTIMIZE_MODE="ReleaseFast" ;;
        3) OPTIMIZE_MODE="Debug" ;;
        *) OPTIMIZE_MODE="ReleaseSmall" ;;
    esac
fi

echo -e "  ${GREEN}✔${NC} Profil terpilih: ${BOLD}${OPTIMIZE_MODE}${NC}"

# 3. Sinkronisasi Embedded Datatype
echo -e "\n${BOLD}[2/4] Menyinkronkan Arsitektur Embedded Standard Library...${NC}"
python3 - << 'PYEOF'
import os

all_files = []
for root, _, files in os.walk("src/datatype"):
    for file in files:
        if file.endswith(".zig"):
            path = os.path.join(root, file).replace("\\", "/")
            rel_path = os.path.relpath(path, "src/datatype").replace("\\", "/")
            embed_path = "datatype/" + rel_path
            all_files.append((rel_path, embed_path))

all_files.sort(key=lambda x: x[0])

with open("src/embedded_datatype.zig", "w") as out:
    out.write("pub const files = .{\n")
    for rel_path, embed_path in all_files:
        out.write(f'    .{{ "{rel_path}", @embedFile("{embed_path}") }},\n')
    out.write("};\n")
PYEOF
echo -e "  ${GREEN}✔${NC} Embedded datatypes siap dan disematkan."

# 4. Compile menggunakan Zig
echo -e "\n${BOLD}[3/4] Mengompilasi SundaPy & SundaFetch (Mode: ${OPTIMIZE_MODE})...${NC}"
rm -rf .zig-cache zig-out
zig build -Doptimize="${OPTIMIZE_MODE}"

echo -e "\n${GREEN}✔ Kompilasi Berhasil!${NC} Ukuran binary yang dihasilkan:"
ls -lh zig-out/bin/ | awk 'NR>1 {printf "  - %-12s : %s\n", $9, $5}'

# 5. Instalasi ke Target Directory
install_binaries() {
    echo -e "\n${BOLD}Memasang binary ke ${INSTALL_DIR}...${NC}"
    mkdir -p "${INSTALL_DIR}"
    cp zig-out/bin/sundapy "${INSTALL_DIR}/"
    cp zig-out/bin/sundafetch "${INSTALL_DIR}/"
    echo -e "${GREEN}✔ Berhasil memasang:${NC}"
    echo -e "  - ${INSTALL_DIR}/sundapy"
    echo -e "  - ${INSTALL_DIR}/sundafetch"

    # Verifikasi PATH
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo -e "\n${YELLOW}⚠ Peringatan: ${INSTALL_DIR} belum terdaftar di variabel PATH Anda.${NC}"
        echo -e "Tambahkan baris berikut ke file konfigurasi shell Anda (~/.bashrc atau ~/.zshrc):"
        echo -e "  ${BOLD}export PATH=\"${INSTALL_DIR}:\$PATH\"${NC}"
        echo -e "Kemudian jalankan: ${CYAN}source ~/.bashrc${NC}"
    else
        echo -e "  ${GREEN}✔${NC} PATH terverifikasi: perintah ${BOLD}sundapy${NC} siap digunakan secara global!"
    fi
}

echo -e "\n${BOLD}[4/4] Tahap Instalasi Global...${NC}"
if [ "$AUTO_YES" = true ]; then
    install_binaries
else
    echo -e "Apakah Anda ingin memasang binary ini ke ${CYAN}${INSTALL_DIR}${NC}? (y/n)"
    read -rp "[y/N]: " confirm_install
    if [[ "$confirm_install" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        install_binaries
    else
        echo -e "${YELLOW}[i] Instalasi global dilewati. Binary tetap tersedia di ./zig-out/bin/sundapy${NC}"
    fi
fi

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}${BOLD}              PROSES INSTALASI SELESAI                ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "Panduan Cepat:"
echo -e "  1. Buat proyek baru     : ${CYAN}sundapy init nama_proyek${NC}"
echo -e "  2. Jalankan skrip Python: ${CYAN}sundapy skrip.py${NC}"
echo -e "  3. Unduh modul pihak-3  : ${CYAN}sundafetch install <package>${NC}"
echo -e "  4. Cek opsi lainnya     : ${CYAN}sundapy --help${NC}"
echo -e "${CYAN}======================================================${NC}"
