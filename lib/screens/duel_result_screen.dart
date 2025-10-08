import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/challenge_service.dart';
import '../core/services/online_quiz_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/quiz_models.dart';

/// Screen to display duel results and winner
class DuelResultScreen extends StatefulWidget {
  final String duelId;

  const DuelResultScreen({
    super.key,
    required this.duelId,
  });

  @override
  State<DuelResultScreen> createState() => _DuelResultScreenState();
}

class _DuelResultScreenState extends State<DuelResultScreen>
    with SingleTickerProviderStateMixin {
  final ChallengeService _challengeService = ChallengeService();
  final OnlineQuizService _quizService = OnlineQuizService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  DuelSession? _duelSession;
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;

  // Statistics from database
  int _challengerCorrectAnswers = 0;
  int _challengedCorrectAnswers = 0;
  int _totalQuestions = 0;
  double _challengerPercentage = 0.0;
  double _challengedPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDuelResults();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load duel results
  Future<void> _loadDuelResults() async {
    try {
      final duelDoc = await _challengeService.firestore
          .collection('duels')
          .doc(widget.duelId)
          .get();

      if (!duelDoc.exists) {
        throw Exception('Duel not found');
      }

      final duelData = duelDoc.data()!;

      print('🔍 Duel data loaded: ${duelData.keys}');
      print('📊 Challenger Score: ${duelData['challengerScore']}');
      print('📊 Challenged Score: ${duelData['challengedScore']}');
      print('🏆 Winner ID: ${duelData['winnerId']}');
      print('👤 Challenger ID: ${duelData['challengerId']}');
      print('👤 Challenged ID: ${duelData['challengedId']}');

      // Load statistics
      _challengerCorrectAnswers = duelData['challengerCorrectAnswers'] ?? 0;
      _challengedCorrectAnswers = duelData['challengedCorrectAnswers'] ?? 0;
      _totalQuestions = duelData['challengerTotalQuestions'] ??
          duelData['challengedTotalQuestions'] ??
          5;
      _challengerPercentage = duelData['challengerPercentage'] ?? 0.0;
      _challengedPercentage = duelData['challengedPercentage'] ?? 0.0;

      print(
          '📈 Challenger: $_challengerCorrectAnswers/$_totalQuestions (${_challengerPercentage.toStringAsFixed(1)}%)');
      print(
          '📈 Challenged: $_challengedCorrectAnswers/$_totalQuestions (${_challengedPercentage.toStringAsFixed(1)}%)');

      // Create DuelSession from DuelRoom data structure
      final duelSession = DuelSession(
        id: widget.duelId,
        challengeId: duelData['challengeId'] ?? '',
        challengerId: duelData['challengerId'] ?? '',
        challengedId: duelData['challengedId'] ?? '',
        questionBankId: duelData['questionBankId'] ?? 'General7-main',
        questionIds: List<String>.from(duelData['questionIds'] ?? []),
        challengerAnswers: _parseAnswers(duelData['challengerAnswers']),
        challengedAnswers: _parseAnswers(duelData['challengedAnswers']),
        status: _parseStatus(duelData['status']),
        startedAt: duelData['startedAt'] != null
            ? (duelData['startedAt'] as Timestamp).toDate()
            : DateTime.now(),
        completedAt: duelData['completedAt'] != null
            ? (duelData['completedAt'] as Timestamp).toDate()
            : null,
        challengerScore: duelData['challengerScore'] ?? 0,
        challengedScore: duelData['challengedScore'] ?? 0,
        winnerId: duelData['winnerId'],
      );

      // Load questions from the question bank
      List<QuizQuestion> questions = [];
      if (duelSession.questionBankId.isNotEmpty) {
        try {
          final allQuestions = await _quizService.getQuestionsFromBank(
            duelSession.questionBankId,
          );

          if (duelSession.questionIds.isNotEmpty) {
            questions = allQuestions
                .where((q) => duelSession.questionIds.contains(q.id))
                .toList();

            // Sort questions by their order in questionIds
            questions.sort((a, b) {
              final indexA = duelSession.questionIds.indexOf(a.id);
              final indexB = duelSession.questionIds.indexOf(b.id);
              return indexA.compareTo(indexB);
            });
          } else {
            questions = allQuestions;
          }
        } catch (e) {
          print('Error loading questions: $e');
          // Try to get questions from Firestore directly
          try {
            questions = await _quizService
                .getQuestionsFromBank(duelSession.questionBankId);
          } catch (e2) {
            print('Error loading questions from bank: $e2');
            questions = [];
          }
        }
      }

      setState(() {
        _duelSession = duelSession;
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading duel results: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('Gagal memuat hasil duel: ${e.toString()}');
    }
  }

  Map<String, DuelPlayerAnswer> _parseAnswers(dynamic answersData) {
    if (answersData == null) return {};

    try {
      final answers = Map<String, dynamic>.from(answersData);
      return answers.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key, DuelPlayerAnswer.fromMap(value));
        } else {
          // Handle legacy format or simple values
          int selectedAnswer;
          try {
            selectedAnswer = int.parse(value.toString());
          } catch (e) {
            selectedAnswer = -1; // Invalid answer
          }

          return MapEntry(
              key,
              DuelPlayerAnswer(
                selectedAnswer: selectedAnswer,
                answeredAt: DateTime.now(),
                timeSpent: 0, // Default time spent
              ));
        }
      });
    } catch (e) {
      print('Error parsing answers: $e');
      return {};
    }
  }

  DuelStatus _parseStatus(dynamic status) {
    if (status == null) return DuelStatus.waiting;

    switch (status.toString()) {
      case 'waiting':
        return DuelStatus.waiting;
      case 'playing':
      case 'inProgress':
        return DuelStatus.inProgress;
      case 'completed':
        return DuelStatus.completed;
      default:
        return DuelStatus.waiting;
    }
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

  /// Get current user ID
  String? get _currentUserId => _challengeService.auth.currentUser?.uid;

  /// Check if current user is the winner
  bool get _isWinner {
    if (_duelSession?.winnerId == null) return false;
    return _duelSession!.winnerId == _currentUserId;
  }

  /// Check if it's a tie
  bool get _isTie {
    return _duelSession?.winnerId == null &&
        _duelSession?.challengerScore == _duelSession?.challengedScore;
  }

  /// Get opponent score
  int get _opponentScore {
    if (_duelSession == null) return 0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger
        ? _duelSession!.challengedScore ?? 0
        : _duelSession!.challengerScore ?? 0;
  }

  /// Get current user score
  int get _userScore {
    if (_duelSession == null) return 0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger
        ? _duelSession!.challengerScore ?? 0
        : _duelSession!.challengedScore ?? 0;
  }

  /// Get current user correct answers
  int get _userCorrectAnswers {
    if (_duelSession == null) return 0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger ? _challengerCorrectAnswers : _challengedCorrectAnswers;
  }

  /// Get current user percentage
  double get _userPercentage {
    if (_duelSession == null) return 0.0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger ? _challengerPercentage : _challengedPercentage;
  }

  /// Get opponent correct answers
  int get _opponentCorrectAnswers {
    if (_duelSession == null) return 0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger ? _challengedCorrectAnswers : _challengerCorrectAnswers;
  }

  /// Get opponent percentage
  double get _opponentPercentage {
    if (_duelSession == null) return 0.0;
    final isChallenger = _currentUserId == _duelSession!.challengerId;
    return isChallenger ? _challengedPercentage : _challengerPercentage;
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
                  'Memuat hasil duel...',
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: Column(
                      children: [
                        _buildResultCard(),
                        const SizedBox(height: 24),
                        _buildScoreComparison(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              'Hasil Duel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // Result icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isWinner
                    ? Colors.amber.withOpacity(0.2)
                    : _isTie
                        ? Colors.grey.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isWinner
                      ? Colors.amber
                      : _isTie
                          ? Colors.grey
                          : Colors.red,
                  width: 2,
                ),
              ),
              child: Icon(
                _isWinner
                    ? Icons.emoji_events
                    : _isTie
                        ? Icons.handshake
                        : Icons.thumb_down,
                color: _isWinner
                    ? Colors.amber
                    : _isTie
                        ? Colors.grey
                        : Colors.red,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isWinner
                ? [
                    Colors.amber.withOpacity(0.2),
                    Colors.orange.withOpacity(0.1),
                  ]
                : _isTie
                    ? [
                        Colors.grey.withOpacity(0.2),
                        Colors.blueGrey.withOpacity(0.1),
                      ]
                    : [
                        Colors.red.withOpacity(0.2),
                        Colors.pink.withOpacity(0.1),
                      ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isWinner
                ? Colors.amber.withOpacity(0.5)
                : _isTie
                    ? Colors.grey.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Result icon
            Icon(
              _isWinner
                  ? Icons.emoji_events
                  : _isTie
                      ? Icons.handshake
                      : Icons.thumb_down,
              size: 64,
              color: _isWinner
                  ? Colors.amber
                  : _isTie
                      ? Colors.grey[600]
                      : Colors.red,
            ),

            const SizedBox(height: 16),

            // Result text
            Text(
              _isWinner
                  ? '🎉 KAMU MENANG! 🎉'
                  : _isTie
                      ? '🤝 SERI! 🤝'
                      : '😔 KAMU KALAH 😔',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Score
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                children: [
                  const TextSpan(text: 'Skor: '),
                  TextSpan(
                    text: '$_userCorrectAnswers/$_totalQuestions',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' vs '),
                  TextSpan(
                    text: '$_opponentCorrectAnswers/$_totalQuestions',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perbandingan Skor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // User score bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kamu',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$_userCorrectAnswers/$_totalQuestions (${_userPercentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _userPercentage / 100,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                minHeight: 8,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Opponent score bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lawan',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$_opponentCorrectAnswers/$_totalQuestions (${_opponentPercentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _opponentPercentage / 100,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.textSecondary),
                minHeight: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main action button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Kembali ke Beranda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.people),
            label: const Text('Kembali ke Teman'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.textSecondary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
