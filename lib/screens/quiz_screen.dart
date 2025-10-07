import 'package:flutter/material.dart';
import 'dart:async';
import '../core/services/offline_quiz_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/quiz_models.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const QuizScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final OfflineQuizService _quizService = OfflineQuizService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  List<QuizQuestion> _questions = [];
  List<int?> _userAnswers = [];
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  String? _error;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  bool _showExplanation = false;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadQuestions();
    _startTimer();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      });
    });
  }

  Future<void> _loadQuestions() async {
    try {
      final category = await _quizService.loadQuizCategory(widget.categoryId);
      final questions = _quizService.getRandomQuestions(category, 10);

      setState(() {
        _questions = questions;
        _userAnswers = List.filled(questions.length, null);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(int selectedIndex) {
    if (_hasAnswered) return;

    setState(() {
      _userAnswers[_currentQuestionIndex] = selectedIndex;
      _hasAnswered = true;
      _showExplanation = true;
    });

    // Show next question after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showExplanation = false;
        _hasAnswered = false;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();

    final result = _quizService.calculateResult(
      categoryName: widget.categoryName,
      questions: _questions,
      userAnswers: _userAnswers,
      timeTaken: _elapsedTime,
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuizResultScreen(result: result),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppConstants.mediumAnimation,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildQuestionCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Questions...',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load Quiz',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
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
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitDialog(),
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.categoryName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatTime(_elapsedTime),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.largePadding),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _questions[_currentQuestionIndex];
    final userAnswer = _userAnswers[_currentQuestionIndex];

    return Container(
      margin: const EdgeInsets.all(AppConstants.largePadding),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question
              Text(
                question.question,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),

              // Options
              Expanded(
                child: ListView.builder(
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    return _buildOptionTile(question, index, userAnswer);
                  },
                ),
              ),

              // Explanation (if shown)
              if (_showExplanation) ...[
                const SizedBox(height: 24),
                _buildExplanation(question),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(QuizQuestion question, int index, int? userAnswer) {
    final isSelected = userAnswer == index;
    final isCorrect = index == question.correctAnswer;
    final showResult = _hasAnswered;

    Color getBackgroundColor() {
      if (!showResult) {
        return isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.grey.shade50;
      }

      if (isCorrect) {
        return Colors.green.withOpacity(0.2);
      } else if (isSelected && !isCorrect) {
        return Colors.red.withOpacity(0.2);
      }
      return Colors.grey.shade50;
    }

    Color getBorderColor() {
      if (!showResult) {
        return isSelected ? AppTheme.primaryColor : Colors.grey.shade300;
      }

      if (isCorrect) {
        return Colors.green;
      } else if (isSelected && !isCorrect) {
        return Colors.red;
      }
      return Colors.grey.shade300;
    }

    IconData? getIcon() {
      if (!showResult) return null;

      if (isCorrect) {
        return Icons.check_circle;
      } else if (isSelected && !isCorrect) {
        return Icons.cancel;
      }
      return null;
    }

    Color? getIconColor() {
      if (!showResult) return null;

      if (isCorrect) {
        return Colors.green;
      } else if (isSelected && !isCorrect) {
        return Colors.red;
      }
      return null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectAnswer(index),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: getBackgroundColor(),
            border: Border.all(color: getBorderColor(), width: 2),
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: getBorderColor(),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  question.options[index],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              if (getIcon() != null) ...[
                const SizedBox(width: 8),
                Icon(
                  getIcon(),
                  color: getIconColor(),
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanation(QuizQuestion question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Explanation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.explanation,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue.shade700,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Quiz?'),
          content: const Text(
              'Are you sure you want to exit? Your progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit quiz
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}
