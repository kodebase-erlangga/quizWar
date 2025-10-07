import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NicknameServiceSimulation {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Singleton pattern
  static final NicknameServiceSimulation _instance =
      NicknameServiceSimulation._internal();
  factory NicknameServiceSimulation() => _instance;
  NicknameServiceSimulation._internal();

  /// Claim nickname dengan simulasi logika yang sama seperti Cloud Function
  /// Ini digunakan untuk testing sebelum deploy Cloud Function
  Future<Map<String, dynamic>> claimNickname(String nickname) async {
    // Pastikan user sudah login
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('User harus login untuk mengklaim nickname');
    }

    final uid = user.uid;
    final nicknameLower = nickname.toLowerCase();

    try {
      // Gunakan transaction untuk memastikan atomicity
      final result = await _firestore.runTransaction<Map<String, dynamic>>(
        (transaction) async {
          // Cek apakah nickname sudah diambil
          final nicknameDoc = await transaction.get(
            _firestore.collection('nicknames').doc(nicknameLower),
          );

          if (nicknameDoc.exists) {
            throw Exception('Nickname sudah digunakan, pilih yang lain');
          }

          // Cek apakah user sudah punya nickname
          final userDoc = await transaction.get(
            _firestore.collection('users').doc(uid),
          );

          if (userDoc.exists && userDoc.data()?['nickname'] != null) {
            throw Exception('Kamu sudah memiliki nickname');
          }

          // Claim nickname di collection nicknames
          transaction.set(
            _firestore.collection('nicknames').doc(nicknameLower),
            {
              'uid': uid,
              'claimedAt': FieldValue.serverTimestamp(),
            },
          );

          // Update atau buat dokumen user
          final userData = {
            'uid': uid,
            'nickname': nickname,
            'nicknameLower': nicknameLower,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (userDoc.exists) {
            transaction.update(
              _firestore.collection('users').doc(uid),
              userData,
            );
          } else {
            transaction.set(
              _firestore.collection('users').doc(uid),
              {
                ...userData,
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
          }

          return {'success': true, 'nickname': nickname};
        },
      );

      return result;
    } catch (e) {
      // Re-throw dengan pesan yang sesuai
      if (e.toString().contains('already-exists') ||
          e.toString().contains('sudah digunakan')) {
        throw Exception('Nickname sudah digunakan, pilih yang lain');
      } else if (e.toString().contains('failed-precondition') ||
          e.toString().contains('sudah memiliki')) {
        throw Exception('Kamu sudah memiliki nickname');
      } else {
        throw Exception('Gagal mengklaim nickname: ${e.toString()}');
      }
    }
  }

  /// Check if user already has nickname
  Future<String?> getCurrentUserNickname() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        return userDoc.data()?['nickname'];
      }

      return null;
    } catch (e) {
      print('Error getting user nickname: $e');
      return null;
    }
  }

  /// Check if nickname is available
  Future<bool> isNicknameAvailable(String nickname) async {
    try {
      final nicknameLower = nickname.toLowerCase();
      final nicknameDoc =
          await _firestore.collection('nicknames').doc(nicknameLower).get();

      return !nicknameDoc.exists;
    } catch (e) {
      print('Error checking nickname availability: $e');
      return false;
    }
  }

  /// Validate nickname format
  bool isValidNickname(String nickname) {
    if (nickname.isEmpty) return false;
    if (nickname.length < 3 || nickname.length > 20) return false;

    final nicknameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    return nicknameRegex.hasMatch(nickname);
  }

  /// Get nickname validation error message
  String? getNicknameValidationError(String nickname) {
    if (nickname.isEmpty) {
      return 'Nickname tidak boleh kosong';
    }

    if (nickname.length < 3) {
      return 'Nickname minimal 3 karakter';
    }

    if (nickname.length > 20) {
      return 'Nickname maksimal 20 karakter';
    }

    final nicknameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!nicknameRegex.hasMatch(nickname)) {
      return 'Nickname hanya boleh berisi huruf, angka, dan underscore';
    }

    return null; // Valid
  }
}
