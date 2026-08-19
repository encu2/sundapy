# Apa itu sundapy?
Sundapy adalah program untuk melakukan transpil kode python (python-like) ke zig dan lalu di compile binary (ELF). Sementara ini memang dalam pengembangannya masih khusus untuk linux tapi gak menutup kemungkinan di update yang akan datang bisa support OS Jendela. Secara khusus untuk memudahkan developer python, sundapy ini dari awal emang dirancang untuk bisa berjalan seamless di ekosistem python dengan kompatibilitas yang cukup tinggi walau gak sampe 100% karena limitasi skema si sundapy ini.

Bagi kalian yang tertarik ingin coba mungkin perlu beberapa hal yang harus diketahui:
- Static-type opsional: Memang hal ini faktor yang tidak umum di python, tapi di sundapy ada beberapa benefit kenapa harus static-type yaitu dilakukan untuk mempercepat proses transpile ke zig dan juga untuk optimize kode kalian di sisi zig tentunya. 
- Tranpiler-nya cukup strict: Saya memang merancang sundapy punya transpiler yang cukup dan mungkin sangat strict. Tapi hal ini berlaku apabila kalian melakukan static-type atau mengaktifkan `#strict` declare pada local scoope atau global scoope.
- Apa itu `#strict` di sundapy:  sebenernya cukup sulit buat saya cari cara buat aktivasi mode strict di sundapy, tapi dengan beberapa pertimbangan saya pakai teknik pengaktifan strict seperti pada js/ts (btw saya itu 95% berkecimpung di js/ts-bun runtime). Bagaimana cara kalian memanggil `#strict` maka akan beda juga hasil transpil kode zig-nya, tapi disarankan untuk memanggil `#strict` di awal global scoope untuk mode ngoding hardcore :V.
- Apa kode zig-nya akan mirip dengan kode python?: Bisa ya dan bisa tidak, cek aja sendiri hasil transpil kode zig di `.cache/src/`.
- Dokumentasi lengkap cek dimana?: Cek file test yang berada di `test/`.

## Kompatibilitas dengan ekosistem python
Sejauh yang sudah saya test, untuk projek skala kecil sih udah cukup okeh, udah di test untuk eksternal lib `bs4` dan `numpy`. Dan yak tentu aja projek ini hanya untuk senang-senang dan hobi semata cuma sampai sebatas ini saja saya bisa melakukan test dan pengujian. Untuk library lainnya ada yang di rewrite secara khusus dengan kode zig, seperti `socket`, `time` dan `request`, lalu selain itu library untuk connect ke url https/ssl/tls juga sudah bisa serta dibangun dengan zig. Memang masih banyak PR untuk improve kompatibilitas dengan ekosistem python.

Untuk install eksternal library misal dari pip ada `sundafetch`, mirip-mirip pip tapi saya merasa masih banyak kekurangan dan baru di test di workspace yang sangat sempit dan sangat terbatas. Sejauh ini secara pengetesan sederhana sundapy masih bergantung pada **python yang terinstall** di device, saat ini tested di python3.14, hal ini digunakan untuk interaksi dengan **external library yang berintegrasi dengan Python ABI**.


### DO WITH YOUR OWN RISK

**Keseluruhan project ini dibangun dengan menggunakan bantuan Gemini 3.1 Pro High + Agy-cli + Ponytail skill, selain memudahkan proses pengembangan hal ini juga karena saya sendiri penggagas projek ini merasa masih skill issue terutama untuk low-level programming seperti memory management, interaksi dengan OS / Kernel, dan keterbatasan knowledge tentang algoritma pemrograman. Perlu diingat kembali projek ini itu pure hobi dan eksperimen saja, kalau merasa ada yang terbantu dengan projek ini saya sangat bersyukur dan jangan lupa menautkan sumber :V.**