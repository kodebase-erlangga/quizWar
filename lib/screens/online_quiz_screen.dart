import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/online_quiz_service.dart';
import '../core/services/auth_service.dart';
import 'online_quiz_play_screen.dart';

class OnlineQuizScreen extends StatefulWidget {
  const OnlineQuizScreen({super.key});

  @override
  State<OnlineQuizScreen> createState() => _OnlineQuizScreenState();
}

class _OnlineQuizScreenState extends State<OnlineQuizScreen> {
  final OnlineQuizService _onlineQuizService = OnlineQuizService();
  final AuthService _authService = AuthService();

  List<QuestionBank> _questionBanks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestionBanks();
  }

  Future<void> _loadQuestionBanks() async {
    print('🚀 OnlineQuizScreen: Starting to load question banks...');
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if user is logged in with Google
      final user = _authService.currentFirebaseUser;
      if (user == null) {
        print('❌ OnlineQuizScreen: User not logged in');
        setState(() {
          _error = 'Anda harus login untuk mengakses soal online';
          _isLoading = false;
        });
        return;
      }

      // Check if user logged in with Google (not anonymous)
      final isGoogleUser = !user.isAnonymous &&
          user.providerData
              .any((provider) => provider.providerId == 'google.com');
      if (!isGoogleUser) {
        print('❌ OnlineQuizScreen: User not logged in with Google');
        setState(() {
          _error =
              'Fitur soal online hanya tersedia untuk pengguna yang login dengan Google';
          _isLoading = false;
        });
        return;
      }

      print(
          '✅ OnlineQuizScreen: User authenticated, fetching question banks...');

      // TEMPORARY: Create missing question banks if they don't exist
      await _createMissingQuestionBanks();

      final questionBanks =
          await _onlineQuizService.getAvailableQuestionBanks();

      print(
          '📊 OnlineQuizScreen: Received ${questionBanks.length} question banks');
      for (final bank in questionBanks) {
        print(
            '   📚 ${bank.name} (${bank.id}): ${bank.totalQuestions} questions');
      }

      setState(() {
        _questionBanks = questionBanks;
        _isLoading = false;
      });

      print('✅ OnlineQuizScreen: State updated, UI should refresh now');
    } catch (e) {
      print('❌ OnlineQuizScreen: Error loading question banks: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// TEMPORARY: Create missing question banks for testing
  Future<void> _createMissingQuestionBanks() async {
    try {
      print('🔧 Creating missing question banks if needed...');
      final firestore = FirebaseFirestore.instance;

      // Create Matematika5-main if missing
      await _createQuestionBankIfMissing(
        firestore,
        'Matematika5-main',
        'Matematika Kelas 5',
        'Kumpulan soal matematika untuk kelas 5',
        'Matematika',
        '5',
      );

      // Create General7-main if missing
      await _createQuestionBankIfMissing(
        firestore,
        'General7-main',
        'General Kelas 7',
        'Kumpulan soal umum untuk kelas 7',
        'General',
        '7',
      );
    } catch (e) {
      print('⚠️ Error creating missing question banks: $e');
    }
  }

  Future<void> _createQuestionBankIfMissing(
    FirebaseFirestore firestore,
    String bankId,
    String name,
    String description,
    String subject,
    String grade,
  ) async {
    try {
      final doc = await firestore.collection('questionBanks').doc(bankId).get();

      if (!doc.exists) {
        print('📝 Creating question bank: $bankId');
        await firestore.collection('questionBanks').doc(bankId).set({
          'name': name,
          'description': description,
          'subject': subject,
          'grade': grade,
          'totalQuestions': 3, // Will be updated after adding questions
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add sample questions
        await _addSampleQuestions(firestore, bankId, subject, grade);
        print('✅ Created $bankId with sample questions');
      } else {
        // Check if it has items
        final itemsSnapshot = await doc.reference.collection('items').get();
        if (itemsSnapshot.docs.isEmpty) {
          print('📝 Adding sample questions to existing bank: $bankId');
          await _addSampleQuestions(firestore, bankId, subject, grade);
        }
        print(
            'ℹ️ Question bank $bankId already exists with ${itemsSnapshot.docs.length} questions');
      }
    } catch (e) {
      print('❌ Error creating question bank $bankId: $e');
    }
  }

  Future<void> _addSampleQuestions(
    FirebaseFirestore firestore,
    String bankId,
    String subject,
    String grade,
  ) async {
    try {
      List<Map<String, dynamic>> sampleQuestions = [];

      if (subject == 'Matematika' && grade == '5') {
        sampleQuestions = [
          {
            'question': 'Berapa hasil dari 25 × 4?',
            'options': ['100', '90', '110', '80', '120'],
            'correctAnswer': 0,
            'explanation':
                '25 × 4 = 100. Dapat dihitung dengan 25 × 4 = 25 + 25 + 25 + 25 = 100',
            'difficulty': 'medium',
            'subject': subject,
            'grade': grade,
            'points': 10,
            'timeSuggestionSec': 15,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'question':
                'Jika sebuah segitiga memiliki alas 8 cm dan tinggi 6 cm, berapa luasnya?',
            'options': ['24 cm²', '48 cm²', '14 cm²', '32 cm²', '16 cm²'],
            'correctAnswer': 0,
            'explanation':
                'Luas segitiga = ½ × alas × tinggi = ½ × 8 × 6 = 24 cm²',
            'difficulty': 'medium',
            'subject': subject,
            'grade': grade,
            'points': 15,
            'timeSuggestionSec': 20,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'question': 'Berapa hasil dari 144 ÷ 12?',
            'options': ['12', '10', '14', '11', '13'],
            'correctAnswer': 0,
            'explanation': '144 ÷ 12 = 12. Dapat dicek dengan 12 × 12 = 144',
            'difficulty': 'easy',
            'subject': subject,
            'grade': grade,
            'points': 10,
            'timeSuggestionSec': 15,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          }
        ];
      } else if (subject == 'General' && grade == '7') {
        sampleQuestions = [
          {
            'question': 'Siapa presiden pertama Indonesia?',
            'options': [
              'Soekarno',
              'Soeharto',
              'B.J. Habibie',
              'Megawati',
              'SBY'
            ],
            'correctAnswer': 0,
            'explanation':
                'Soekarno adalah presiden pertama Republik Indonesia yang menjabat dari 1945-1967',
            'difficulty': 'easy',
            'subject': subject,
            'grade': grade,
            'points': 10,
            'timeSuggestionSec': 15,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'question': 'Apa ibu kota Indonesia?',
            'options': ['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang'],
            'correctAnswer': 0,
            'explanation':
                'Jakarta adalah ibu kota negara Indonesia sejak kemerdekaan',
            'difficulty': 'easy',
            'subject': subject,
            'grade': grade,
            'points': 5,
            'timeSuggestionSec': 10,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'question': 'Berapa jumlah provinsi di Indonesia saat ini?',
            'options': ['34', '32', '35', '33', '36'],
            'correctAnswer': 0,
            'explanation':
                'Indonesia memiliki 34 provinsi termasuk DKI Jakarta, DI Yogyakarta, dan Aceh',
            'difficulty': 'medium',
            'subject': subject,
            'grade': grade,
            'points': 15,
            'timeSuggestionSec': 20,
            'createdBy': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          }
        ];
      }

      // Add questions to Firestore
      for (final questionData in sampleQuestions) {
        await firestore
            .collection('questionBanks')
            .doc(bankId)
            .collection('items')
            .add(questionData);
      }

      // Update totalQuestions count
      await firestore.collection('questionBanks').doc(bankId).update({
        'totalQuestions': sampleQuestions.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('📝 Added ${sampleQuestions.length} sample questions to $bankId');
    } catch (e) {
      print('❌ Error adding sample questions to $bankId: $e');
    }
  }

  Future<void> _startQuiz(QuestionBank questionBank) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final questions = await _onlineQuizService.getQuestionsFromBank(
        questionBank.id,
        limit: 10, // Limit to 10 questions per quiz
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada soal yang tersedia di bank soal ini'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Navigate to quiz screen with online questions
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineQuizPlayScreen(
            questionBank: questionBank,
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soal Online'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat bank soal...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadQuestionBanks,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questionBanks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tidak ada bank soal yang tersedia',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadQuestionBanks,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuestionBanks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questionBanks.length,
        itemBuilder: (context, index) {
          final questionBank = _questionBanks[index];
          return _buildQuestionBankCard(questionBank);
        },
      ),
    );
  }

  Widget _buildQuestionBankCard(QuestionBank questionBank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    questionBank.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    questionBank.grade,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              questionBank.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.subject,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  questionBank.subject,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.quiz,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${questionBank.totalQuestions} soal',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startQuiz(questionBank),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Mulai Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
