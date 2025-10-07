# QuizWar - Google Sign In Setup

Aplikasi QuizWar dengan integrasi Google Sign In untuk Flutter.

## Setup Google Sign In

### 1. Google Cloud Console Setup

1. Buka [Google Cloud Console](https://console.cloud.google.com/)
2. Buat project baru atau pilih project yang sudah ada
3. Aktifkan Google Sign-In API:
   - Pergi ke "APIs & Services" > "Library"
   - Cari "Google Sign-In API" dan aktifkan

### 2. Konfigurasi OAuth 2.0

1. Pergi ke "APIs & Services" > "Credentials"
2. Klik "Create Credentials" > "OAuth 2.0 Client IDs"

#### Untuk Android:

1. Pilih "Android" sebagai application type
2. Masukkan package name: `com.example.quizwar`
3. Dapatkan SHA-1 certificate fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
4. Masukkan SHA-1 fingerprint ke Google Cloud Console
5. Simpan OAuth client ID

#### Untuk iOS:

1. Pilih "iOS" sebagai application type
2. Masukkan bundle ID: `com.example.quizwar`
3. Simpan OAuth client ID

#### Untuk Web:

1. Pilih "Web application" sebagai application type
2. Tambahkan authorized origins jika diperlukan
3. Simpan OAuth client ID

### 3. Platform Configuration

#### Android Configuration:

Tidak diperlukan konfigurasi tambahan untuk versi baru google_sign_in plugin.

#### iOS Configuration:

1. Buka `ios/Runner/Info.plist`
2. Tambahkan konfigurasi berikut:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` dengan reversed client ID dari Google Cloud Console.

### 4. Konfigurasi Client ID (Opsional)

Jika Anda ingin menggunakan client ID specific, uncomment dan update baris ini di `main.dart`:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: 'your-client-id.apps.googleusercontent.com', // Untuk iOS
  scopes: [
    'email',
    'profile',
  ],
);
```

## Menjalankan Aplikasi

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Jalankan aplikasi:
   ```bash
   flutter run
   ```

## Fitur

- ✅ Google Sign In/Sign Out
- ✅ Menampilkan profil user (nama, email, foto)
- ✅ Silent sign in (auto login)
- ✅ Error handling
- ✅ Loading states

## Troubleshooting

### Error: "Developer Error" atau "Sign in failed"

- Pastikan SHA-1 certificate sudah dikonfigurasi dengan benar di Google Cloud Console
- Pastikan package name sama dengan yang dikonfigurasi di Google Cloud Console
- Pastikan Google Sign-In API sudah diaktifkan

### Error: "Network error"

- Pastikan device terhubung ke internet
- Coba dengan akun Google yang berbeda

### Error pada iOS

- Pastikan bundle ID sudah dikonfigurasi dengan benar
- Pastikan reversed client ID sudah ditambahkan ke Info.plist

## Dependencies

- `google_sign_in: ^6.2.2` - Plugin untuk Google Sign In
- `flutter/material.dart` - Material Design components

## Support

Aplikasi ini mendukung:

- Android (API 21+)
- iOS (iOS 12.0+)
- Web
