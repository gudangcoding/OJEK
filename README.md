# Ojek App — Flutter + Laravel (Realtime Order)

Proyek ini adalah aplikasi ojek sederhana dengan dua peran utama: `customer` (pemesan) dan `driver` (pengemudi). Frontend dibangun dengan Flutter (`ojek_app`) dan backend dengan Laravel (`ojek_backend`). Aplikasi mendukung pemesanan, penawaran driver di sekitar, pembaruan lokasi driver secara realtime, serta alur status order (dibuat, diterima, dibatalkan, selesai).

## Fitur Utama
- Pemesanan perjalanan oleh customer, estimasi jarak dan harga.
- Pencarian driver di sekitar lokasi pickup dan broadcasting order baru.
- Driver menerima atau menolak order, dengan penutupan modal realtime di perangkat lain.
- Pelacakan lokasi driver (realtime) oleh customer di halaman rute.
- Manajemen sesi (token, role, userId) agar langganan channel privat tetap berfungsi setelah restart.
- Dual-broadcast untuk event order penting: kanal publik `orders` dan kanal privat `private-orders.{id}`.

## Struktur Proyek
- `ojek_app/` — Aplikasi Flutter (Android/iOS/web/desktop).
- `ojek_backend/` — Aplikasi Laravel (API, broadcasting, events, models).
- Berkas gambar dokumentasi berada di root proyek.

## Prasyarat
- Flutter 3.x dan Dart SDK.
- PHP 8.x, Composer, dan ekstensi yang diperlukan Laravel.
- Node.js (opsional untuk asset Laravel bila diperlukan).

## Instalasi Cepat

### Backend (Laravel)
1. Masuk ke folder backend:
   ```bash
   cd ojek_backend
   ```
2. Install dependencies:
   ```bash
   composer install
   ```
3. Salin `.env.example` menjadi `.env` dan atur konfigurasi database, broadcasting (Pusher), dan SANCTUM.
4. Generate app key dan migrasi database:
   ```bash
   php artisan key:generate
   php artisan migrate --seed
   ```
5. Jalankan server pengembangan:
   ```bash
   php artisan serve
   ```

### Frontend (Flutter)
1. Masuk ke folder aplikasi Flutter:
   ```bash
   cd ojek_app
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Konfigurasi `lib/config.dart` sesuai environment Anda:
   - `AppConfig.apiBaseUrl` mengarah ke URL API Laravel, misalnya `http://localhost:8000/api`.
   - `AppConfig.pusherKey` dan `AppConfig.pusherCluster` mengikuti pengaturan Pusher di backend.
4. Jalankan aplikasi:
   ```bash
   flutter run
   ```

## Konfigurasi Realtime & Broadcast
- Backend mengirim event order ke:
  - Kanal publik: `orders` (untuk driver umum yang memantau order baru dan status ringkas).
  - Kanal privat: `private-orders.{id}` (untuk customer pemilik order agar dialog menunggu/halaman rute bereaksi cepat).
- Event bertajuk `order.created`, `accepted`, `cancelled`, `completed` dikirim sesuai aksi di backend.
- Driver juga menerima penawaran tertarget via kanal privat `private-users.{id}` (opsional/configurable).
- Frontend berlangganan kanal melalui `BroadcastService`/`RealtimeService` dan menggunakan token Bearer untuk authorizer.

## Endpoint Penting (contoh)
- `POST /api/login` — Login dan menerima token Sanctum.
- `POST /api/register` — Registrasi user baru (role: `customer`/`driver`).
- `POST /api/orders` — Customer membuat order.
- `POST /api/orders/{id}/accept` — Driver menerima order.
- `POST /api/me/location` — Kirim lokasi user (status_job didukung: `online`, `offline`, `active`, `idle`).

## Screenshot & Ilustrasi

![Beranda Customer](./customer.png)

![Beranda Driver](./driver.png)

![Order Masuk (Driver)](./order%20masuk.png)

![Estimasi Perjalanan](./estimasi.png)

![Cari Driver](./cari%20driver.png)

![Radius Customer](./Customer%20Radius.png)

## Catatan
- Jika dialog menunggu pada halaman customer tidak tertutup saat order diterima, pastikan event `accepted` diterima di kanal publik `orders` atau kanal privat `private-orders.{id}` dan periksa konfigurasi Pusher/token.
- Nilai `status_job` sudah diperluas untuk mendukung `idle` agar sinkron dengan alur driver.
- Untuk mengubah mode broadcast (publik vs privat tertarget), sesuaikan event di `ojek_backend/app/Events/` dan langganan di `ojek_app/lib/services/broadcast.dart`.

---
Silakan sesuaikan README ini jika Anda menambah fitur atau mengubah alur kerja. Jika ada gambar tambahan di root, tambahkan dengan format:

```md
![Judul Gambar](./nama%20file.png)
```