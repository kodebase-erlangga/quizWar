import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final String difficulty;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'] as int,
      explanation: json['explanation'] as String,
      difficulty: json['difficulty'] as String,
    );
  }

  /// Factory constructor for Firestore documents
  factory QuizQuestion.fromFirestore(String id, Map<String, dynamic> data) {
    // Handle different possible data structures
    String question = '';
    List<String> options = [];
    int correctAnswer = 0;
    String explanation = '';
    String difficulty = 'medium';

    // Parse question text
    if (data.containsKey('question')) {
      question = data['question']?.toString() ?? '';
    } else if (data.containsKey('questionText')) {
      question = data['questionText']?.toString() ?? '';
    } else if (data.containsKey('text')) {
      question = data['text']?.toString() ?? '';
    }

    // Parse options (handle both List and Map structures)
    if (data.containsKey('options')) {
      final optionsData = data['options'];
      if (optionsData is List) {
        options =
            List<String>.from(optionsData.map((e) => e?.toString() ?? ''));
      } else if (optionsData is Map) {
        // Convert map to list (for structures like {0: "option1", 1: "option2"})
        final sortedKeys = (optionsData.keys.toList()..sort());
        options = sortedKeys
            .map((key) => optionsData[key]?.toString() ?? '')
            .toList();
      }
    }

    // Ensure we have at least 4 options
    while (options.length < 4) {
      options.add('Option ${options.length + 1}');
    }

    // Parse correct answer (handle both int and string)
    if (data.containsKey('correctAnswer')) {
      final correctAnswerData = data['correctAnswer'];
      if (correctAnswerData is int) {
        correctAnswer = correctAnswerData;
      } else if (correctAnswerData is String) {
        correctAnswer = int.tryParse(correctAnswerData) ?? 0;
      }
    } else if (data.containsKey('answerIndex')) {
      final answerIndex = data['answerIndex'];
      if (answerIndex is int) {
        correctAnswer = answerIndex;
      } else if (answerIndex is String) {
        correctAnswer = int.tryParse(answerIndex) ?? 0;
      }
    }

    // Ensure correct answer is within valid range
    correctAnswer = correctAnswer.clamp(0, options.length - 1);

    // Parse explanation
    if (data.containsKey('explanation')) {
      explanation = data['explanation']?.toString() ?? '';
    } else if (data.containsKey('explanationText')) {
      explanation = data['explanationText']?.toString() ?? '';
    }

    // Parse difficulty
    if (data.containsKey('difficulty')) {
      difficulty = data['difficulty']?.toString() ?? 'medium';
    } else if (data.containsKey('level')) {
      difficulty = data['level']?.toString() ?? 'medium';
    }

    return QuizQuestion(
      id: id,
      question: question.isEmpty ? 'Question text not available' : question,
      options: options,
      correctAnswer: correctAnswer,
      explanation:
          explanation.isEmpty ? 'No explanation available' : explanation,
      difficulty: difficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'difficulty': difficulty,
    };
  }
}

class QuizCategory {
  final String category;
  final String description;
  final String difficulty;
  final List<QuizQuestion> questions;

  QuizCategory({
    required this.category,
    required this.description,
    required this.difficulty,
    required this.questions,
  });

