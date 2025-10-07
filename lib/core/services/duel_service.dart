import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/online_quiz_service.dart';
import '../../models/quiz_models.dart';

class DuelService {
  static final DuelService _instance = DuelService._internal();
  factory DuelService() => _instance;
  DuelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OnlineQuizService _quizService = OnlineQuizService();

  StreamSubscription? _onlineListener;
  StreamSubscription? _challengeListener;
  StreamSubscription? _roomListener;

  // Get all friends with their online status
  Stream<List<OnlineUser>> getOnlineFriends() async* {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      yield [];
      return;
    }

    try {
      // Get current user's friends
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      if (friendsSnapshot.docs.isEmpty) {
        yield [];
        return;
      }

      // Get friend user IDs
      final friendIds = friendsSnapshot.docs.map((doc) => doc.id).toList();

      // Listen to users collection for ALL friends (online and offline)
      yield* _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => OnlineUser.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error getting friends: $e');
      yield [];
    }
  }

  // Set user online status
  Future<void> setUserOnline(String userId, String username) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'duelStatus': 'available',
      });
    } catch (e) {
      print('Error setting user online: $e');
    }
  }

  // Set user offline
  Future<void> setUserOffline(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'duelStatus': 'offline',
      });
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Get available question banks
  Future<List<QuestionBank>> getAvailableQuestionBanks() async {
    try {
      return await _quizService.getAvailableQuestionBanks();
    } catch (e) {
      print('❌ Error getting question banks: $e');
      return [];
    }
  }

  // Send challenge to friend with selected question bank
  Future<String?> sendChallenge(
      String challengedUserId, String challengedUsername,
      {QuestionBank? selectedQuestionBank}) async {
    try {
      final challengerId = _auth.currentUser?.uid;
      if (challengerId == null) {
        print('❌ No current user found when sending challenge');
        return null;
      }

      print('🎯 Sending challenge from $challengerId to $challengedUserId');

      // Get challenger info
      final challengerDoc =
          await _firestore.collection('users').doc(challengerId).get();
      final challengerData = challengerDoc.data();
      final challengerUsername =
          challengerData?['nickname'] ?? 'Unknown Player';

      // Use selected question bank or default
      final questionBank = selectedQuestionBank ??
          QuestionBank(
            id: 'General7-main',
            name: 'General Knowledge',
            description: 'General knowledge questions',
            subject: 'General',
            grade: '7',
            totalQuestions: 10,
            createdAt: DateTime.now(),
          );

      final challengeData = {
        'challengerId': challengerId,
        'challengerName': challengerUsername,
        'challengedId': challengedUserId,
        'challengedName': challengedUsername,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            DateTime.now().add(Duration(minutes: 5)).millisecondsSinceEpoch,
        'questionBankId': questionBank.id,
        'questionBankName': questionBank.name,
        'questionBankSubject': questionBank.subject,
        'questionBankGrade': questionBank.grade,
        'totalQuestions': questionBank.totalQuestions,
        'navigated': false, // Initialize navigated to false
      };

      print('📝 Challenge data to save: $challengeData');

      final docRef =
          await _firestore.collection('challenges').add(challengeData);

      print('✅ Challenge created with ID: ${docRef.id}');

      // Update challenger status
      await _firestore.collection('users').doc(challengerId).update({
        'duelStatus': 'challenging',
      });

      print('📊 Updated challenger status to challenging');

      return docRef.id;
    } catch (e) {
      print('❌ Error sending challenge: $e');
      return null;
    }
  }

  // Listen for incoming challenges
  Stream<List<Challenge>> listenForChallenges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ No current user found when listening for challenges');
      return Stream.value([]);
    }

    print('👂 Started listening for challenges for user: $userId');

    return _firestore
        .collection('challenges')
        .where('challengedId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(10) // Limit to recent 10 challenges
        .snapshots()
        .map((snapshot) {
      print('📥 Received ${snapshot.docs.length} challenges for user $userId');
      final challenges = snapshot.docs.map((doc) {
        print('🎯 Challenge data: ${doc.data()}');
        return Challenge.fromFirestore(doc.id, doc.data());
      }).toList();
      return challenges;
    }).handleError((error) {
      print('❌ Error in challenge stream: $error');
      return <Challenge>[];
    });
  }

  // Listen for sent challenges (for challenger)
  Stream<List<Challenge>> listenForSentChallenges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('challenges')
        .where('challengerId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Listen for accepted challenges (for challenger to know when to navigate to duel)
  Stream<List<Challenge>> listenForAcceptedChallenges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('challenges')
        .where('challengerId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('navigated',
            isEqualTo:
                false) // Only show challenges that haven't been navigated to
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Mark challenge as navigated to prevent auto-navigation
  Future<void> markChallengeAsNavigated(String challengeId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'navigated': true,
      });
      print('✅ Marked challenge as navigated: $challengeId');
    } catch (e) {
      print('❌ Error marking challenge as navigated: $e');
    }
  }

  // Accept challenge
  Future<String?> acceptChallenge(String challengeId) async {
    try {
      print('✅ Accepting challenge: $challengeId');

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ No current user when accepting challenge');
        return null;
      }

      // Get challenge data
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) {
        print('❌ Challenge not found: $challengeId');
        return null;
      }

      final challengeData = challengeDoc.data()!;

      print('📊 Challenge data: $challengeData');
      print('🔐 Current user: $userId');
      print('🎯 Challenger: ${challengeData['challengerId']}');
      print('🎯 Challenged: ${challengeData['challengedId']}');
      ;

      // Create duel room
      final duelData = {
        'challengeId': challengeId,
        'challengerId': challengeData['challengerId'],
        'challengerName': challengeData['challengerName'],
        'challengedId': challengeData['challengedId'],
        'challengedName': challengeData['challengedName'],
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'completedAt': null,
        'questionBankId': challengeData['questionBankId'] ?? 'General7-main',
        'currentQuestion': 0,
        'challengerAnswers': {},
        'challengedAnswers': {},
        'challengerScore': 0,
        'challengedScore': 0,
        'challengerReady': false,
        'challengedReady': false,
        'challengerFinished': false,
        'challengedFinished': false,
        'winnerId': null,
        'questions': [], // Will be populated when game starts
      };

      // Use batch for atomic operations (only for challenge and duel)
      final batch = _firestore.batch();

      // Create duel
      final duelRef = _firestore.collection('duels').doc();
      batch.set(duelRef, duelData);

      // Update challenge status
      batch.update(
        _firestore.collection('challenges').doc(challengeId),
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'duelId': duelRef.id,
        },
      );

      await batch.commit();

      // Update current user's status separately (since we can only update our own user)
      try {
        await _firestore.collection('users').doc(userId).update({
          'duelStatus': 'in_duel',
          'currentDuelId': duelRef.id,
        });
        print('✅ Updated current user status');
      } catch (e) {
        print('⚠️ Failed to update user status: $e');
      }

      print('✅ Challenge accepted, duel created: ${duelRef.id}');

      return duelRef.id;
    } catch (e) {
      print('❌ Error accepting challenge: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  // Decline challenge
  Future<void> declineChallenge(String challengeId) async {
    try {
      print('🚫 Rejecting challenge: $challengeId');

      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) {
        print('❌ Challenge not found: $challengeId');
        return;
      }

      final challengeData = challengeDoc.data()!;
      final challengerId = challengeData['challengerId'];
      final currentUserId = _auth.currentUser?.uid;

      print('📊 Challenge data: $challengeData');
      print('🔐 Current user: $currentUserId');
      print('🎯 Challenger: $challengerId');
      print('🎯 Challenged: ${challengeData['challengedId']}');

      // Only update challenge status - let challenger handle their own status
      print('📝 Updating challenge status to rejected...');
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Challenge rejected successfully');
    } catch (e) {
      print('❌ Error rejecting challenge: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  // Listen to duel room
  Stream<DuelRoom?> listenToRoom(String duelId) {
    return _firestore.collection('duels').doc(duelId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DuelRoom.fromFirestore(doc);
    });
  }

  // Set player ready
  Future<void> setPlayerReady(String duelId, bool isChallenger) async {
    try {
      final field = isChallenger ? 'challengerReady' : 'challengedReady';

      print('🔄 Setting $field to true for duel: $duelId');

      // Update ready status
      await _firestore.collection('duels').doc(duelId).update({
        field: true,
      });

      print('✅ Player ready status updated: $field = true');

      // Verify the update by reading back
      final doc = await _firestore.collection('duels').doc(duelId).get();
      if (doc.exists) {
        final data = doc.data()!;
        print(
            '📊 Verified status: challengerReady=${data['challengerReady']}, challengedReady=${data['challengedReady']}');
      }
    } catch (e) {
      print('❌ Error setting player ready: $e');
      rethrow;
    }
  }

  // Start game (load questions and begin)
  Future<void> startGame(String duelId) async {
    try {
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (!duelDoc.exists) return;

      final duelData = duelDoc.data()!;
      final questionBankId = duelData['questionBankId'] as String;

      // Load questions from question bank
      final questions = await _loadQuestionsFromBank(questionBankId);

      if (questions.isEmpty) {
        print('No questions found in bank: $questionBankId');
        return;
      }

      // Convert questions to map format for Firestore
      final questionsData = questions
          .map((q) => {
                'id': q.id,
                'question': q.question,
                'options': q.options,
                'correctAnswer': q.correctAnswer,
                'timeLimit': 30, // 30 seconds per question
              })
          .toList();

      await _firestore.collection('duels').doc(duelId).update({
        'status': 'playing',
        'startedAt': FieldValue.serverTimestamp(),
        'questions': questionsData,
        'totalQuestions': questionsData.length,
      });
    } catch (e) {
      print('Error starting game: $e');
    }
  }

  // Load questions from question bank
  Future<List<QuizQuestion>> _loadQuestionsFromBank(String bankId) async {
    try {
      // Get questions from the specified bank
      final questionsSnapshot = await _firestore
          .collection('questionBanks')
          .doc(bankId)
          .collection('items')
          .limit(5) // Limit to 5 questions for duel
          .get();

      if (questionsSnapshot.docs.isEmpty) {
        print('No questions found in bank: $bankId');
        return [];
      }

      return questionsSnapshot.docs
          .map((doc) => QuizQuestion.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error loading questions: $e');
      return [];
    }
  }

  // Submit answer
  Future<void> submitAnswer(String duelId, int questionIndex, int answer,
      int timeUsed, bool isChallenger) async {
    try {
      final field = isChallenger ? 'challengerAnswers' : 'challengedAnswers';

      await _firestore.collection('duels').doc(duelId).update({
        '$field.$questionIndex': {
          'selectedAnswer': answer, // Changed from 'answer' to 'selectedAnswer'
          'timeSpent': timeUsed, // Changed from 'timeUsed' to 'timeSpent'
          'answeredAt': FieldValue.serverTimestamp(),
        }
      });

      print(
          '✅ Answer submitted - Question: $questionIndex, Answer: $answer, Time: $timeUsed');

      // Check if this was the last question
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (duelDoc.exists) {
        final data = duelDoc.data()!;
        final questions = data['questions'] as List;

        if (questionIndex >= questions.length - 1) {
          // Mark player as finished
          final finishedField =
              isChallenger ? 'challengerFinished' : 'challengedFinished';
          await _firestore.collection('duels').doc(duelId).update({
            finishedField: true,
          });

          // Calculate final score
          await _calculateScore(duelId, isChallenger);
        }
      }
    } catch (e) {
      print('Error submitting answer: $e');
    }
  }

  // Calculate final score
  Future<void> _calculateScore(String duelId, bool isChallenger) async {
    try {
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (!duelDoc.exists) return;

      final data = duelDoc.data()!;
      final questions = data['questions'] as List;
      final answersField =
          isChallenger ? 'challengerAnswers' : 'challengedAnswers';
      final scoreField = isChallenger ? 'challengerScore' : 'challengedScore';
      final answers = data[answersField] as Map<String, dynamic>? ?? {};

      int totalScore = 0;

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i] as Map<String, dynamic>;
        final answerKey = i.toString();
        final answer = answers[answerKey] as Map<String, dynamic>?;

        if (answer != null) {
          final selectedAnswer = answer['selectedAnswer'] as int? ?? -1;
          final correctAnswer = question['correct'] as int? ?? 0;

          if (selectedAnswer == correctAnswer) {
            // Correct answer: base score + time bonus
            final timeSpent = answer['timeSpent'] as int? ?? 20;
            final timeLimit = 20; // 20 seconds per question
            final timeBonus = (timeLimit - timeSpent).clamp(0, timeLimit);
            totalScore += 100 + timeBonus;
          }
        }
      }

      print(
          '📊 Calculated score for ${isChallenger ? 'challenger' : 'challenged'}: $totalScore');

      await _firestore.collection('duels').doc(duelId).update({
        scoreField: totalScore,
      });

      // Check if both players finished
      final challengerFinished = data['challengerFinished'] ?? false;
      final challengedFinished = data['challengedFinished'] ?? false;

      print(
          '🏁 Players finished - Challenger: $challengerFinished, Challenged: $challengedFinished');

      if (challengerFinished && challengedFinished) {
        await _finalizeDuel(duelId);
      }
    } catch (e) {
      print('Error calculating score: $e');
    }
  }

  // Mark player as finished manually
  Future<void> markPlayerFinished(String duelId, bool isChallenger) async {
    try {
      final finishedField =
          isChallenger ? 'challengerFinished' : 'challengedFinished';

      await _firestore.collection('duels').doc(duelId).update({
        finishedField: true,
      });

      // Calculate final score
      await _calculateScore(duelId, isChallenger);
    } catch (e) {
      print('Error marking player finished: $e');
    }
  }

  // Finalize duel (determine winner and cleanup)
  Future<void> _finalizeDuel(String duelId) async {
    try {
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (!duelDoc.exists) return;

      final data = duelDoc.data()!;
      final challengerScore = data['challengerScore'] as int? ?? 0;
      final challengedScore = data['challengedScore'] as int? ?? 0;

      String? winnerId;
      if (challengerScore > challengedScore) {
        winnerId = data['challengerId'];
      } else if (challengedScore > challengerScore) {
        winnerId = data['challengedId'];
      }
      // null means tie

      await _firestore.collection('duels').doc(duelId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'winnerId': winnerId,
      });

      // Reset current user's status only (to avoid permission issues)
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        try {
          await _firestore.collection('users').doc(currentUserId).update({
            'duelStatus': 'available',
            'currentDuelId': null,
          });
          print('✅ Updated current user status after duel completion');
        } catch (e) {
          print('⚠️ Failed to update user status: $e');
        }
      }
    } catch (e) {
      print('Error finalizing duel: $e');
    }
  }

  // Cancel challenge (for challenger)
  Future<void> cancelChallenge(String challengeId) async {
    try {
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) return;

      final challengeData = challengeDoc.data()!;

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Reset challenger status
      await _firestore
          .collection('users')
          .doc(challengeData['challengerId'])
          .update({
        'duelStatus': 'available',
      });
    } catch (e) {
      print('Error cancelling challenge: $e');
    }
  }

  // Clean up listeners
  void dispose() {
    _onlineListener?.cancel();
    _challengeListener?.cancel();
    _roomListener?.cancel();
  }
}

