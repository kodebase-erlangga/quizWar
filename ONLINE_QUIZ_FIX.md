# Perbaikan Online Quiz - Menampilkan Semua Question Banks

## Masalah

Aplikasi online quiz hanya menampilkan satu question bank (`math7-main`) padahal di Firestore terdapat beberapa question banks (`General7-main`, `math7-main`).

## Analisis Root Cause

1. **Data parsing issue**: QuestionBank model tidak dapat mem-parse data dari Firestore dengan baik karena field yang diharapkan mungkin tidak ada
2. **Missing debug information**: Tidak ada logging yang cukup untuk mengidentifikasi masalah parsing
3. **Manual question counting**: Jumlah soal tidak dihitung secara otomatis dari subcollection

## Solusi yang Diimplementasikan

### 1. Enhanced Debug Logging

**File**: `lib/core/services/online_quiz_service.dart`

Menambahkan debug log yang lebih detail:

```dart
print('DEBUG: Found ${snapshot.docs.length} documents in questionBanks collection');
print('DEBUG: Processing document ${doc.id} with data: $data');
print('DEBUG: Found $actualQuestionCount questions in ${doc.id}');
```

### 2. Improved QuestionBank Parsing

**File**: `lib/core/services/online_quiz_service.dart`

Memperbaiki `QuestionBank.fromFirestore()` dengan:

- Smart parsing dari document ID untuk mengekstrak subject dan grade
- Fallback values yang lebih baik
- Auto-generation nama yang user-friendly

```dart
// Extract subject and grade from document ID if not present in data
String defaultSubject = 'General';
String defaultGrade = '';
String defaultName = id;

if (id.contains('-')) {
  final parts = id.split('-');
  if (parts.isNotEmpty) {
    final firstPart = parts[0];
    // Extract grade number from the end of the subject
    final gradeMatch = RegExp(r'(\d+)$').firstMatch(firstPart);
    if (gradeMatch != null) {
      defaultGrade = gradeMatch.group(1) ?? '';
      defaultSubject = firstPart.substring(0, firstPart.length - defaultGrade.length);
    } else {
      defaultSubject = firstPart;
    }
    defaultName = '${defaultSubject.toUpperCase()} Kelas $defaultGrade';
  }
}
```

### 3. Auto Question Counting

**File**: `lib/core/services/online_quiz_service.dart`

Menghitung jumlah soal secara otomatis dari subcollection:

```dart
// Count questions in this bank by querying the items subcollection
final itemsSnapshot = await _firestore
    .collection('questionBanks')
    .doc(doc.id)
    .collection('items')
    .get();

final actualQuestionCount = itemsSnapshot.docs.length;
```

## Expected Results

Setelah perbaikan ini, aplikasi seharusnya:

1. **Menampilkan semua question banks** yang ada di Firestore
2. **Parsing dengan benar** untuk document ID seperti:
   - `math7-main` → "MATH Kelas 7"
   - `General7-main` → "GENERAL Kelas 7"
3. **Menampilkan jumlah soal yang akurat** untuk setiap question bank
4. **Memberikan debug log yang detail** untuk troubleshooting

## Testing

1. Navigasi ke halaman "Soal Online"
2. Periksa log console untuk melihat debug output
3. Verifikasi bahwa semua question banks ditampilkan
4. Pastikan jumlah soal di setiap question bank benar

## Debug Log yang Diharapkan

```
DEBUG: Fetching question banks for user: [USER_ID]
DEBUG: Found 2 documents in questionBanks collection
DEBUG: Processing document General7-main with data: {...}
DEBUG: Found [X] questions in General7-main
DEBUG: Successfully parsed question bank: GENERAL Kelas 7 (General7-main) with [X] questions
DEBUG: Processing document math7-main with data: {...}
DEBUG: Found [Y] questions in math7-main
DEBUG: Successfully parsed question bank: MATH Kelas 7 (math7-main) with [Y] questions
DEBUG: Total question banks parsed: 2
```
