import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen untuk upload sample questions ke Firebase
class UploadQuestionsScreen extends StatefulWidget {
  const UploadQuestionsScreen({super.key});

  @override
  State<UploadQuestionsScreen> createState() => _UploadQuestionsScreenState();
}

class _UploadQuestionsScreenState extends State<UploadQuestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploading = false;
  String _status = '';
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
      _status = message;
    });
    print(message);
  }

  Future<void> _uploadQuestions() async {
    setState(() {
      _isUploading = true;
      _logs.clear();
    });

    try {
      _addLog('🚀 Starting question upload to Firebase...');

      // Load sample question data from assets or hardcoded
      final sampleData = _getSampleQuestionData();

      _addLog(
          '📊 Found ${sampleData.keys.length} question banks in sample data');

      // Upload each question bank
      for (final entry in sampleData.entries) {
        final bankId = entry.key;
        final bankData = entry.value as Map<String, dynamic>;

        _addLog('📚 Uploading question bank: $bankId');
        _addLog('   Name: ${bankData['name']}');
        _addLog('   Subject: ${bankData['subject']}');

        // Extract items (questions)
        final items = bankData['items'] as Map<String, dynamic>? ?? {};
        _addLog('   Questions: ${items.length}');

        // Prepare bank document (without items)
        final bankDocument = Map<String, dynamic>.from(bankData);
        bankDocument.remove('items'); // Remove items from main document
        bankDocument['totalQuestions'] = items.length;
        bankDocument['createdAt'] = FieldValue.serverTimestamp();

        // Upload question bank document
        await _firestore
            .collection('questionBanks')
            .doc(bankId)
            .set(bankDocument);
        _addLog('✅ Question bank uploaded: $bankId');

        // Upload each question as sub-document
        for (final itemEntry in items.entries) {
          final questionId = itemEntry.key;
          final questionData = itemEntry.value as Map<String, dynamic>;

          // Add metadata
          questionData['createdAt'] = FieldValue.serverTimestamp();
          questionData['createdBy'] = 'system';

          await _firestore
              .collection('questionBanks')
              .doc(bankId)
              .collection('items')
              .doc(questionId)
              .set(questionData);

          final questionText = questionData['question']?.toString() ?? '';
          final displayText = questionText.length > 50
              ? '${questionText.substring(0, 50)}...'
              : questionText;
          _addLog('  ✅ Question uploaded: $questionId - $displayText');
        }

        _addLog('🎯 Completed uploading ${items.length} questions for $bankId');
      }

      _addLog('🎉 All question banks uploaded successfully!');

      // Verify upload
      _addLog('🔍 Verifying upload...');
      final banksSnapshot = await _firestore.collection('questionBanks').get();
      _addLog(
          '📊 Total question banks in Firebase: ${banksSnapshot.docs.length}');

      for (final doc in banksSnapshot.docs) {
        final itemsSnapshot = await _firestore
            .collection('questionBanks')
            .doc(doc.id)
            .collection('items')
            .get();
        _addLog('   ${doc.id}: ${itemsSnapshot.docs.length} questions');
      }
    } catch (e) {
      _addLog('❌ Error uploading questions: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Map<String, dynamic> _getSampleQuestionData() {
    return {
      "math7-main": {
        "name": "Matematika Kelas 7",
        "description": "Soal matematika untuk kelas 7 SMP",
        "subject": "Matematika",
        "grade": "Kelas 7",
        "totalQuestions": 10,
        "createdAt": "2024-10-03T10:00:00Z",
        "items": {
          "M7_ALJ_001": {
            "question": "Berapakah hasil dari 2 + 3 × 4?",
            "options": ["14", "20", "12", "24"],
            "correctAnswer": 0,
            "explanation":
                "Sesuai urutan operasi, perkalian dikerjakan lebih dulu: 3 × 4 = 12, kemudian 2 + 12 = 14",
            "difficulty": "mudah",
            "subject": "Aljabar"
          },
          "M7_ALJ_002": {
            "question": "Jika x = 5, maka nilai dari 2x + 3 adalah...",
            "options": ["10", "13", "8", "15"],
            "correctAnswer": 1,
            "explanation":
                "Substitusi x = 5 ke dalam 2x + 3: 2(5) + 3 = 10 + 3 = 13",
            "difficulty": "mudah",
            "subject": "Aljabar"
          },
          "M7_ALJ_003": {
            "question": "Manakah yang merupakan bilangan prima?",
            "options": ["15", "21", "17", "25"],
            "correctAnswer": 2,
            "explanation":
                "17 adalah bilangan prima karena hanya habis dibagi 1 dan dirinya sendiri",
            "difficulty": "sedang",
            "subject": "Bilangan"
          },
          "M7_GEO_001": {
            "question": "Luas persegi dengan sisi 8 cm adalah...",
            "options": ["32 cm²", "64 cm²", "16 cm²", "72 cm²"],
            "correctAnswer": 1,
            "explanation": "Luas persegi = sisi × sisi = 8 × 8 = 64 cm²",
            "difficulty": "mudah",
            "subject": "Geometri"
          },
          "M7_GEO_002": {
            "question":
                "Keliling lingkaran dengan jari-jari 7 cm adalah... (π = 22/7)",
            "options": ["22 cm", "44 cm", "14 cm", "28 cm"],
            "correctAnswer": 1,
            "explanation": "Keliling = 2πr = 2 × (22/7) × 7 = 44 cm",
            "difficulty": "sedang",
            "subject": "Geometri"
          },
          "M7_STAT_001": {
            "question": "Mean dari data 5, 7, 8, 6, 9 adalah...",
            "options": ["6", "7", "8", "5"],
            "correctAnswer": 1,
            "explanation": "Mean = (5+7+8+6+9)/5 = 35/5 = 7",
            "difficulty": "mudah",
            "subject": "Statistika"
          },
          "M7_FRAC_001": {
            "question": "Hasil dari 1/2 + 1/3 adalah...",
            "options": ["2/5", "5/6", "1/6", "3/5"],
            "correctAnswer": 1,
            "explanation": "1/2 + 1/3 = 3/6 + 2/6 = 5/6",
            "difficulty": "sedang",
            "subject": "Pecahan"
          },
          "M7_PERC_001": {
            "question": "25% dari 80 adalah...",
            "options": ["15", "20", "25", "30"],
            "correctAnswer": 1,
            "explanation": "25% × 80 = 25/100 × 80 = 20",
            "difficulty": "mudah",
            "subject": "Persentase"
          },
          "M7_ALG_001": {
            "question": "Jika 3x - 5 = 10, maka x = ...",
            "options": ["3", "4", "5", "6"],
            "correctAnswer": 2,
            "explanation": "3x - 5 = 10 → 3x = 15 → x = 5",
            "difficulty": "sedang",
            "subject": "Aljabar"
          },
          "M7_NUM_001": {
            "question": "Hasil dari (-3) × 4 adalah...",
            "options": ["-12", "12", "-7", "7"],
            "correctAnswer": 0,
            "explanation":
                "Perkalian bilangan negatif dengan positif menghasilkan negatif: (-3) × 4 = -12",
            "difficulty": "mudah",
            "subject": "Bilangan"
          }
        }
      },
      "science7-main": {
        "name": "IPA Kelas 7",
        "description": "Soal IPA untuk kelas 7 SMP",
        "subject": "IPA",
        "grade": "Kelas 7",
        "totalQuestions": 8,
        "createdAt": "2024-10-03T10:00:00Z",
        "items": {
          "S7_BIO_001": {
            "question": "Organ yang berfungsi memompa darah adalah...",
            "options": ["Paru-paru", "Jantung", "Hati", "Ginjal"],
            "correctAnswer": 1,
            "explanation":
                "Jantung adalah organ yang berfungsi memompa darah ke seluruh tubuh",
            "difficulty": "mudah",
            "subject": "Biologi"
          },
          "S7_PHY_001": {
            "question": "Satuan kecepatan dalam SI adalah...",
            "options": ["km/jam", "m/s", "cm/s", "mil/jam"],
            "correctAnswer": 1,
            "explanation":
                "Satuan kecepatan dalam sistem SI adalah meter per sekon (m/s)",
            "difficulty": "mudah",
            "subject": "Fisika"
          },
          "S7_CHE_001": {
            "question": "Rumus kimia air adalah...",
            "options": ["H2O", "CO2", "NaCl", "O2"],
            "correctAnswer": 0,
            "explanation":
                "Air memiliki rumus kimia H2O (2 atom hidrogen dan 1 atom oksigen)",
            "difficulty": "mudah",
            "subject": "Kimia"
          },
          "S7_BIO_002": {
            "question": "Proses fotosintesis pada tumbuhan menghasilkan...",
            "options": ["Karbondioksida", "Oksigen", "Nitrogen", "Argon"],
            "correctAnswer": 1,
            "explanation":
                "Fotosintesis menghasilkan oksigen sebagai produk sampingan dan glukosa sebagai produk utama",
            "difficulty": "sedang",
            "subject": "Biologi"
          },
          "S7_PHY_002": {
            "question": "Gaya yang menyebabkan benda jatuh ke bumi disebut...",
            "options": [
              "Gaya magnet",
              "Gaya gravitasi",
              "Gaya listrik",
              "Gaya gesek"
            ],
            "correctAnswer": 1,
            "explanation":
                "Gaya gravitasi adalah gaya tarik-menarik antara benda dengan bumi",
            "difficulty": "mudah",
            "subject": "Fisika"
          },
          "S7_CHE_002": {
            "question": "Perubahan es menjadi air disebut...",
            "options": ["Membeku", "Mencair", "Menguap", "Mengembun"],
            "correctAnswer": 1,
            "explanation":
                "Perubahan wujud dari padat (es) menjadi cair (air) disebut mencair",
            "difficulty": "mudah",
            "subject": "Kimia"
          },
          "S7_ECO_001": {
            "question": "Komponen biotik dalam ekosistem adalah...",
            "options": ["Air", "Tanah", "Tumbuhan", "Udara"],
            "correctAnswer": 2,
            "explanation":
                "Komponen biotik adalah makhluk hidup, seperti tumbuhan, hewan, dan mikroorganisme",
            "difficulty": "sedang",
            "subject": "Ekologi"
          },
          "S7_EARTH_001": {
            "question": "Planet yang paling dekat dengan Matahari adalah...",
            "options": ["Venus", "Merkurius", "Bumi", "Mars"],
            "correctAnswer": 1,
            "explanation":
                "Merkurius adalah planet yang paling dekat dengan Matahari dalam tata surya",
            "difficulty": "mudah",
            "subject": "Bumi dan Antariksa"
          }
        }
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Questions'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadQuestions,
              child: _isUploading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Uploading...'),
                      ],
                    )
                  : const Text('Upload Sample Questions'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
