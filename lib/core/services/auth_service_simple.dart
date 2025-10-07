import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  GoogleSignIn get googleSignIn => _googleSignIn;

  /// Get current Google user
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Stream of authentication state changes (simplified for Google only)
  Stream<GoogleSignInAccount?> get onAuthStateChanged =>
      _googleSignIn.onCurrentUserChanged;

  /// Check if user is signed in
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Check if user is anonymous (for our mock implementation)
  bool _isAnonymousUser = false;
  bool get isAnonymous => _isAnonymousUser;

  /// Get user display name
  String? get userDisplayName {
    if (_isAnonymousUser) return 'Guest User';
    return _googleSignIn.currentUser?.displayName;
  }

  /// Get user email
  String? get userEmail {
    if (_isAnonymousUser) return null;
    return _googleSignIn.currentUser?.email;
  }

  /// Get user photo URL
  String? get userPhotoUrl {
    if (_isAnonymousUser) return null;
    return _googleSignIn.currentUser?.photoUrl;
  }

  /// Sign in with Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      _isAnonymousUser = false;
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      throw Exception('Google Sign-In failed: $error');
    }
  }

  /// Sign in anonymously (mock implementation)
  Future<String?> signInAnonymously() async {
    try {
      // Sign out from Google if signed in
      await _googleSignIn.signOut();
      _isAnonymousUser = true;
      return 'anonymous_user_${DateTime.now().millisecondsSinceEpoch}';
    } catch (error) {
      throw Exception('Anonymous sign-in failed: $error');
    }
  }

  /// Link anonymous account with Google (mock implementation)
  Future<GoogleSignInAccount?> linkWithGoogle() async {
    try {
      if (!_isAnonymousUser) {
        throw Exception('User is not anonymous');
      }

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        _isAnonymousUser = false;
      }
      return account;
    } catch (error) {
      throw Exception('Account linking failed: $error');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _isAnonymousUser = false;
    } catch (error) {
      throw Exception('Sign out failed: $error');
    }
  }

  /// Disconnect (revoke access)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      _isAnonymousUser = false;
    } catch (error) {
      throw Exception('Disconnect failed: $error');
    }
  }

  /// Delete account (mock implementation)
  Future<void> deleteAccount() async {
    try {
      await disconnect();
      _isAnonymousUser = false;
    } catch (error) {
      throw Exception('Delete account failed: $error');
    }
  }

  /// Sign in silently
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      // Silent sign in failed, return null
      return null;
    }
  }
}

/// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;

  /// Create AuthException from Google Sign-In error
  factory AuthException._fromGoogleSignInError(dynamic error) {
    String message = 'Authentication failed';
    String? code;

    if (error.toString().contains('network_error')) {
      message = 'Network error. Please check your internet connection.';
      code = 'network_error';
    } else if (error.toString().contains('sign_in_canceled')) {
      message = 'Sign in was canceled.';
      code = 'sign_in_canceled';
    } else if (error.toString().contains('sign_in_failed')) {
      message = 'Sign in failed. Please try again.';
      code = 'sign_in_failed';
    }

    return AuthException(message, code: code);
  }
}
