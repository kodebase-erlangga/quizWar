class AppConstants {
  // App Information
  static const String appName = 'QuizWar';
  static const String appVersion = '1.0.0';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;

  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Text Strings
  static const String welcomeTitle = 'Welcome to QuizWar!';
  static const String welcomeSubtitle =
      'Challenge your knowledge and compete with friends';
  static const String signInWithGoogle = 'Sign in with Google';
  static const String continueAsGuest = 'Continue as Guest';
  static const String signOut = 'Sign Out';
  static const String getStarted = 'Get Started';
  static const String linkWithGoogle = 'Link with Google Account';
  static const String deleteAccount = 'Delete Account';
  static const String orDivider = 'OR';

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String authError = 'Authentication failed. Please try again.';

  // Success Messages
  static const String signInSuccess = 'Welcome back!';
  static const String guestSignInSuccess = 'Welcome, Guest!';
  static const String accountLinkedSuccess = 'Account linked successfully!';
  static const String signOutSuccess = 'You have been signed out.';
  static const String accountDeletedSuccess = 'Account deleted successfully.';
}
