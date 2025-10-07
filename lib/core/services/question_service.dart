/// Question Service
///
/// Handles all question-related operations including:
/// - Creating new questions
/// - Managing question banks
/// - User question statistics
/// - Firestore integration for questions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/quiz_models.dart';

/// Service class for managing questions and question banks
class QuestionService {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants for subject codes
  static const Map<String, String> _subjectCodes = {
    'matematika': 'M',
    'math': 'M',
    'ipa': 'S',
    'science': 'S',
    'ips': 'SO',
    'social': 'SO',
    'bahasa indonesia': 'BI',
    'indonesian': 'BI',
    'bahasa inggris': 'EN',
    'english': 'EN',
  };

  static const String _defaultSubjectCode = 'GN'; // General
  static const String _bankSuffix = '-main';
  static const int _timestampLength = 8;

  // === PUBLIC METHODS ===

  /// Creates a new question in the specified question bank
  ///
  /// [question] - The question data to create
  /// Returns the generated question ID
  /// Throws [Exception] if creation fails
  Future<String> createQuestion(CreateQuestionModel question) async {
    try {
      // Validate user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to create questions');
      }

      // Generate unique ID for the question
      final questionId = _generateQuestionId(question.subject, question.grade);
      final bankId = '${question.subject}${question.grade}$_bankSuffix';

      // Save to Firestore question bank
      await _firestore
          .collection('questionBanks')
          .doc(bankId)
          .collection('items')
          .doc(questionId)
          .set(question.toFirestore());

      // Update user's question count
      await _updateUserQuestionCount();

      return questionId;
    } catch (e) {
      throw Exception('Failed to create question: $e');
    }
  }

  // === PRIVATE HELPER METHODS ===

  /// Generates a unique question ID
  ///
  /// Format: {SubjectCode}_{Grade}_{Timestamp}
  /// Example: M_7_12345678
  String _generateQuestionId(String subject, String grade) {
    final subjectCode = _getSubjectCode(subject);
    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(_timestampLength);

    return '${subjectCode}_${grade}_$timestamp';
  }

  /// Gets the subject code for a given subject name
  ///
  /// Returns standardized code for the subject, or default code if not found
  String _getSubjectCode(String subject) {
    return _subjectCodes[subject.toLowerCase()] ?? _defaultSubjectCode;
  }

  /// Updates the user's question creation count
  ///
  /// Increments the questionsCreated field in the user's document
  /// Throws [Exception] if user is not authenticated or update fails
  Future<void> _updateUserQuestionCount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to update question count');
    }

    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.update({
        'questionsCreated': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user question count: $e');
    }
  }

  /// Retrieves all questions created by the current user
  ///
  /// Returns a list of [CreateQuestionModel] objects
  /// Throws [Exception] if user is not authenticated or retrieval fails
  Future<List<CreateQuestionModel>> getUserQuestions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to retrieve questions');
      }

      final List<CreateQuestionModel> questions = [];

      // Query all question banks
      final questionBanks = await _firestore.collection('questionBanks').get();

      // Search through each bank for user's questions
      for (final bank in questionBanks.docs) {
        final items = await bank.reference
            .collection('items')
            .where('createdBy', isEqualTo: user.uid)
            .get();

        // Convert each question document to model
        for (final item in items.docs) {
          try {
            final questionData = item.data();
            final question = CreateQuestionModel.fromFirestore(questionData);
            questions.add(question);
          } catch (e) {
            // Log parsing error but continue with other questions
            print('Warning: Failed to parse question ${item.id}: $e');
          }
        }
      }

      return questions;
    } catch (e) {
      throw Exception('Failed to retrieve user questions: $e');
    }
  }

  /// Retrieves the current user's profile from Firestore
  ///
  /// Returns [UserProfile] object with user information
  /// Creates a new profile if none exists
  /// Throws [Exception] if user is not authenticated
  Future<UserProfile> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      print(
          'DEBUG: Current user: ${user?.uid}, ${user?.displayName}, ${user?.email}');

      if (user == null) {
        throw Exception('User must be authenticated to retrieve profile');
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      print('DEBUG: Document exists: ${doc.exists}');

      if (doc.exists) {
        print('DEBUG: Document data: ${doc.data()}');
        final data = doc.data() as Map<String, dynamic>;

        // Ensure email is available from auth if not in document
        data['email'] ??= user.email ?? '';

        // Ensure displayName is available with fallback logic
        data['displayName'] ??=
            data['nickname'] ?? user.displayName ?? 'Unknown User';

        final profile = UserProfile.fromFirestore(data);
        print(
            'DEBUG: Profile loaded: ${profile.displayName}, ${profile.email}');
        return profile;
      } else {
        // Create new profile if none exists
        print('DEBUG: Creating new profile for user');
        return _createNewUserProfile(user);
      }
    } catch (e) {
      throw Exception('Failed to retrieve user profile: $e');
    }
  }

  /// Creates a new user profile document in Firestore
  ///
  /// [user] - The Firebase user to create profile for
  /// Returns new [UserProfile] object
  Future<UserProfile> _createNewUserProfile(User user) async {
    try {
      final newProfile = UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown User',
        email: user.email ?? '',
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
      );

      print(
          'DEBUG: Saving new profile: ${newProfile.displayName}, ${newProfile.email}');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(newProfile.toFirestore());

      return newProfile;
    } catch (e) {
      throw Exception('Failed to create new user profile: $e');
    }
  }

  /// Updates an existing user profile in Firestore
  ///
  /// [profile] - The updated profile data
  /// Throws [Exception] if update fails
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).update({
        ...profile.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // === UTILITY METHODS ===

  /// Returns list of available subjects for question creation
  ///
  /// Static list of subjects that can be used in questions
  List<String> getSubjects() {
    return [
      'Matematika',
      'IPA',
      'IPS',
      'Bahasa Indonesia',
      'Bahasa Inggris',
      'Lainnya'
    ];
  }

  /// Returns list of available grade levels for question creation
  ///
  /// Static list of grade levels that can be used in questions
  List<String> getGrades() {
    return [
      '1', '2', '3', '4', '5', '6', // SD
      '7', '8', '9', // SMP
      '10', '11', '12' // SMA
    ];
  }
}
