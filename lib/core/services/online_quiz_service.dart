/// Online Quiz Service
///
/// Handles online quiz operations including:
/// - Managing question banks
/// - Retrieving questions from Firestore
/// - Search and filter functionality
/// - User authentication validation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/quiz_models.dart';

/// Service class for online quiz operations
class OnlineQuizService {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Constants
  static const String _questionBanksCollection = 'questionBanks';
  static const String _itemsSubcollection = 'items';
  static const String _defaultErrorMessage =
      'An error occurred while processing your request';
  static const int _defaultQuestionLimit = 20;

  // === PUBLIC METHODS ===

  /// Retrieves all available question banks from Firestore
  ///
  /// Returns list of [QuestionBank] objects with question counts
  /// Throws [Exception] if user is not authenticated or retrieval fails
  Future<List<QuestionBank>> getAvailableQuestionBanks() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to access online questions');
    }

    try {
      print(
          '🔍 DEBUG: Starting question bank retrieval for user: ${currentUser.uid}');

      final snapshot =
          await _firestore.collection(_questionBanksCollection).get();

      print(
          '📊 DEBUG: Found ${snapshot.docs.length} documents in questionBanks collection');

      // If no question banks found in Firestore, return sample banks
      if (snapshot.docs.isEmpty) {
        print(
            '⚠️ WARNING: No question banks found in Firestore, returning sample banks');
        return _getSampleQuestionBanks();
      }

      final questionBanks = <QuestionBank>[];
      int successCount = 0;
      int errorCount = 0;

      for (final doc in snapshot.docs) {
        try {
          print('\n📄 DEBUG: Processing document ${doc.id}');
          print('📋 DEBUG: Document data keys: ${doc.data().keys.toList()}');

          final data = doc.data();

          // Count questions in this bank
          print('🔢 DEBUG: Counting questions in ${doc.id}');
          final itemsSnapshot = await _firestore
              .collection(_questionBanksCollection)
              .doc(doc.id)
              .collection(_itemsSubcollection)
              .get();

          final actualQuestionCount = itemsSnapshot.docs.length;
          print('✅ DEBUG: Found $actualQuestionCount questions in ${doc.id}');

          // Prepare data with actual question count
          final dataWithCount = Map<String, dynamic>.from(data);
          dataWithCount['totalQuestions'] = actualQuestionCount;

          final questionBank =
              QuestionBank.fromFirestore(doc.id, dataWithCount);

          print(
              '🎯 SUCCESS: Parsed question bank: ${questionBank.name} (${questionBank.id}) with ${questionBank.totalQuestions} questions');
          print(
              '   Subject: ${questionBank.subject}, Grade: ${questionBank.grade}');

          questionBanks.add(questionBank);
          successCount++;
        } catch (e) {
          errorCount++;
          // Log parsing error but continue with other banks
          print('❌ ERROR: Failed to parse question bank ${doc.id}: $e');
          print('📝 ERROR: Document data was: ${doc.data()}');

          // Try to create a minimal question bank even if parsing fails
          try {
            // Extract info from document ID for fallback
            String fallbackSubject = 'General';
            String fallbackGrade = '7';
            String fallbackName = doc.id;

            if (doc.id.contains('-')) {
              final parts = doc.id.split('-');
              if (parts.isNotEmpty) {
                final firstPart = parts[0];
                final gradeMatch = RegExp(r'(\d+)$').firstMatch(firstPart);
                if (gradeMatch != null) {
                  fallbackGrade = gradeMatch.group(1) ?? '7';
                  fallbackSubject = firstPart.substring(
                      0, firstPart.length - fallbackGrade.length);
                } else {
                  fallbackSubject = firstPart;
                }
                fallbackName =
                    '${fallbackSubject.toUpperCase()} Kelas $fallbackGrade';
              }
            }

            final basicQuestionBank = QuestionBank(
              id: doc.id,
              name: fallbackName,
              description:
                  'Question bank for ${fallbackSubject.toLowerCase()} kelas $fallbackGrade',
              subject: fallbackSubject,
              grade: fallbackGrade,
              totalQuestions: 0,
              createdAt: DateTime.now(),
            );
            questionBanks.add(basicQuestionBank);
            print(
                '🔧 RECOVERY: Created fallback question bank for ${doc.id}: $fallbackName');
            successCount++;
          } catch (basicError) {
            print(
                '💥 CRITICAL: Even fallback parsing failed for ${doc.id}: $basicError');
          }
        }
      }

      print('\n📊 SUMMARY: Question Bank Processing Complete');
      print('✅ Success: $successCount question banks loaded');
      print('❌ Errors: $errorCount question banks failed');
      print('📦 Total: ${questionBanks.length} question banks available');

      if (questionBanks.isEmpty) {
        print('⚠️ WARNING: No question banks could be loaded!');
        print('🔧 SUGGESTION: Check Firebase data structure and permissions');
        return [];
      }

      // Sort question banks by name for consistent display
      questionBanks.sort((a, b) => a.name.compareTo(b.name));

      print('🔤 DEBUG: Question banks sorted by name:');
      for (final bank in questionBanks) {
        print(
            '   - ${bank.name} (${bank.id}): ${bank.totalQuestions} questions');
      }

      return questionBanks;
    } catch (e) {
      print('💥 CRITICAL ERROR: Failed to retrieve question banks: $e');
      print(
          '🔧 SUGGESTION: Check network connection and Firebase configuration');
      throw Exception('Failed to retrieve question banks: $e');
    }
  }

  /// Get questions from a specific question bank
  Future<List<QuizQuestion>> getQuestionsFromBank(String bankId,
      {int? limit}) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login untuk mengakses soal online');
    }

    try {
      print('DEBUG: Fetching questions from bank: $bankId');

      // Check if this is a sample bank
      if (bankId.endsWith('-sample')) {
        print('DEBUG: Using sample questions for bank: $bankId');
        final sampleQuestions = _getSampleQuestions(bankId);
        if (limit != null && limit < sampleQuestions.length) {
          return sampleQuestions.take(limit).toList();
        }
        return sampleQuestions;
      }

      Query query = _firestore
          .collection(_questionBanksCollection)
          .doc(bankId)
          .collection(_itemsSubcollection);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      print(
          'DEBUG: Found ${snapshot.docs.length} question documents in $bankId');

      final questions = <QuizQuestion>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print(
              'DEBUG: Processing question ${doc.id} with data keys: ${data.keys.toList()}');

          final question = QuizQuestion.fromFirestore(doc.id, data);
          questions.add(question);
          print(
              'DEBUG: Successfully loaded question: ${question.id} - ${question.question.substring(0, question.question.length > 50 ? 50 : question.question.length)}...');
        } catch (e) {
          print('ERROR parsing question ${doc.id}: $e');
          print('ERROR: Question data was: ${doc.data()}');

          // Try to create a basic question object to avoid losing data
          try {
            final basicQuestion = QuizQuestion(
              id: doc.id,
              question: 'Question data parsing error',
              options: ['Option A', 'Option B', 'Option C', 'Option D'],
              correctAnswer: 0,
              explanation: 'Data parsing error occurred',
              difficulty: 'Easy',
            );
            questions.add(basicQuestion);
            print('DEBUG: Created basic question object for ${doc.id}');
          } catch (basicError) {
            print(
                'ERROR: Even basic question creation failed for ${doc.id}: $basicError');
          }
        }
      }

      print('DEBUG: Total questions loaded from $bankId: ${questions.length}');

      // Return questions in original order for debugging
      // TODO: Re-enable shuffle after fixing duel question loading
      // questions.shuffle();

      return questions;
    } catch (e) {
      print('ERROR fetching questions from bank $bankId: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mengakses soal dari $bankId. Periksa Firestore Rules.');
      }
      throw Exception('Gagal mengambil soal dari $bankId: ${e.toString()}');
    }
  }

  /// Get a specific question by ID
  Future<QuizQuestion?> getQuestionById(
      String bankId, String questionId) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login untuk mengakses soal online');
    }

    try {
      print('DEBUG: Fetching question: $bankId/$questionId');

      final doc = await _firestore
          .collection('questionBanks')
          .doc(bankId)
          .collection('items')
          .doc(questionId)
          .get();

      if (!doc.exists) {
        print('DEBUG: Question not found: $bankId/$questionId');
        return null;
      }

      final data = doc.data()!;
      final question = QuizQuestion.fromFirestore(doc.id, data);
      print('DEBUG: Question loaded: ${question.question}');
      return question;
    } catch (e) {
      print('ERROR fetching question $bankId/$questionId: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mengakses soal $questionId dari $bankId.');
      }
      throw Exception('Gagal mengambil soal: ${e.toString()}');
    }
  }

  /// Search questions by criteria
  Future<List<QuizQuestion>> searchQuestions(
    String bankId, {
    String? difficulty,
    String? subject,
    int? limit = 20,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login untuk mengakses soal online');
    }

    try {
      print(
          'DEBUG: Searching questions in $bankId with difficulty: $difficulty, subject: $subject');

      Query query = _firestore
          .collection('questionBanks')
          .doc(bankId)
          .collection('items');

      // Add filters
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      if (subject != null) {
        query = query.where('subject', isEqualTo: subject);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      final questions = <QuizQuestion>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final question = QuizQuestion.fromFirestore(doc.id, data);
          questions.add(question);
        } catch (e) {
          print('ERROR parsing search result ${doc.id}: $e');
        }
      }

      print('DEBUG: Search found ${questions.length} questions');
      return questions;
    } catch (e) {
      print('ERROR searching questions: $e');
      throw Exception('Gagal mencari soal: ${e.toString()}');
    }
  }

  /// Get sample question banks as fallback when Firestore is empty
  List<QuestionBank> _getSampleQuestionBanks() {
    print('📚 Creating sample question banks...');
    return [
      QuestionBank(
        id: 'math7-sample',
        name: 'Matematika Kelas 7 (Sample)',
        description: 'Soal matematika untuk kelas 7 SMP - Sample Data',
        subject: 'Matematika',
        grade: 'Kelas 7',
        totalQuestions: 10,
        createdAt: DateTime.now(),
      ),
      QuestionBank(
        id: 'science7-sample',
        name: 'IPA Kelas 7 (Sample)',
        description: 'Soal IPA untuk kelas 7 SMP - Sample Data',
        subject: 'IPA',
        grade: 'Kelas 7',
        totalQuestions: 8,
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Get sample questions for a specific sample bank
  List<QuizQuestion> _getSampleQuestions(String bankId) {
    print('📝 Creating sample questions for bank: $bankId');

    if (bankId == 'math7-sample') {
      return [
        QuizQuestion(
          id: 'M7_ALJ_001',
          question: 'Berapakah hasil dari 2 + 3 × 4?',
          options: ['14', '20', '12', '24'],
          correctAnswer: 0,
          explanation:
              'Sesuai urutan operasi, perkalian dikerjakan lebih dulu: 3 × 4 = 12, kemudian 2 + 12 = 14',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'M7_ALJ_002',
          question: 'Jika x = 5, maka nilai dari 2x + 3 adalah...',
          options: ['10', '13', '8', '15'],
          correctAnswer: 1,
          explanation:
              'Substitusi x = 5 ke dalam 2x + 3: 2(5) + 3 = 10 + 3 = 13',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'M7_ALJ_003',
          question: 'Manakah yang merupakan bilangan prima?',
          options: ['15', '21', '17', '25'],
          correctAnswer: 2,
          explanation:
              '17 adalah bilangan prima karena hanya habis dibagi 1 dan dirinya sendiri',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'M7_GEO_001',
          question: 'Luas persegi dengan sisi 8 cm adalah...',
          options: ['32 cm²', '64 cm²', '16 cm²', '72 cm²'],
          correctAnswer: 1,
          explanation: 'Luas persegi = sisi × sisi = 8 × 8 = 64 cm²',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'M7_GEO_002',
          question:
              'Keliling lingkaran dengan jari-jari 7 cm adalah... (π = 22/7)',
          options: ['22 cm', '44 cm', '14 cm', '28 cm'],
          correctAnswer: 1,
          explanation: 'Keliling = 2πr = 2 × (22/7) × 7 = 44 cm',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'M7_STAT_001',
          question: 'Mean dari data 5, 7, 8, 6, 9 adalah...',
          options: ['6', '7', '8', '5'],
          correctAnswer: 1,
          explanation: 'Mean = (5+7+8+6+9)/5 = 35/5 = 7',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'M7_FRAC_001',
          question: 'Hasil dari 1/2 + 1/3 adalah...',
          options: ['2/5', '5/6', '1/6', '3/5'],
          correctAnswer: 1,
          explanation: '1/2 + 1/3 = 3/6 + 2/6 = 5/6',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'M7_PERC_001',
          question: '25% dari 80 adalah...',
          options: ['15', '20', '25', '30'],
          correctAnswer: 1,
          explanation: '25% × 80 = 25/100 × 80 = 20',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'M7_ALG_001',
          question: 'Jika 3x - 5 = 10, maka x = ...',
          options: ['3', '4', '5', '6'],
          correctAnswer: 2,
          explanation: '3x - 5 = 10 → 3x = 15 → x = 5',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'M7_NUM_001',
          question: 'Hasil dari (-3) × 4 adalah...',
          options: ['-12', '12', '-7', '7'],
          correctAnswer: 0,
          explanation:
              'Perkalian bilangan negatif dengan positif menghasilkan negatif: (-3) × 4 = -12',
          difficulty: 'mudah',
        ),
      ];
    } else if (bankId == 'science7-sample') {
      return [
        QuizQuestion(
          id: 'S7_BIO_001',
          question: 'Organ yang berfungsi memompa darah adalah...',
          options: ['Paru-paru', 'Jantung', 'Hati', 'Ginjal'],
          correctAnswer: 1,
          explanation:
              'Jantung adalah organ yang berfungsi memompa darah ke seluruh tubuh',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'S7_PHY_001',
          question: 'Satuan kecepatan dalam SI adalah...',
          options: ['km/jam', 'm/s', 'cm/s', 'mil/jam'],
          correctAnswer: 1,
          explanation:
              'Satuan kecepatan dalam sistem SI adalah meter per sekon (m/s)',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'S7_CHE_001',
          question: 'Rumus kimia air adalah...',
          options: ['H2O', 'CO2', 'NaCl', 'O2'],
          correctAnswer: 0,
          explanation:
              'Air memiliki rumus kimia H2O (2 atom hidrogen dan 1 atom oksigen)',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'S7_BIO_002',
          question: 'Proses fotosintesis pada tumbuhan menghasilkan...',
          options: ['Karbondioksida', 'Oksigen', 'Nitrogen', 'Argon'],
          correctAnswer: 1,
          explanation:
              'Fotosintesis menghasilkan oksigen sebagai produk sampingan dan glukosa sebagai produk utama',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'S7_PHY_002',
          question: 'Gaya yang menyebabkan benda jatuh ke bumi disebut...',
          options: [
            'Gaya magnet',
            'Gaya gravitasi',
            'Gaya listrik',
            'Gaya gesek'
          ],
          correctAnswer: 1,
          explanation:
              'Gaya gravitasi adalah gaya tarik-menarik antara benda dengan bumi',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'S7_CHE_002',
          question: 'Perubahan es menjadi air disebut...',
          options: ['Membeku', 'Mencair', 'Menguap', 'Mengembun'],
          correctAnswer: 1,
          explanation:
              'Perubahan wujud dari padat (es) menjadi cair (air) disebut mencair',
          difficulty: 'mudah',
        ),
        QuizQuestion(
          id: 'S7_ECO_001',
          question: 'Komponen biotik dalam ekosistem adalah...',
          options: ['Air', 'Tanah', 'Tumbuhan', 'Udara'],
          correctAnswer: 2,
          explanation:
              'Komponen biotik adalah makhluk hidup, seperti tumbuhan, hewan, dan mikroorganisme',
          difficulty: 'sedang',
        ),
        QuizQuestion(
          id: 'S7_EARTH_001',
          question: 'Planet yang paling dekat dengan Matahari adalah...',
          options: ['Venus', 'Merkurius', 'Bumi', 'Mars'],
          correctAnswer: 1,
          explanation:
              'Merkurius adalah planet yang paling dekat dengan Matahari dalam tata surya',
          difficulty: 'mudah',
        ),
      ];
    }

    return [];
  }
}

/// Model for Question Bank
class QuestionBank {
  final String id;
  final String name;
  final String description;
  final String subject;
  final String grade;
  final int totalQuestions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  QuestionBank({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.grade,
    required this.totalQuestions,
    required this.createdAt,
    this.updatedAt,
  });

  factory QuestionBank.fromFirestore(String id, Map<String, dynamic> data) {
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
          defaultSubject =
              firstPart.substring(0, firstPart.length - defaultGrade.length);
        } else {
          defaultSubject = firstPart;
        }
        defaultName = '${defaultSubject.toUpperCase()} Kelas $defaultGrade';
      }
    }

    return QuestionBank(
      id: id,
      name: data['name'] as String? ?? defaultName,
      description: data['description'] as String? ??
          'Kumpulan soal ${defaultSubject.toLowerCase()} kelas $defaultGrade',
      subject: data['subject'] as String? ?? defaultSubject,
      grade: data['grade'] as String? ?? defaultGrade,
      totalQuestions: data['totalQuestions'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'subject': subject,
      'grade': grade,
      'totalQuestions': totalQuestions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
