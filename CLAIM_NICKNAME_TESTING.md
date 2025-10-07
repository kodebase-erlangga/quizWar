# Testing Guide - Claim Nickname Feature

## Setup untuk Testing

### 1. Pastikan Firestore Rules Sudah Aktif

Rules yang sudah kamu deploy sebelumnya harus tetap aktif. Cek di Firebase Console > Firestore > Rules bahwa rules custom sudah aktif (bukan default).

### 2. Jalankan Aplikasi

```bash
flutter run
```

## Langkah Testing - Bagian E: Alur "Claim Nickname"

### Step 1: Login ke Aplikasi

1. Buka aplikasi Flutter
2. Login menggunakan Google Sign-In atau Anonymous
3. Pastikan di Firebase Console > Authentication > Users muncul akun kamu

### Step 2: Buka Layar Claim Nickname

1. Setelah login, kamu akan melihat HomeScreen
2. Jika login dengan Google, akan ada box biru dengan teks "Belum Punya Nickname?"
3. Klik tombol **"Pilih Nickname"**
4. Aplikasi akan navigasi ke ClaimNicknameScreen

### Step 3: Test Claim Nickname

1. Di layar Claim Nickname, masukkan nickname (contoh: "testuser123")
2. Pastikan nickname mengikuti aturan:
   - 3-20 karakter
   - Hanya huruf, angka, dan underscore
   - Unik (belum digunakan user lain)
3. Klik tombol **"Klaim Nickname"**

### Step 4: Verifikasi di Firebase Console

#### Cek di Firestore Database:

1. Buka Firebase Console > Firestore Database > Data
2. **Cek Collection `users`:**

   - Klik collection `users`
   - Cari dokumen dengan ID = UID kamu (dari Authentication)
   - Pastikan fields berikut ada:
     ```
     {
       "uid": "your-uid-here",
       "nickname": "testuser123",
       "nicknameLower": "testuser123",
       "createdAt": [timestamp],
       "updatedAt": [timestamp]
     }
     ```

3. **Cek Collection `nicknames`:**
   - Klik collection `nicknames`
   - Cari dokumen dengan ID = "testuser123" (nicknameLower)
   - Pastikan fields berikut ada:
     ```
     {
       "uid": "your-uid-here",
       "claimedAt": [timestamp]
     }
     ```

### Step 5: Test Error Cases

#### Test Nickname Sudah Digunakan:

1. Buat user kedua (login dengan akun Google berbeda atau anonymous)
2. Coba claim nickname yang sama ("testuser123")
3. Harus muncul error: "Nickname sudah digunakan, pilih yang lain"

#### Test User Sudah Punya Nickname:

1. User yang sudah punya nickname coba claim nickname lagi
2. Harus muncul error: "Kamu sudah memiliki nickname"

#### Test Format Nickname Invalid:

1. Coba nickname < 3 karakter (contoh: "ab")
2. Coba nickname > 20 karakter
3. Coba nickname dengan karakter khusus (contoh: "test@123")
4. Harus muncul pesan error yang sesuai

## Expected Results

### ✅ Success Case:

- Nickname berhasil diklaim
- Data tersimpan di `/users/{uid}` dan `/nicknames/{nicknameLower}`
- User di-redirect kembali ke HomeScreen
- Snackbar hijau muncul dengan pesan sukses

### ❌ Error Cases:

- Error message yang jelas muncul di snackbar merah
- Data tidak tersimpan di Firestore
- User tetap di ClaimNicknameScreen untuk retry

## Monitoring Errors

### Jika ada error:

1. **Check Flutter Debug Console** untuk error messages
2. **Check Browser Dev Tools** (jika testing di web) untuk network errors
3. **Check Firebase Console > Firestore** untuk permission errors

### Common Issues:

- **Permission Denied**: Pastikan Firestore Rules sudah di-deploy dengan benar
- **User not authenticated**: Pastikan login berhasil sebelum claim nickname
- **Network errors**: Pastikan koneksi internet stabil

## Testing Checklist

- [ ] User bisa login (Google/Anonymous)
- [ ] User bisa mengakses ClaimNicknameScreen
- [ ] Nickname valid bisa diklaim successfully
- [ ] Data tersimpan di `/users/{uid}`
- [ ] Data tersimpan di `/nicknames/{nicknameLower}`
- [ ] Error handling untuk nickname sudah digunakan
- [ ] Error handling untuk user sudah punya nickname
- [ ] Validasi format nickname bekerja
- [ ] UI feedback (loading, success, error) bekerja

## Next Steps

Setelah testing berhasil:

1. Upgrade Firebase project ke Blaze plan
2. Deploy Cloud Functions (`firebase deploy --only functions`)
3. Ganti `NicknameServiceSimulation` dengan `NicknameService` yang asli
4. Test ulang dengan Cloud Functions
