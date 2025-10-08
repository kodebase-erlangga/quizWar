class AppConstants {
  // App Information
  static const String appName = 'EKSIS';
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
  static const String welcomeTitle = 'Welcome to EKSIS!';
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

  // Asset Paths
  static const String logoEksis = 'assets/images/logoEksis.png';
  static const String apkLogo = 'assets/images/apkLogo.png';
  static const String imageBosan = 'assets/images/bosan.png';
  static const String imageDuel = 'assets/images/duel.png';
  static const String imageInputSoal = 'assets/images/inputSoal.png';
  static const String imageMenjawabBenar = 'assets/images/menjawabBenar.png';

  // Splash Screen
  static const Duration splashDuration = Duration(seconds: 3);
  static const String splashTitle = 'EKSIS';
  static const String splashSubtitle = 'Belajar Jadi Menyenangkan!';

  // Onboarding Content
  static const List<OnboardingData> onboardingPages = [
    OnboardingData(
      image: imageBosan,
      title: 'Bosan dengan Belajar Monoton?',
      subtitle:
          'Saatnya mengubah cara belajarmu! Dengan EKSIS, belajar jadi lebih seru dan menyenangkan. Tidak ada lagi kebosanan dalam proses pembelajaran!',
    ),
    OnboardingData(
      image: imageDuel,
      title: 'Tantang Temanmu!',
      subtitle:
          'Ajak teman-temanmu untuk duel seru! Uji siapa yang paling pintar dan kuasai berbagai mata pelajaran. Kompetisi sehat yang bikin semangat belajar makin tinggi!',
    ),
    OnboardingData(
      image: imageInputSoal,
      title: 'Buat Soal Sendiri',
      subtitle:
          'Guru dan siswa bisa membuat soal mereka sendiri! Sesuaikan dengan materi yang sedang dipelajari. Pembelajaran jadi lebih personal dan efektif!',
    ),
    OnboardingData(
      image: imageMenjawabBenar,
      title: 'Rasakan Kepuasan Menjawab Benar!',
      subtitle:
          'Setiap jawaban benar memberikan kepuasan tersendiri! Kumpulkan poin, naik level, dan buktikan kemampuanmu. Belajar sambil bermain, siapa takut?',
    ),
  ];

  // Onboarding Buttons
  static const String skipButton = 'Lewati';
  static const String nextButton = 'Lanjut';
  static const String startButton = 'Mulai Sekarang!';

  // SharedPreferences Keys
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';
}

// Data class for onboarding content
class OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  const OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