  factory QuizCategory.fromJson(Map<String, dynamic> json) {
    return QuizCategory(
      category: json['category'] as String,
      description: json['description'] as String,
      difficulty: json['difficulty'] as String,
      questions: (json['questions'] as List)
          .map((questionJson) => QuizQuestion.fromJson(questionJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizResult {
  final String categoryName;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final double percentage;
  final Duration timeTaken;
  final DateTime completedAt;
  final List<QuestionResult> questionResults;

  QuizResult({
    required this.categoryName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.percentage,
    required this.timeTaken,
    required this.completedAt,
    required this.questionResults,
  });

  String get grade {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  String get gradeDescription {
    switch (grade) {
      case 'A':
        return 'Excellent!';
      case 'B':
        return 'Very Good!';
      case 'C':
        return 'Good!';
      case 'D':
        return 'Fair';
      case 'F':
        return 'Need Improvement';
      default:
        return '';
    }
  }
}

class QuestionResult {
  final String questionId;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final int? userAnswer;
  final bool isCorrect;
  final String explanation;
  final Duration timeSpent;

  QuestionResult({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.userAnswer,
    required this.isCorrect,
    required this.explanation,
    required this.timeSpent,
  });
}

/// Model untuk membuat soal baru berdasarkan struktur Firestore
class CreateQuestionModel {
  final int answerIndex;
  final String createdBy;
  final String explanation;
  final String grade;
  final bool isCopied;
  final String locale;
  final int number;
  final List<String> options;
  final int points;
  final String qid;
  final String question;
  final bool randomizeOptions;
  final QuestionSource source;
  final String subject;
  final int timeSuggestionSec;
  final int total;
  final String updatedBy;
  final int version;

  CreateQuestionModel({
    required this.answerIndex,
    required this.createdBy,
    required this.explanation,
    required this.grade,
    this.isCopied = false,
    this.locale = 'id-ID',
    required this.number,
    required this.options,
    this.points = 10,
    required this.qid,
    required this.question,
    this.randomizeOptions = true,
    required this.source,
    required this.subject,
    this.timeSuggestionSec = 15,
    this.total = 10,
    required this.updatedBy,
    this.version = 1,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'answerIndex': answerIndex,
      'createdBy': createdBy,
      'explanation': explanation,
      'grade': grade,
      'isCopied': isCopied,
      'locale': locale,
      'number': number,
      'options': options,
      'points': points,
      'qid': qid,
      'question': question,
      'randomizeOptions': randomizeOptions,
      'source': source.toMap(),
      'subject': subject,
      'timeSuggestionSec': timeSuggestionSec,
      'total': total,
      'updatedBy': updatedBy,
      'version': version,
    };
  }

  factory CreateQuestionModel.fromFirestore(Map<String, dynamic> data) {
    return CreateQuestionModel(
      answerIndex: data['answerIndex'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      explanation: data['explanation'] ?? '',
      grade: data['grade'] ?? '',
      isCopied: data['isCopied'] ?? false,
      locale: data['locale'] ?? 'id-ID',
      number: data['number'] ?? 1,
      options: List<String>.from(data['options'] ?? []),
      points: data['points'] ?? 10,
      qid: data['qid'] ?? '',
      question: data['question'] ?? '',
      randomizeOptions: data['randomizeOptions'] ?? true,
      source: QuestionSource.fromMap(data['source'] ?? {}),
      subject: data['subject'] ?? '',
      timeSuggestionSec: data['timeSuggestionSec'] ?? 15,
      total: data['total'] ?? 10,
      updatedBy: data['updatedBy'] ?? '',
      version: data['version'] ?? 1,
    );
  }
}

class QuestionSource {
  final String bookTitle;
  final int page;
  final String subject;

  QuestionSource({
    required this.bookTitle,
    required this.page,
    required this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookTitle': bookTitle,
      'page': page,
      'subject': subject,
    };
  }

  factory QuestionSource.fromMap(Map<String, dynamic> map) {
    return QuestionSource(
      bookTitle: map['bookTitle'] ?? '',
      page: map['page'] ?? 1,
      subject: map['subject'] ?? '',
    );
  }
}

/// Model untuk user profile
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  final DateTime createdAt;
  final int questionsCreated;
  final int quizzesTaken;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.createdAt,
    this.questionsCreated = 0,
    this.quizzesTaken = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'createdAt': createdAt.toIso8601String(),
      'questionsCreated': questionsCreated,
      'quizzesTaken': quizzesTaken,
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    // Handle createdAt field - could be Timestamp or String
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    return UserProfile(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? data['nickname'] ?? 'Unknown User',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      createdAt: createdAt,
      questionsCreated: data['questionsCreated'] ?? 0,
      quizzesTaken: data['quizzesTaken'] ?? 0,
    );
  }
}

/// Challenge model for duel challenges between friends
class Challenge {
  final String id;
  final String challengerId;
  final String challengerName;
  final String challengedId;
  final String challengedName;
  final String questionBankId;
  final String questionBankName;
  final String questionBankSubject;
  final String questionBankGrade;
  final int totalQuestions;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? winnerId;
  final String? winnerName;
  final String? duelId; // Added duelId field
  final bool navigated; // Added navigated field to prevent auto-navigation

  Challenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengedId,
    required this.challengedName,
    required this.questionBankId,
    required this.questionBankName,
    required this.questionBankSubject,
    required this.questionBankGrade,
    required this.totalQuestions,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.winnerId,
    this.winnerName,
    this.duelId, // Added duelId parameter
    this.navigated = false, // Default to false
  });

  Map<String, dynamic> toFirestore() {
    return {
      'challengerId': challengerId,
      'challengerName': challengerName,
      'challengedId': challengedId,
      'challengedName': challengedName,
      'questionBankId': questionBankId,
      'questionBankName': questionBankName,
      'questionBankSubject': questionBankSubject,
      'questionBankGrade': questionBankGrade,
      'totalQuestions': totalQuestions,
      'status': status.name, // Use .name instead of .toString()
      'createdAt': createdAt,
      'acceptedAt': acceptedAt,
      'completedAt': completedAt,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'duelId': duelId, // Include duelId
      'navigated': navigated, // Include navigated flag
    };
  }

  factory Challenge.fromFirestore(String id, Map<String, dynamic> data) {
    return Challenge(
      id: id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? '',
      challengedId: data['challengedId'] ?? '',
      challengedName: data['challengedName'] ?? '',
      questionBankId: data['questionBankId'] ?? '',
      questionBankName: data['questionBankName'] ?? '',
      questionBankSubject: data['questionBankSubject'] ?? 'General',
      questionBankGrade: data['questionBankGrade'] ?? '',
      totalQuestions: data['totalQuestions'] ?? 10,
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == data['status'], // Use .name instead of .toString()
        orElse: () => ChallengeStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      winnerId: data['winnerId'],
      winnerName: data['winnerName'],
      duelId: data['duelId'], // Include duelId
      navigated: data['navigated'] ??
          false, // Include navigated flag with default false
    );
  }

  factory Challenge.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Challenge.fromFirestore(doc.id, data);
  }
}

/// Duel session model for active duels
class DuelSession {
  final String id;
  final String challengeId;
  final String challengerId;
  final String challengedId;
  final String questionBankId;
  final List<String> questionIds;
  final Map<String, DuelPlayerAnswer> challengerAnswers;
  final Map<String, DuelPlayerAnswer> challengedAnswers;
  final DuelStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? challengerScore;
  final int? challengedScore;
  final String? winnerId;

  DuelSession({
    required this.id,
    required this.challengeId,
    required this.challengerId,
    required this.challengedId,
    required this.questionBankId,
    required this.questionIds,
    required this.challengerAnswers,
    required this.challengedAnswers,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.challengerScore,
    this.challengedScore,
    this.winnerId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'challengeId': challengeId,
      'challengerId': challengerId,
      'challengedId': challengedId,
      'questionBankId': questionBankId,
      'questionIds': questionIds,
      'challengerAnswers': challengerAnswers.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'challengedAnswers': challengedAnswers.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'status': status.name, // Use .name instead of .toString()
      'startedAt': startedAt,
      'completedAt': completedAt,
      'challengerScore': challengerScore,
      'challengedScore': challengedScore,
      'winnerId': winnerId,
    };
  }

  factory DuelSession.fromFirestore(String id, Map<String, dynamic> data) {
    Map<String, DuelPlayerAnswer> parseAnswers(Map<String, dynamic>? answers) {
      if (answers == null) return {};
      return answers.map(
        (key, value) => MapEntry(
          key,
          DuelPlayerAnswer.fromMap(value as Map<String, dynamic>),
        ),
      );
    }

    return DuelSession(
      id: id,
      challengeId: data['challengeId'] ?? '',
      challengerId: data['challengerId'] ?? '',
      challengedId: data['challengedId'] ?? '',
      questionBankId: data['questionBankId'] ?? '',
      questionIds: List<String>.from(data['questionIds'] ?? []),
      challengerAnswers: parseAnswers(data['challengerAnswers']),
      challengedAnswers: parseAnswers(data['challengedAnswers']),
      status: DuelStatus.values.firstWhere(
        (e) => e.name == data['status'], // Use .name instead of .toString()
        orElse: () => DuelStatus.waiting,
      ),
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      challengerScore: data['challengerScore'],
      challengedScore: data['challengedScore'],
      winnerId: data['winnerId'],
    );
  }

  DuelSession copyWith({
    String? id,
    String? challengeId,
    String? challengerId,
    String? challengedId,
    String? questionBankId,
    List<String>? questionIds,
    Map<String, DuelPlayerAnswer>? challengerAnswers,
    Map<String, DuelPlayerAnswer>? challengedAnswers,
    DuelStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? challengerScore,
    int? challengedScore,
    String? winnerId,
  }) {
    return DuelSession(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      challengerId: challengerId ?? this.challengerId,
      challengedId: challengedId ?? this.challengedId,
      questionBankId: questionBankId ?? this.questionBankId,
      questionIds: questionIds ?? this.questionIds,
      challengerAnswers: challengerAnswers ?? this.challengerAnswers,
      challengedAnswers: challengedAnswers ?? this.challengedAnswers,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      challengerScore: challengerScore ?? this.challengerScore,
      challengedScore: challengedScore ?? this.challengedScore,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}

/// Player answer in a duel
class DuelPlayerAnswer {
  final int selectedAnswer;
  final DateTime answeredAt;
  final int timeSpent; // in seconds

  DuelPlayerAnswer({
    required this.selectedAnswer,
    required this.answeredAt,
    required this.timeSpent,
  });

  Map<String, dynamic> toMap() {
    return {
      'selectedAnswer': selectedAnswer,
      'answeredAt': answeredAt,
      'timeSpent': timeSpent,
    };
  }

  factory DuelPlayerAnswer.fromMap(Map<String, dynamic> map) {
    return DuelPlayerAnswer(
      selectedAnswer: map['selectedAnswer'] ?? -1,
      answeredAt: (map['answeredAt'] as Timestamp).toDate(),
      timeSpent: map['timeSpent'] ?? 0,
    );
  }
}

/// Challenge status enumeration
enum ChallengeStatus {
  pending,
  accepted,
  rejected,
  completed,
  expired,
}

/// Duel status enumeration
enum DuelStatus {
  waiting,
  inProgress,
  completed,
  abandoned,
}
