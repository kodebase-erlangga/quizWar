import 'package:flutter/material.dart';
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
      print('🎨 DEBUG: _questionBanks.length = ${_questionBanks.length}');
      print('🎨 DEBUG: _isLoading = $_isLoading');
      print('🎨 DEBUG: _error = $_error');
    } catch (e) {
      print('❌ OnlineQuizScreen: Error loading question banks: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
    print(
        '🖥️ DEBUG: Building UI - isLoading: $_isLoading, error: $_error, questionBanks.length: ${_questionBanks.length}');

    if (_isLoading) {
      print('🔄 DEBUG: Showing loading indicator');
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
      print('❌ DEBUG: Showing error screen');
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
      print('📭 DEBUG: Showing empty state');
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

    print(
        '📋 DEBUG: Showing question banks list with ${_questionBanks.length} items');

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
