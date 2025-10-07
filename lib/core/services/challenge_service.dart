import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/quiz_models.dart';
import 'online_quiz_service.dart';

/// Service for managing challenges and duels between friends
class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OnlineQuizService _quizService = OnlineQuizService();

  // Public getters for accessing firebase instances
  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;

  /// Send a challenge to a friend
  Future<String> sendChallenge({
    required String friendId,
    required String friendName,
    required String questionBankId,
    required String questionBankName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 Debug Challenge Send:');
      print('  Current User ID: ${user.uid}');
      print('  Current User Display Name: ${user.displayName}');
      print('  Current User Email: ${user.email}');
      print('  User Email Verified: ${user.emailVerified}');
      print('  Friend ID: $friendId');
      print('  Question Bank ID: $questionBankId');

      // Check if current user exists in users collection
      try {
        final currentUserDoc =
            await _firestore.collection('users').doc(user.uid).get();
        print('  Current User Doc Exists: ${currentUserDoc.exists}');
        if (currentUserDoc.exists) {
          print('  Current User Data: ${currentUserDoc.data()}');
        }
      } catch (e) {
        print('⚠️ Error checking current user: $e');
      }

      // Check if challenged user exists in users collection
      try {
        final challengedUserDoc =
            await _firestore.collection('users').doc(friendId).get();
        print('  Challenged User Doc Exists: ${challengedUserDoc.exists}');
        if (challengedUserDoc.exists) {
          print('  Challenged User Data: ${challengedUserDoc.data()}');
        }
      } catch (e) {
        print('⚠️ Error checking challenged user: $e');
      }

      // Get current user's nickname from users collection
      String challengerName = user.displayName ?? 'Unknown';
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          challengerName = userData['nickname'] ??
              userData['displayName'] ??
              user.displayName ??
              'Unknown';
        }
      } catch (e) {
        print('⚠️ Could not fetch user nickname: $e');
      }

      // Create challenge document
      final challengeData = Challenge(
        id: '', // Will be set by Firestore
        challengerId: user.uid,
        challengerName: challengerName,
        challengedId: friendId,
        challengedName: friendName,
        questionBankId: questionBankId,
        questionBankName: questionBankName,
        questionBankSubject: 'General', // Default subject
        questionBankGrade: '', // Default grade
        totalQuestions: 10, // Default question count
        status: ChallengeStatus.pending,
        createdAt: DateTime.now(),
      );

      print('🔍 Challenge Data to Send:');
      final challengeMap = challengeData.toFirestore();
      print('  Challenge Map: $challengeMap');

      // Validate required fields
      final requiredFields = [
        'challengerId',
        'challengedId',
        'status',
        'createdAt'
      ];
      for (String field in requiredFields) {
        if (!challengeMap.containsKey(field) || challengeMap[field] == null) {
          throw Exception('Missing required field: $field');
        }
      }

      // Validate user IDs are not empty
      if (challengeMap['challengerId'].toString().isEmpty ||
          challengeMap['challengedId'].toString().isEmpty) {
        throw Exception('User IDs cannot be empty');
      }

      print('✅ Challenge data validation passed');

      final docRef =
          await _firestore.collection('challenges').add(challengeMap);

      print('🏆 Challenge sent successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error sending challenge: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('permission-denied')) {
        print('❌ Permission denied details:');
        print('  - Check Firestore rules for challenges collection');
        print('  - Verify user authentication state');
        print('  - Check if challengerId and challengedId are valid');
      }
      rethrow;
    }
  }

  /// Get incoming challenges for current user
  Stream<List<Challenge>> getIncomingChallenges() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('challenges')
        .where('challengedId', isEqualTo: user.uid)
        .where('status', isEqualTo: ChallengeStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Challenge.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get outgoing challenges from current user
  Stream<List<Challenge>> getOutgoingChallenges() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('challenges')
        .where('challengerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Challenge.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Accept a challenge
  Future<String> acceptChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update challenge status
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.accepted.name,
        'acceptedAt': DateTime.now(),
      });

      // Get challenge data
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();

      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challenge =
          Challenge.fromFirestore(challengeId, challengeDoc.data()!);

      // Get random questions from the question bank
      print('🔍 Getting questions from bank: ${challenge.questionBankId}');
      final questions = await _quizService.getQuestionsFromBank(
        challenge.questionBankId,
        limit: 10, // 10 questions per duel
      );

      print('🔍 Questions retrieved for duel: ${questions.length}');
      for (var q in questions) {
        print(
            '  Question ID: ${q.id} - ${q.question.substring(0, q.question.length > 50 ? 50 : q.question.length)}...');
      }

      if (questions.isEmpty) {
        throw Exception('No questions available in selected question bank');
      }

      final questionIds = questions.map((q) => q.id).toList();
      print('🔍 Question IDs for duel: $questionIds');

      // Create duel session
      final duelData = DuelSession(
        id: '', // Will be set by Firestore
        challengeId: challengeId,
        challengerId: challenge.challengerId,
        challengedId: challenge.challengedId,
        questionBankId: challenge.questionBankId,
        questionIds: questionIds,
        challengerAnswers: {},
        challengedAnswers: {},
        status: DuelStatus.waiting,
        startedAt: DateTime.now(),
      );

      print('🔍 Creating duel with data: ${duelData.toFirestore()}');

      final duelRef =
          await _firestore.collection('duels').add(duelData.toFirestore());

      print('⚔️ Duel session created: ${duelRef.id}');

      // Auto-start the duel by setting status to inProgress
      await Future.delayed(const Duration(seconds: 1));
      await _firestore.collection('duels').doc(duelRef.id).update({
        'status': DuelStatus.inProgress.name,
        'actualStartedAt': DateTime.now(),
      });
      print('🚀 Duel auto-started: ${duelRef.id}');

      return duelRef.id;
    } catch (e) {
      print('❌ Error accepting challenge: $e');
      rethrow;
    }
  }

  /// Reject a challenge
  Future<void> rejectChallenge(String challengeId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.rejected.name,
      });

      print('🚫 Challenge rejected: $challengeId');
    } catch (e) {
      print('❌ Error rejecting challenge: $e');
      rethrow;
    }
  }

  /// Get active duel for current user
  Stream<DuelSession?> getActiveDuel() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('duels')
        .where('status',
            whereIn: [DuelStatus.waiting.name, DuelStatus.inProgress.name])
        .where('challengerId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            return DuelSession.fromFirestore(
              snapshot.docs.first.id,
              snapshot.docs.first.data(),
            );
          }

          // Check if user is the challenged one
          final challengedSnapshot = await _firestore
              .collection('duels')
              .where('status', whereIn: [
                DuelStatus.waiting.name,
                DuelStatus.inProgress.name
              ])
              .where('challengedId', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (challengedSnapshot.docs.isNotEmpty) {
            return DuelSession.fromFirestore(
              challengedSnapshot.docs.first.id,
              challengedSnapshot.docs.first.data(),
            );
          }

          return null;
        });
  }

  /// Get specific duel by ID
  Stream<DuelSession?> getDuel(String duelId) {
    return _firestore.collection('duels').doc(duelId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DuelSession.fromFirestore(doc.id, doc.data()!);
    });
  }

  /// Submit answer in duel
  Future<void> submitDuelAnswer({
    required String duelId,
    required String questionId,
    required int selectedAnswer,
    required int timeSpent,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final answer = DuelPlayerAnswer(
        selectedAnswer: selectedAnswer,
        answeredAt: DateTime.now(),
        timeSpent: timeSpent,
      );

      // Determine if user is challenger or challenged
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (!duelDoc.exists) throw Exception('Duel not found');

      final duel = DuelSession.fromFirestore(duelId, duelDoc.data()!);
      final isChallenger = user.uid == duel.challengerId;

      final fieldName =
          isChallenger ? 'challengerAnswers' : 'challengedAnswers';

      await _firestore.collection('duels').doc(duelId).update({
        '$fieldName.$questionId': answer.toMap(),
        'status': DuelStatus.inProgress.name,
      });

      print('✅ Answer submitted for question $questionId');

      // Check if both players have answered all questions
      await _checkDuelCompletion(duelId);
    } catch (e) {
      print('❌ Error submitting duel answer: $e');
      rethrow;
    }
  }

  /// Check if duel is complete and calculate results
  Future<void> _checkDuelCompletion(String duelId) async {
    try {
      final duelDoc = await _firestore.collection('duels').doc(duelId).get();
      if (!duelDoc.exists) return;

      final duel = DuelSession.fromFirestore(duelId, duelDoc.data()!);

      final totalQuestions = duel.questionIds.length;
      final challengerAnswered = duel.challengerAnswers.length;
      final challengedAnswered = duel.challengedAnswers.length;

      // Check if both players answered all questions
      if (challengerAnswered == totalQuestions &&
          challengedAnswered == totalQuestions) {
        await _calculateDuelResults(duelId, duel);
      }
    } catch (e) {
      print('❌ Error checking duel completion: $e');
    }
  }

  /// Calculate duel results and determine winner
  Future<void> _calculateDuelResults(String duelId, DuelSession duel) async {
    try {
      // Get questions to check correct answers
      final allQuestions = await _quizService.getQuestionsFromBank(
        duel.questionBankId,
      );

      // Filter to only the questions used in this duel
      final questions =
          allQuestions.where((q) => duel.questionIds.contains(q.id)).toList();

      int challengerScore = 0;
      int challengedScore = 0;

      for (final question in questions) {
        final challengerAnswer = duel.challengerAnswers[question.id];
        final challengedAnswer = duel.challengedAnswers[question.id];

        if (challengerAnswer?.selectedAnswer == question.correctAnswer) {
          challengerScore++;
        }
        if (challengedAnswer?.selectedAnswer == question.correctAnswer) {
          challengedScore++;
        }
      }

      // Determine winner
      String? winnerId;
      String? winnerName;

      if (challengerScore > challengedScore) {
        winnerId = duel.challengerId;
        // Get challenger name from challenge
        final challengeDoc = await _firestore
            .collection('challenges')
            .doc(duel.challengeId)
            .get();
        if (challengeDoc.exists) {
          final challenge =
              Challenge.fromFirestore(duel.challengeId, challengeDoc.data()!);
          winnerName = challenge.challengerName;
        }
      } else if (challengedScore > challengerScore) {
        winnerId = duel.challengedId;
        // Get challenged name from challenge
        final challengeDoc = await _firestore
            .collection('challenges')
            .doc(duel.challengeId)
            .get();
        if (challengeDoc.exists) {
          final challenge =
              Challenge.fromFirestore(duel.challengeId, challengeDoc.data()!);
          winnerName = challenge.challengedName;
        }
      }
      // If scores are equal, it's a tie (winnerId remains null)

      // Update duel with results
      await _firestore.collection('duels').doc(duelId).update({
        'status': DuelStatus.completed.name,
        'completedAt': DateTime.now(),
        'challengerScore': challengerScore,
        'challengedScore': challengedScore,
        'winnerId': winnerId,
      });

      // Update challenge status
      await _firestore.collection('challenges').doc(duel.challengeId).update({
        'status': ChallengeStatus.completed.name,
        'completedAt': DateTime.now(),
        'winnerId': winnerId,
        'winnerName': winnerName,
      });

      print(
          '🏁 Duel completed! Challenger: $challengerScore, Challenged: $challengedScore');
    } catch (e) {
      print('❌ Error calculating duel results: $e');
    }
  }

  /// Get completed duels for current user
  Stream<List<DuelSession>> getCompletedDuels() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('duels')
        .where('status', isEqualTo: DuelStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .limit(20)
        .snapshots()
        .asyncMap((snapshot) async {
      List<DuelSession> userDuels = [];

      for (final doc in snapshot.docs) {
        final duel = DuelSession.fromFirestore(doc.id, doc.data());
        if (duel.challengerId == user.uid || duel.challengedId == user.uid) {
          userDuels.add(duel);
        }
      }

      return userDuels;
    });
  }

  /// Cancel/abandon an active duel
  Future<void> abandonDuel(String duelId) async {
    try {
      await _firestore.collection('duels').doc(duelId).update({
        'status': DuelStatus.abandoned.name,
        'completedAt': DateTime.now(),
      });

      print('🏃‍♂️ Duel abandoned: $duelId');
    } catch (e) {
      print('❌ Error abandoning duel: $e');
      rethrow;
    }
  }
}
