# Firebase Google Sign-In Setup Guide

## Masalah yang Ditemukan

User yang login dengan Google tidak muncul di Firebase Authentication karena:

1. Firebase belum diinisialisasi dengan benar
2. Tidak ada integrasi Firebase Auth dengan Google Sign-In
3. Sign-in method Google mungkin belum diaktifkan di Firebase Console

## Perbaikan yang Sudah Dilakukan

### 1. Inisialisasi Firebase di main.dart ✅

```dart
void main() async {flutter 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const QuizWarApp());
}
```

### 2. Integrasi Firebase Auth dengan Google Sign-In ✅

- Menambahkan `FirebaseAuth` instance
- Mengubah `signInWithGoogle()` untuk menggunakan Firebase Auth
- Mengubah `signInAnonymously()` untuk menggunakan Firebase Auth
- Menambahkan stream `onFirebaseAuthStateChanged`

## Langkah-langkah di Firebase Console

### 1. Aktifkan Google Sign-In Method

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Pilih project "Quiz War"
3. Masuk ke **Authentication** → **Sign-in method**
4. Klik pada **Google** di daftar providers
5. Aktifkan toggle **Enable**
6. Masukkan **Project support email** (email Anda)
7. Klik **Save**

### 2. Tambahkan SHA-256 Fingerprint

1. Masih di Firebase Console, masuk ke **Project Settings** (ikon gear)
2. Pilih tab **General**
3. Scroll ke bagian **Your apps**
4. Klik pada aplikasi Android Anda
5. Klik **Add fingerprint**
6. Paste SHA-256 fingerprint:
   ```
   8A:6D:EF:08:CF:0E:9E:7F:0A:F1:E1:6C:E6:66:47:25:B2:BB:09:9B:FD:31:21:82:80:BE:9A:0E:81:1F:34:BB
   ```
7. Klik **Save**

### 3. Download google-services.json Terbaru

1. Setelah menambahkan fingerprint, download file `google-services.json` yang terbaru
2. Replace file yang ada di `android/app/google-services.json`

## Testing

Setelah semua konfigurasi selesai:

1. Build dan run aplikasi: `flutter run`
2. Coba login dengan Google
3. User seharusnya muncul di Firebase Console → Authentication → Users

## Verifikasi Konfigurasi

### Cek apakah Firebase sudah terkonfigurasi dengan benar:

```bash
flutter doctor
```

### Cek dependencies di pubspec.yaml:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.17.4
  google_sign_in: ^6.2.2
```

## Troubleshooting

### Jika masih ada masalah:

1. **Clean dan rebuild project:**

   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Cek log error di console** saat login
3. **Pastikan internet connection** stable
4. **Cek konfigurasi Google Console** (Google Cloud Console) jika diperlukan

### Error umum:

- `PlatformException: sign_in_failed` - Biasanya masalah SHA fingerprint
- `FirebaseException: NETWORK_ERROR` - Masalah koneksi
- `sign_in_canceled` - User membatalkan proses login

## Support

Jika masih ada masalah, periksa:

- Firebase Console logs
- Android Studio logcat
- Flutter doctor output
