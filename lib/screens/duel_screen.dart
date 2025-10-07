import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/challenge_service.dart';
import '../core/services/online_quiz_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/quiz_models.dart';
import 'duel_result_screen.dart';

/// Screen for conducting duels between two players
class DuelScreen extends StatefulWidget {
  final String duelId;

  const DuelScreen({
    super.key,
    required this.duelId,
  });

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen>
    with SingleTickerProviderStateMixin {
  final ChallengeService _challengeService = ChallengeService();
  final OnlineQuizService _quizService = OnlineQuizService();

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  DuelSession? _duelSession;
  List<QuizQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  bool _isAnswered = false;
  bool _isLoading = true;

  Timer? _questionTimer;
  int _timeLeft = 30; // 30 seconds per question
  late DateTime _questionStartTime;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDuelData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Load duel data and questions
  Future<void> _loadDuelData() async {
    try {
      // Listen to duel session changes
      _challengeService.getDuel(widget.duelId).listen((duelSession) async {
        if (duelSession == null) return;

        setState(() {
          _duelSession = duelSession;
        });

        // Check if duel is completed
        if (duelSession.status == DuelStatus.completed) {
          _navigateToResults();
          return;
        }

        // If duel status changed to inProgress, ensure we start
        if (duelSession.status == DuelStatus.inProgress && _questions.isEmpty) {
          print('🚀 Duel status changed to inProgress, loading questions...');
        }

        // Load questions if not loaded yet
        if (_questions.isEmpty) {
          await _loadQuestions();
        }

        // Check current question progress
        _updateCurrentQuestionIndex();
      });
    } catch (e) {
      print('❌ Error loading duel data: $e');
      _showErrorMessage('Gagal memuat data duel: ${e.toString()}');
    }
  }

  /// Load questions for the duel
  Future<void> _loadQuestions() async {
    try {
      print('🔍 Starting to load questions for duel...');
      if (_duelSession == null) {
        print('❌ DuelSession is null, cannot load questions');
        return;
      }

      print('🔍 DuelSession data:');
      print('  Question Bank ID: ${_duelSession!.questionBankId}');
      print('  Question IDs: ${_duelSession!.questionIds}');
      print('  Total questions needed: ${_duelSession!.questionIds.length}');

      final allQuestions = await _quizService.getQuestionsFromBank(
        _duelSession!.questionBankId,
      );

      print('🔍 Questions loaded from service: ${allQuestions.length}');
      for (var q in allQuestions) {
        print(
            '  Question ID: ${q.id} - ${q.question.substring(0, q.question.length > 50 ? 50 : q.question.length)}...');
      }

      // Filter to only questions in this duel
      _questions = allQuestions
          .where((q) => _duelSession!.questionIds.contains(q.id))
          .toList();

      print('🔍 Filtered questions for duel: ${_questions.length}');
      for (var q in _questions) {
        print(
            '  Filtered Question ID: ${q.id} - ${q.question.substring(0, q.question.length > 50 ? 50 : q.question.length)}...');
      }

      // If no questions found by ID matching, try to get the first N questions
      if (_questions.isEmpty && allQuestions.isNotEmpty) {
        print(
            '⚠️ No questions found by ID matching, using first ${_duelSession!.questionIds.length} questions');
        _questions =
            allQuestions.take(_duelSession!.questionIds.length).toList();

        // Update duel session with actual question IDs
        final actualQuestionIds = _questions.map((q) => q.id).toList();
        print('🔄 Updating duel with actual question IDs: $actualQuestionIds');

        try {
          await _challengeService.firestore
              .collection('duels')
              .doc(widget.duelId)
              .update({
            'questionIds': actualQuestionIds,
          });
          print('✅ Updated duel question IDs in Firestore');
        } catch (updateError) {
          print('⚠️ Failed to update question IDs: $updateError');
        }
      }

      // If still no questions, create sample questions
      if (_questions.isEmpty) {
        print('⚠️ Creating sample questions as fallback');
        _questions = _createSampleQuestions();
      }

      // Sort questions by their order in questionIds
      _questions.sort((a, b) {
        final indexA = _duelSession!.questionIds.indexOf(a.id);
        final indexB = _duelSession!.questionIds.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

      print('🔍 Final sorted questions: ${_questions.length}');

      setState(() {
        _isLoading = false;
      });

      if (_questions.isNotEmpty) {
        _startQuestionTimer();
        print('✅ Questions loaded successfully, timer started');
      } else {
        print('❌ No questions found for this duel');
        _showErrorMessage('Tidak ada soal yang ditemukan untuk duel ini');
      }
    } catch (e) {
      print('❌ Error loading questions: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      _showErrorMessage('Gagal memuat soal: ${e.toString()}');
    }
  }

  /// Create sample questions as fallback
  List<QuizQuestion> _createSampleQuestions() {
    // Create questions based on what was stored in duel session
    final questionCount = _duelSession?.questionIds.length ?? 10;
    final baseQuestions = [
      QuizQuestion(
        id: 'sample_1',
        question: 'Berapakah hasil dari 2 + 3 × 4?',
        options: ['14', '20', '12', '24'],
        correctAnswer: 0,
        explanation:
            'Sesuai urutan operasi, perkalian dikerjakan lebih dulu: 3 × 4 = 12, kemudian 2 + 12 = 14',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_2',
        question: 'Ibu kota Indonesia adalah...',
        options: ['Jakarta', 'Surabaya', 'Bandung', 'Medan'],
        correctAnswer: 0,
        explanation: 'Jakarta adalah ibu kota negara Indonesia',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_3',
        question: 'Planet terdekat dengan Matahari adalah...',
        options: ['Venus', 'Merkurius', 'Bumi', 'Mars'],
        correctAnswer: 1,
        explanation:
            'Merkurius adalah planet yang paling dekat dengan Matahari',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_4',
        question: 'Organ yang berfungsi memompa darah adalah...',
        options: ['Paru-paru', 'Jantung', 'Hati', 'Ginjal'],
        correctAnswer: 1,
        explanation:
            'Jantung adalah organ yang berfungsi memompa darah ke seluruh tubuh',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_5',
        question: 'Satuan kecepatan dalam SI adalah...',
        options: ['km/jam', 'm/s', 'cm/s', 'mil/jam'],
        correctAnswer: 1,
        explanation:
            'Satuan kecepatan dalam sistem SI adalah meter per sekon (m/s)',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_6',
        question: 'Rumus kimia air adalah...',
        options: ['H2O', 'CO2', 'NaCl', 'O2'],
        correctAnswer: 0,
        explanation:
            'Air memiliki rumus kimia H2O (2 atom hidrogen dan 1 atom oksigen)',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_7',
        question: 'Jika x = 5, maka nilai dari 2x + 3 adalah...',
        options: ['10', '13', '8', '15'],
        correctAnswer: 1,
        explanation: 'Substitusi x = 5 ke dalam 2x + 3: 2(5) + 3 = 10 + 3 = 13',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_8',
        question: 'Luas persegi dengan sisi 8 cm adalah...',
        options: ['32 cm²', '64 cm²', '16 cm²', '72 cm²'],
        correctAnswer: 1,
        explanation: 'Luas persegi = sisi × sisi = 8 × 8 = 64 cm²',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_9',
        question: 'Mean dari data 5, 7, 8, 6, 9 adalah...',
        options: ['6', '7', '8', '5'],
        correctAnswer: 1,
        explanation: 'Mean = (5+7+8+6+9)/5 = 35/5 = 7',
        difficulty: 'mudah',
      ),
      QuizQuestion(
        id: 'sample_10',
        question: 'Hasil dari 1/2 + 1/3 adalah...',
        options: ['2/5', '5/6', '1/6', '3/5'],
        correctAnswer: 1,
        explanation: '1/2 + 1/3 = 3/6 + 2/6 = 5/6',
        difficulty: 'sedang',
      ),
    ];

    // Return only the number of questions needed
    return baseQuestions.take(questionCount).toList();
  }

  /// Update current question index based on answered questions
  void _updateCurrentQuestionIndex() {
    if (_duelSession == null) return;

    final userId = _challengeService.auth.currentUser?.uid;
    if (userId == null) return;

    final isChallenger = userId == _duelSession!.challengerId;
    final answers = isChallenger
        ? _duelSession!.challengerAnswers
        : _duelSession!.challengedAnswers;

    // Find first unanswered question
    for (int i = 0; i < _questions.length; i++) {
      if (!answers.containsKey(_questions[i].id)) {
        setState(() {
          _currentQuestionIndex = i;
          _selectedAnswer = null;
          _isAnswered = false;
        });
        _startQuestionTimer();
        return;
      }
    }

    // All questions answered
    setState(() {
      _currentQuestionIndex = _questions.length;
    });
  }

  /// Start timer for current question
  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionStartTime = DateTime.now();

    setState(() {
      _timeLeft = 30;
    });

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeLeft =
            _timeLeft > 0 ? _timeLeft - 1 : 0; // Prevent negative values
      });

      if (_timeLeft <= 0) {
        timer.cancel();
        _submitAnswer(-1); // No answer selected - auto submit
      }
    });
  }

  /// Submit answer for current question
  Future<void> _submitAnswer(int answer) async {
    if (_isAnswered ||
        _duelSession == null ||
        _currentQuestionIndex >= _questions.length) {
      return;
    }

    try {
      _questionTimer?.cancel();
      final timeSpent = DateTime.now().difference(_questionStartTime).inSeconds;

      setState(() {
        _selectedAnswer = answer;
        _isAnswered = true;
      });

      await _challengeService.submitDuelAnswer(
        duelId: widget.duelId,
        questionId: _questions[_currentQuestionIndex].id,
        selectedAnswer: answer,
        timeSpent: timeSpent,
      );

      // Wait a moment to show the selected answer
      await Future.delayed(const Duration(seconds: 2));

      // Check if this is the last question
      if (_currentQuestionIndex >= _questions.length - 1) {
        print('🏁 Last question completed, navigating to results...');
        _navigateToResults();
        return;
      }

      // Move to next question
      _animationController.forward().then((_) {
        _animationController.reset();

        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _isAnswered = false;
        });

        if (_currentQuestionIndex < _questions.length) {
          print(
              '➡️ Moving to question ${_currentQuestionIndex + 1}/${_questions.length}');
          _startQuestionTimer();
        } else {
          print('🏁 All questions completed, navigating to results...');
          _navigateToResults();
        }
      });
    } catch (e) {
      print('❌ Error submitting answer: $e');
      _showErrorMessage('Gagal mengirim jawaban: ${e.toString()}');
    }
  }

  /// Navigate to results screen
  void _navigateToResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DuelResultScreen(duelId: widget.duelId),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Memuat duel...',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button during duel
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildProgressBar(),
                    _buildTimer(),
                    Expanded(
                      child: _buildQuestionContent(),
                    ),
                  ],
                ),
              ),
              // Debug overlay for development
              if (true) // Enable debug in development
                Positioned(
                  top: 50,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DEBUG:',
                          style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Questions: ${_questions.length}',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        Text(
                          'Current: $_currentQuestionIndex',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        Text(
                          'Loading: $_isLoading',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        if (_duelSession != null)
                          Text(
                            'Duel: ${_duelSession!.id.substring(0, 8)}...',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        children: [
          // Duel icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.sports_esports,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // Title and vs info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Duel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_duelSession != null)
                  Text(
                    '${_duelSession!.challengerId == _challengeService.auth.currentUser?.uid ? _duelSession!.challengedId : _duelSession!.challengerId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
              ],
            ),
          ),

          // Question counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentQuestionIndex / _questions.length).clamp(0.0, 1.0);

    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _timeLeft <= 10
            ? Colors.red.withOpacity(0.1)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _timeLeft <= 10
              ? Colors.red.withOpacity(0.3)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer,
            color: _timeLeft <= 10 ? Colors.red : AppTheme.textPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$_timeLeft detik',
            style: TextStyle(
              color: _timeLeft <= 10 ? Colors.red : AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    print('🔍 Building question content...');
    print('  Questions loaded: ${_questions.length}');
    print('  Current question index: $_currentQuestionIndex');
    print('  Is loading: $_isLoading');

    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      print('🔍 Showing completion screen');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'Semua soal selesai!',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Menunggu hasil...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    print('🔍 Rendering question: ${question.id} - ${question.question}');

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.0, 0.0),
      ).animate(_slideAnimation),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultBorderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                question.question,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
              ),
            ),

            const SizedBox(height: 24),

            // Answer options
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  return _buildAnswerOption(index, question.options[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(int index, String option) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == _questions[_currentQuestionIndex].correctAnswer;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (_isAnswered) {
      if (isSelected) {
        backgroundColor = isCorrect
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2);
        borderColor = isCorrect ? Colors.green : Colors.red;
        textColor = isCorrect ? Colors.green : Colors.red;
      } else if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green.withOpacity(0.5);
        textColor = Colors.green;
      } else {
        backgroundColor = Colors.white.withOpacity(0.05);
        borderColor = Colors.white.withOpacity(0.2);
        textColor = AppTheme.textPrimary;
      }
    } else {
      backgroundColor = isSelected
          ? AppTheme.primaryColor.withOpacity(0.2)
          : Colors.white.withOpacity(0.05);
      borderColor =
          isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.2);
      textColor = AppTheme.textPrimary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _submitAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Option letter
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: TextStyle(
                        color: _isAnswered && isSelected && !isCorrect
                            ? Colors.white
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Option text
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Check/cross icon for answered state
                if (_isAnswered && (isSelected || isCorrect))
                  Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
