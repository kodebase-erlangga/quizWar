import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/quiz_models.dart';

class OfflineQuizService {
  static final OfflineQuizService _instance = OfflineQuizService._internal();
  factory OfflineQuizService() => _instance;
  OfflineQuizService._internal();

  // Cache for loaded categories
  final Map<String, QuizCategory> _cachedCategories = {};

  /// Available quiz categories for offline mode
  static const List<Map<String, dynamic>> availableCategories = [
    {
      'id': 'science',
      'name': 'Science',
      'description': 'Test your knowledge of basic science concepts',
      'icon': 'science',
      'color': 0xFF2196F3, // Blue
      'totalQuestions': 10,
      'difficulty': 'Mixed',
    },
    {
      'id': 'history',
      'name': 'History',
      'description': 'Explore important events and figures from world history',
      'icon': 'history_edu',
      'color': 0xFFFF9800, // Orange
      'totalQuestions': 10,
      'difficulty': 'Mixed',
    },
    {
      'id': 'sports',
      'name': 'Sports',
      'description': 'Test your knowledge about various sports and athletes',
      'icon': 'sports_soccer',
      'color': 0xFF4CAF50, // Green
      'totalQuestions': 10,
      'difficulty': 'Mixed',
    },
    {
      'id': 'movies',
      'name': 'Movies',
      'description': 'Test your knowledge about films, actors, and cinema',
      'icon': 'movie',
      'color': 0xFF9C27B0, // Purple
      'totalQuestions': 10,
      'difficulty': 'Mixed',
    },
  ];

  /// Get all available categories
  List<Map<String, dynamic>> getAvailableCategories() {
    return List.from(availableCategories);
  }

  /// Load quiz questions from JSON file
  Future<QuizCategory> loadQuizCategory(String categoryId) async {
    // Check cache first
    if (_cachedCategories.containsKey(categoryId)) {
      return _cachedCategories[categoryId]!;
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/questions/$categoryId.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final QuizCategory category = QuizCategory.fromJson(jsonData);

      // Cache the category
      _cachedCategories[categoryId] = category;

      return category;
    } catch (e) {
      throw Exception('Failed to load quiz category: $categoryId. Error: $e');
    }
  }

  /// Get random questions from a category
  List<QuizQuestion> getRandomQuestions(QuizCategory category, int count) {
    if (category.questions.length <= count) {
      return List.from(category.questions)..shuffle();
    }

    final List<QuizQuestion> shuffled = List.from(category.questions)
      ..shuffle();
    return shuffled.take(count).toList();
  }

  /// Get questions by difficulty
  List<QuizQuestion> getQuestionsByDifficulty(
      QuizCategory category, String difficulty) {
    return category.questions
        .where((q) => q.difficulty.toLowerCase() == difficulty.toLowerCase())
        .toList();
  }

  /// Calculate quiz result
  QuizResult calculateResult({
    required String categoryName,
    required List<QuizQuestion> questions,
    required List<int?> userAnswers,
    required Duration timeTaken,
  }) {
    final List<QuestionResult> questionResults = [];
    int correctCount = 0;

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = userAnswers[i];
      final isCorrect = userAnswer == question.correctAnswer;

      if (isCorrect) correctCount++;

      questionResults.add(QuestionResult(
        questionId: question.id,
        question: question.question,
        options: question.options,
        correctAnswer: question.correctAnswer,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        explanation: question.explanation,
        timeSpent:
            Duration(seconds: (timeTaken.inSeconds / questions.length).round()),
      ));
    }

    final int wrongCount = questions.length - correctCount;
    final double percentage = (correctCount / questions.length) * 100;

    return QuizResult(
      categoryName: categoryName,
      totalQuestions: questions.length,
      correctAnswers: correctCount,
      wrongAnswers: wrongCount,
      percentage: percentage,
      timeTaken: timeTaken,
      completedAt: DateTime.now(),
      questionResults: questionResults,
    );
  }

  /// Get category info by ID
  Map<String, dynamic>? getCategoryInfo(String categoryId) {
    try {
      return availableCategories.firstWhere((cat) => cat['id'] == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Check if category is available
  bool isCategoryAvailable(String categoryId) {
    return availableCategories.any((cat) => cat['id'] == categoryId);
  }

  /// Get total questions count for a category
  Future<int> getTotalQuestionsCount(String categoryId) async {
    try {
      final category = await loadQuizCategory(categoryId);
      return category.questions.length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedCategories.clear();
  }

  /// Get statistics for offline mode
  Map<String, dynamic> getOfflineStats() {
    return {
      'totalCategories': availableCategories.length,
      'cachedCategories': _cachedCategories.length,
      'availableCategories':
          availableCategories.map((cat) => cat['name']).toList(),
    };
  }
}
