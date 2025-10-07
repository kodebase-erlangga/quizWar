import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NicknameService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Singleton pattern
  static final NicknameService _instance = NicknameService._internal();
  factory NicknameService() => _instance;
  NicknameService._internal();

  /// Claim nickname menggunakan Cloud Function
  Future<Map<String, dynamic>> claimNickname(String nickname) async {
    // Pastikan user sudah login
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('User harus login untuk mengklaim nickname');
    }

    try {
      // Panggil Cloud Function claimNickname
      final callable = _functions.httpsCallable('claimNickname');

      final result = await callable.call({
        'nickname': nickname,
      });

      // Return hasil dari function
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Firebase Functions errors
      String errorMessage;

      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'User harus login untuk mengklaim nickname';
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'Format nickname tidak valid';
          break;
        case 'already-exists':
          errorMessage = 'Nickname sudah digunakan, pilih yang lain';
          break;
        case 'failed-precondition':
          errorMessage = 'Kamu sudah memiliki nickname';
          break;
        case 'internal':
          errorMessage = 'Terjadi kesalahan server. Coba lagi nanti.';
          break;
        default:
          errorMessage = e.message ?? 'Terjadi kesalahan tidak diketahui';
      }

      throw Exception(errorMessage);
    } catch (e) {
      // Handle other errors
      throw Exception('Gagal mengklaim nickname: ${e.toString()}');
    }
  }

  /// Check if user already has nickname (untuk simulasi sementara)
  /// Nanti bisa diganti dengan query ke Firestore langsung
  Future<String?> getCurrentUserNickname() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      // Untuk sementara, kita bisa cek dari displayName atau custom claims
      // Nanti bisa diganti dengan query ke Firestore

      // Simulasi: cek apakah user sudah punya nickname
      // Implementasi sebenarnya akan query ke /users/{uid}
      return null; // Belum ada implementasi
    } catch (e) {
      return null;
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