// Models for Firestore data
class OnlineUser {
  final String id;
  final String username;
  final String nickname;
  final bool isOnline;
  final String duelStatus;
  final DateTime? lastSeen;

  OnlineUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.isOnline,
    required this.duelStatus,
    this.lastSeen,
  });

  factory OnlineUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OnlineUser(
      id: doc.id,
      username: data['nickname'] ?? data['uid'] ?? 'Unknown',
      nickname: data['nickname'] ?? 'Unknown',
      isOnline: data['isOnline'] ?? false,
      duelStatus: data['duelStatus'] ?? 'offline',
      lastSeen: data['lastSeen']?.toDate(),
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswer;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromFirestore(String id, Map<String, dynamic> data) {
    return QuizQuestion(
      id: id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
    };
  }
}

class DuelRoom {
  final String id;
  final String challengerId;
  final String challengerName;
  final String challengedId;
  final String challengedName;
  final String status;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final int currentQuestion;
  final List<Map<String, dynamic>> questions;
  final bool challengerReady;
  final bool challengedReady;
  final bool challengerFinished;
  final bool challengedFinished;
  final int challengerScore;
  final int challengedScore;
  final Map<String, dynamic> challengerAnswers;
  final Map<String, dynamic> challengedAnswers;
  final String? winnerId;

