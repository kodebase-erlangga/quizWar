import 'package:flutter/material.dart';
import 'dart:async';
import '../core/services/online_quiz_service.dart';
import '../models/quiz_models.dart';
import 'quiz_result_screen.dart';

class OnlineQuizPlayScreen extends StatefulWidget {
  final QuestionBank questionBank;
  final List<QuizQuestion> questions;

  const OnlineQuizPlayScreen({
    super.key,
    required this.questionBank,
    required this.questions,
  });

  @override
  State<OnlineQuizPlayScreen> createState() => _OnlineQuizPlayScreenState();
}

class _OnlineQuizPlayScreenState extends State<OnlineQuizPlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  Timer? _timer;
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  final List<QuestionResult> _questionResults = [];
  late Stopwatch _quizStopwatch;
  late Stopwatch _questionStopwatch;
  bool _isSubmitting = false;

  // Quiz timing
  final int _totalTimeInSeconds = 30 * 60; // 30 minutes
  late int _remainingTimeInSeconds;

  @override
  void initState() {
    super.initState();
    _remainingTimeInSeconds = _totalTimeInSeconds;
    _quizStopwatch = Stopwatch()..start();
    _questionStopwatch = Stopwatch()..start();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _quizStopwatch.stop();
    _questionStopwatch.stop();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTimeInSeconds > 0) {
          _remainingTimeInSeconds--;
        } else {
          _submitQuiz();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int answerIndex) {
    if (_isSubmitting) return;

    setState(() {
      _selectedAnswer = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_isSubmitting) return;

    final currentQuestion = widget.questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswer == currentQuestion.correctAnswer;

    // Record question result
    _questionResults.add(QuestionResult(
      questionId: currentQuestion.id,
      question: currentQuestion.question,
      options: currentQuestion.options,
      correctAnswer: currentQuestion.correctAnswer,
      userAnswer: _selectedAnswer,
      isCorrect: isCorrect,
      explanation: currentQuestion.explanation,
      timeSpent: Duration(milliseconds: _questionStopwatch.elapsedMilliseconds),
    ));

    _questionStopwatch.reset();
    _questionStopwatch.start();

    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      });

      _animationController.reset();
      _animationController.forward();
    } else {
      _submitQuiz();
    }
  }

  void _submitQuiz() {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    _timer?.cancel();
    _quizStopwatch.stop();

    final correctAnswers =
        _questionResults.where((result) => result.isCorrect).length;
    final totalQuestions = _questionResults.length;
    final percentage =
        totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;

    final quizResult = QuizResult(
      categoryName: widget.questionBank.name,
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      wrongAnswers: totalQuestions - correctAnswers,
      percentage: percentage,
      timeTaken: Duration(milliseconds: _quizStopwatch.elapsedMilliseconds),
      completedAt: DateTime.now(),
      questionResults: _questionResults,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(result: quizResult),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keluar dari Quiz?'),
          content: const Text(
              'Progress quiz akan hilang. Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.questions.length;

    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          title: Text(widget.questionBank.name),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitDialog,
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatTime(_remainingTimeInSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soal ${_currentQuestionIndex + 1} dari ${widget.questions.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: progress * _progressAnimation.value,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Question Content
            Expanded(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              currentQuestion.question,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Answer Options
                          Expanded(
                            child: ListView.builder(
                              itemCount: currentQuestion.options.length,
                              itemBuilder: (context, index) {
                                final isSelected = _selectedAnswer == index;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _selectAnswer(index),
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.1)
                                              : Colors.white,
                                          border: Border.all(
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[300]!,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.1),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                      : Colors.grey[400]!,
                                                  width: 2,
                                                ),
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 16,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${String.fromCharCode(65 + index)}. ${currentQuestion.options[index]}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Next Button
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != null && !_isSubmitting
                      ? _nextQuestion
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _currentQuestionIndex == widget.questions.length - 1
                        ? 'Selesai'
                        : 'Lanjut',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
