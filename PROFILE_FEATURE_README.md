# Fitur Profile & Buat Soal - QuizWar

## Overview

Fitur baru yang telah ditambahkan ke aplikasi QuizWar untuk memungkinkan pengguna melihat profil mereka dan membuat soal sendiri.

## Fitur Utama

### 1. Halaman Profile (`ProfileScreen`)

- **Data Diri**: Menampilkan foto profil, nama, email, dan tanggal bergabung
- **Statistik**: Menampilkan jumlah soal yang dibuat dan kuis yang diambil
- **Navigasi Cepat**: Tombol untuk langsung membuat soal baru
- **Daftar Soal**: Menampilkan semua soal yang telah dibuat oleh user

### 2. Halaman Buat Soal (`CreateQuestionScreen`)

- **Form Lengkap**: Input untuk semua field yang diperlukan sesuai struktur Firestore
- **Pilihan A-E**: Interface untuk membuat 5 pilihan jawaban dengan radio button selection
- **Validasi**: Validasi komprehensif untuk semua input
- **Auto-ID**: Otomatis generate Question ID berdasarkan mata pelajaran dan kelas
- **Mata Pelajaran**: Support untuk berbagai mata pelajaran (Matematika, IPA, IPS, dll)

## Struktur Data Firestore

### Question Document Structure

```typescript
{
  answerIndex: number,        // Index jawaban benar (0-4)
  createdBy: string,         // UID pembuat soal
  explanation: string,       // Penjelasan jawaban
  grade: string,            // Kelas (1-12)
  isCopied: boolean,        // Apakah soal hasil copy
  locale: string,           // Bahasa (default: id-ID)
  number: number,           // Nomor soal
  options: string[],        // Array pilihan A-E
  points: number,           // Poin soal (default: 10)
  qid: string,             // Question ID unik
  question: string,        // Teks pertanyaan
  randomizeOptions: boolean, // Acak pilihan saat quiz
  source: {                // Sumber soal
    bookTitle: string,
    page: number,
    subject: string
  },
  subject: string,         // Mata pelajaran
  timeSuggestionSec: number, // Waktu yang disarankan (detik)
  total: number,           // Total soal dalam set
  updatedBy: string,       // UID yang update terakhir
  version: number          // Versi soal
}
```

## File Struktur

### Model

- `lib/models/quiz_models.dart` - Ditambahkan `CreateQuestionModel`, `QuestionSource`, `UserProfile`

### Services

- `lib/core/services/question_service.dart` - Service untuk mengelola CRUD soal dan profile

### Screens

- `lib/screens/profile_screen.dart` - Halaman profile user
- `lib/screens/create_question_screen.dart` - Halaman buat soal baru

### Demo

- `lib/profile_demo.dart` - Demo standalone untuk testing

## Integrasi dengan Aplikasi Utama

### 1. Menambahkan ke Home Screen

Di `home_screen.dart`, method `_showUserProfile()` sudah dimodifikasi untuk navigasi ke `ProfileScreen`:

```dart
void _showUserProfile() {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ProfileScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AppConstants.mediumAnimation,
    ),
  );
}
```

### 2. Firebase Firestore Path

Soal disimpan di: `/questionBanks/{subject}{grade}-main/items/{questionId}`

Contoh:

- `/questionBanks/math7-main/items/M7_ALJ_001`
- `/questionBanks/ipa8-main/items/S8_BIO_002`

## Cara Penggunaan

### Testing dengan Demo

1. Jalankan `lib/profile_demo.dart` untuk melihat demo standalone
2. Klik "Halaman Profile" untuk melihat profil user
3. Klik "Buat Soal Baru" untuk membuat soal

### Integrasi Penuh

1. User dapat mengakses profile melalui avatar di home screen
2. Di halaman profile, klik tombol "Buat Soal Baru"
3. Isi form lengkap untuk membuat soal
4. Soal otomatis tersimpan di Firestore dengan struktur yang sesuai

## Field Form Buat Soal

### Informasi Dasar

- **Mata Pelajaran**: Dropdown (Matematika, IPA, IPS, Bahasa Indonesia, Bahasa Inggris, Lainnya)
- **Kelas**: Dropdown (1-12)

### Pertanyaan

- **Pertanyaan**: TextArea untuk input pertanyaan

### Pilihan Jawaban

- **Pilihan A-E**: 5 TextInput dengan radio button untuk menentukan jawaban benar
- **Visual Feedback**: Pilihan yang dipilih sebagai jawaban benar akan highlighted

### Penjelasan

- **Penjelasan**: TextArea untuk penjelasan jawaban

### Sumber Soal

- **Judul Buku**: Input sumber referensi
- **Halaman**: Input nomor halaman

### Pengaturan Lanjutan

- **Poin**: Input poin soal (default: 10)
- **Waktu**: Input waktu yang disarankan dalam detik (default: 15)

## Auto-Generated Question ID

Question ID dibuat otomatis dengan format:
`{SubjectCode}{Grade}_{Timestamp}`

### Subject Codes:

- M = Matematika
- S = IPA/Science
- SO = IPS/Social
- BI = Bahasa Indonesia
- EN = Bahasa Inggris
- GN = General/Lainnya

Contoh: `M7_ALJ_001`, `S8_BIO_123`

## Security & Validasi

### Client-side Validation

- Semua field wajib diisi
- Poin dan waktu harus berupa angka
- Minimal 1 pilihan jawaban harus dipilih sebagai benar

### Firebase Security

- Soal hanya bisa dibuat oleh user yang sudah login
- CreatedBy dan UpdatedBy otomatis diisi dengan UID user
- Profile user otomatis di-update statistiknya

## Future Enhancements

1. **Edit Soal**: Fitur untuk mengedit soal yang sudah dibuat
2. **Delete Soal**: Fitur untuk menghapus soal
3. **Share Soal**: Fitur untuk membagikan soal ke user lain
4. **Category Management**: Manajemen kategori soal yang lebih advanced
5. **Bulk Import**: Import soal dalam format Excel/CSV
6. **Question Preview**: Preview soal sebelum disimpan
7. **Draft System**: Sistem untuk menyimpan draft soal