  DuelRoom({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengedId,
    required this.challengedName,
    required this.status,
    this.createdAt,
    this.startedAt,
    required this.currentQuestion,
    required this.questions,
    required this.challengerReady,
    required this.challengedReady,
    required this.challengerFinished,
    required this.challengedFinished,
    required this.challengerScore,
    required this.challengedScore,
    required this.challengerAnswers,
    required this.challengedAnswers,
    this.winnerId,
  });

  factory DuelRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DuelRoom(
      id: doc.id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? 'Unknown',
      challengedId: data['challengedId'] ?? '',
      challengedName: data['challengedName'] ?? 'Unknown',
      status: data['status'] ?? 'waiting',
      createdAt: data['createdAt']?.toDate(),
      startedAt: data['startedAt']?.toDate(),
      currentQuestion: data['currentQuestion'] ?? 0,
      questions: List<Map<String, dynamic>>.from(data['questions'] ?? []),
      challengerReady: data['challengerReady'] ?? false,
      challengedReady: data['challengedReady'] ?? false,
      challengerFinished: data['challengerFinished'] ?? false,
      challengedFinished: data['challengedFinished'] ?? false,
      challengerScore: data['challengerScore'] ?? 0,
      challengedScore: data['challengedScore'] ?? 0,
      challengerAnswers:
          Map<String, dynamic>.from(data['challengerAnswers'] ?? {}),
      challengedAnswers:
          Map<String, dynamic>.from(data['challengedAnswers'] ?? {}),
      winnerId: data['winnerId'],
    );
  }
}
