#!/bin/bash
set -e

echo "======================================================"
echo "    SundaPy Compiler Builder & Installer"
echo "======================================================"

# 1. Cek dependencies
if ! command -v zig &> /dev/null
then
    echo "[!] Zig compiler tidak ditemukan! Harap install Zig (versi 0.16.0 direkomendasikan)."
    exit 1
fi

if ! command -v python3 &> /dev/null
then
    echo "[!] Python3 tidak ditemukan!"
    exit 1
fi

# 2. Generate Embedded Architecture
echo "[1/4] Membangun arsitektur Embedded Static Standard Library..."
cat << 'PYEOF' > generate_embedded.py
import os

with open("src/embedded_datatype.zig", "w") as out:
    out.write("pub const files = .{\n")
    for root, _, files in os.walk("src/datatype"):
        for file in files:
            if file.endswith(".zig"):
                path = os.path.join(root, file).replace("\\", "/")
                rel_path = os.path.relpath(path, "src/datatype").replace("\\", "/")
                embed_path = "datatype/" + rel_path
                out.write(f'    .{{ "{rel_path}", @embedFile("{embed_path}") }},\n')
    out.write("};\n")
PYEOF
python3 generate_embedded.py
rm generate_embedded.py

# 3. Compile menggunakan Zig
echo "[2/4] Mengompilasi SundaPy & SundaFetch secara ekstrim (ReleaseSmall)..."
rm -rf .zig-cache zig-out
zig build

echo "[3/4] Kompilasi Selesai! Ukuran binari mandiri sangat kecil:"
ls -lh zig-out/bin/

# 4. Prompt Instalasi ke PATH lokal pengguna
echo ""
echo "[4/4] Apakah Anda ingin meng-install binari ini ke ~/.local/bin/ agar bisa diakses darimana saja? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    mkdir -p ~/.local/bin
    cp zig-out/bin/sundapy ~/.local/bin/
    cp zig-out/bin/sundafetch ~/.local/bin/
    echo "[+] Berhasil di-install ke ~/.local/bin/!"
    echo "    (Pastikan ~/.local/bin sudah terdaftar di sistem PATH Anda)"
else
    echo "[i] Instalasi global dilewati. Anda bisa menjalankannya via ./zig-out/bin/sundapy"
fi

echo "======================================================"
echo "   Proses Selesai !!!"
echo "======================================================"
