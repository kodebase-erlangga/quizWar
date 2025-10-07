/// Authentication Service
///
/// Handles all authentication operations including:
/// - Google Sign-in integration
/// - Firebase Authentication
/// - Anonymous authentication
/// - User state management
///
/// Uses Singleton pattern to ensure single instance across the app

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service class for handling authentication operations
class AuthService {
  // Private static instances for Singleton pattern
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Singleton pattern implementation
  static final AuthService _instance = AuthService._internal();

  /// Factory constructor returns the singleton instance
  factory AuthService() => _instance;

  /// Private constructor for singleton
  AuthService._internal();

  // Constants
  static const String _guestUserDisplayName = 'Guest User';

  // === GETTERS ===

  /// Provides access to GoogleSignIn instance for advanced operations
  GoogleSignIn get googleSignIn => _googleSignIn;

  /// Provides access to FirebaseAuth instance for advanced operations
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  /// Returns current Google user account if signed in, null otherwise
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Returns current Firebase user if authenticated, null otherwise
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Get user display name
  Future<String> getUserDisplayName(String userId) async {
    final user = _firebaseAuth.currentUser;
    if (user != null && user.uid == userId) {
      return user.displayName ?? user.email ?? _guestUserDisplayName;
    }
    return _guestUserDisplayName;
  }

  /// Stream that emits Google authentication state changes
  Stream<GoogleSignInAccount?> get onAuthStateChanged =>
      _googleSignIn.onCurrentUserChanged;

  /// Stream that emits Firebase authentication state changes
  Stream<User?> get onFirebaseAuthStateChanged =>
      _firebaseAuth.authStateChanges();

  /// Returns true if user is currently signed in (Google or Anonymous)
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Returns true if current user is signed in anonymously
  bool get isAnonymous => _firebaseAuth.currentUser?.isAnonymous ?? false;

  /// Returns user display name with fallback logic:
  /// 1. Firebase user display name
  /// 2. Google account display name
  /// 3. 'Guest User' for anonymous users
  /// 4. null if no user is signed in
  String? get userDisplayName {
    final user = _firebaseAuth.currentUser;

    if (user == null) return null;
    if (user.isAnonymous) return _guestUserDisplayName;

    return user.displayName ?? _googleSignIn.currentUser?.displayName;
  }

  /// Returns user email with fallback logic:
  /// 1. Firebase user email
  /// 2. Google account email
  /// 3. null for anonymous users or if no email available
  String? get userEmail {
    final user = _firebaseAuth.currentUser;

    if (user == null || user.isAnonymous) return null;

    return user.email ?? _googleSignIn.currentUser?.email;
  }

  /// Returns user profile photo URL with fallback logic:
  /// 1. Firebase user photo URL
  /// 2. Google account photo URL
  /// 3. null for anonymous users or if no photo available
  String? get userPhotoUrl {
    final user = _firebaseAuth.currentUser;

    if (user == null || user.isAnonymous) return null;

    return user.photoURL ?? _googleSignIn.currentUser?.photoUrl;
  }

  // === AUTHENTICATION METHODS ===

  /// Signs in user with Google account
  ///
  /// Returns [GoogleSignInAccount] on success, null if user cancels
  /// Throws [Exception] if sign-in fails
  ///
  /// Process:
  /// 1. Initiates Google sign-in flow
  /// 2. Gets authentication credentials
  /// 3. Signs in to Firebase with Google credential
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate that we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await _firebaseAuth.signInWithCredential(credential);

      return googleUser;
    } catch (error) {
      throw Exception('Google Sign-In failed: $error');
    }
  }

  /// Signs in user anonymously
  ///
  /// Returns user UID on success
  /// Throws [Exception] if anonymous sign-in fails
  ///
  /// Note: Automatically signs out from Google if currently signed in
  Future<String?> signInAnonymously() async {
    try {
      // Sign out from Google if signed in to avoid conflicts
      await _googleSignIn.signOut();

      // Sign in anonymously to Firebase
      final UserCredential userCredential =
          await _firebaseAuth.signInAnonymously();

      return userCredential.user?.uid;
    } catch (error) {
      throw Exception('Anonymous sign-in failed: $error');
    }
  }

  /// Link anonymous account with Google
  Future<GoogleSignInAccount?> linkWithGoogle() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        throw Exception('User is not anonymous');
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link the anonymous account with the Google credential
      await currentUser.linkWithCredential(credential);

      return googleUser;
    } catch (error) {
      throw Exception('Account linking failed: $error');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (error) {
      throw Exception('Sign out failed: $error');
    }
  }

  /// Disconnect (revoke access)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
    } catch (error) {
      throw Exception('Disconnect failed: $error');
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
      await _googleSignIn.disconnect();
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
