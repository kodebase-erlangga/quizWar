# 🚨 URGENT: Cara Mengatasi Error Google Sign In (ApiException: 10)

## ❌ Error Yang Terjadi

```
Sign in failed: PlatformException(sign_in_failed,
com.google.android.gms.common.api.ApiException: 10: , null, null)
```

**Error Code 10 = Developer Error** - Ini berarti konfigurasi OAuth belum benar di Google Cloud Console.

## ✅ SOLUSI: Setup Google Cloud Console

### 📋 Step 1: Buka Google Cloud Console

1. Buka [Google Cloud Console](https://console.cloud.google.com/)
2. Login dengan akun Google Anda
3. Pilih project **quiz-war-4257f** (atau buat project baru)

### 📋 Step 2: Aktifkan Google Sign-In API

1. Pergi ke **APIs & Services** → **Library**
2. Cari **"Google Sign-In API"** atau **"Google+ API"**
3. Klik **Enable**

### 📋 Step 3: Buat OAuth 2.0 Client ID untuk Android

1. Pergi ke **APIs & Services** → **Credentials**
2. Klik **+ CREATE CREDENTIALS** → **OAuth 2.0 Client IDs**
3. Pilih **Application type**: **Android**
4. Isi form:
   - **Name**: `QuizWar Android`
   - **Package name**: `com.example.quizwar`
   - **SHA-1 certificate fingerprint**: `F5:D7:80:60:31:29:31:1F:04:D4:18:24:64:5D:35:DB:02:6A:89:3E`

### 📋 Step 4: Download google-services.json (Updated)

1. Setelah membuat OAuth client ID, download file **google-services.json** terbaru
2. Replace file `android/app/google-services.json` yang sudah ada
3. File baru akan berisi Android OAuth client (client_type: 1)

### 📋 Step 5: Test Aplikasi

1. Jalankan `flutter clean`
2. Jalankan `flutter run`
3. Coba Sign In dengan Google

---

## 🔑 INFORMASI PENTING

### SHA-1 Fingerprint (untuk Google Console):

```
F5:D7:80:60:31:29:31:1F:04:D4:18:24:64:5D:35:DB:02:6A:89:3E
```

### Package Name:

```
com.example.quizwar
```

### Project ID (Firebase):

```
quiz-war-4257f
```

---

## 🔍 Verifikasi google-services.json

File yang benar harus berisi **client_type: 1** (Android), contoh:

```json
{
  "project_info": {
    "project_id": "quiz-war-4257f"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:770807191577:android:xxxx",
        "android_client_info": {
          "package_name": "com.example.quizwar"
        }
      },
      "oauth_client": [
        {
          "client_id": "xxx-android.apps.googleusercontent.com",
          "client_type": 1    ← HARUS ADA INI (Android client)
        },
        {
          "client_id": "xxx-web.apps.googleusercontent.com",
          "client_type": 3    ← Web client (sudah ada)
        }
      ]
    }
  ]
}
```

---

## 🎯 Setelah Setup Google Console

1. **Download google-services.json baru** dan replace yang lama
2. **Flutter clean & run**:
   ```bash
   flutter clean
   flutter run
   ```
3. **Test Google Sign In** - seharusnya berfungsi!

---

## 🆘 Troubleshooting

### Jika masih error:

1. **Pastikan package name sama**: `com.example.quizwar`
2. **Pastikan SHA-1 fingerprint benar**: `F5:D7:...`
3. **Wait 5-10 menit** setelah setup (propagasi Google)
4. **Restart aplikasi** dan emulator

### Jika perlu generate SHA-1 lagi:

```bash
cd android
./gradlew signingReport
```

---

**Status**: ⏳ Pending setup Google Cloud Console
**Next**: 🔧 Setup OAuth Android client dengan SHA-1 fingerprint di atas
