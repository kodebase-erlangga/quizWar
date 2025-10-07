import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../widgets/buttons.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isSigningIn = false;
  bool _isSigningInAnonymously = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAuthListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _setupAuthListener() {
    // Listen to Firebase auth state changes instead of Google Sign-In only
    _authService.onFirebaseAuthStateChanged.listen((user) {
      if (mounted) {
        if (user != null) {
          _navigateToHome();
        }
      }
    });
  }

  Future<void> _handleSignIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      final account = await _authService.signInWithGoogle();
      if (account != null && mounted) {
        _showSuccessMessage(AppConstants.signInSuccess);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    if (_isSigningInAnonymously) return;

    setState(() {
      _isSigningInAnonymously = true;
    });

    try {
      final result = await _authService.signInAnonymously();
      if (result != null && mounted) {
        _showSuccessMessage(AppConstants.guestSignInSuccess);
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInAnonymously = false;
        });
      }
    }
  }

  void _navigateToHome() {
    Future.delayed(AppConstants.shortAnimation, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: AppConstants.mediumAnimation,
          ),
        );
      }
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.largePadding),
            child: Column(
              children: [
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 48),
                          _buildWelcomeText(),
                          const SizedBox(height: 48),
                          _buildSignInSection(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.quiz,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          AppConstants.welcomeTitle,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Text(
          AppConstants.welcomeSubtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignInSection() {
    return Column(
      children: [
        GoogleSignInButton(
          onPressed: _handleSignIn,
          isLoading: _isSigningIn,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        const OrDivider(),
        const SizedBox(height: AppConstants.defaultPadding),
        AnonymousSignInButton(
          onPressed: _handleAnonymousSignIn,
          isLoading: _isSigningInAnonymously,
        ),
        const SizedBox(height: AppConstants.largePadding),
        Text(
          'By signing in, you agree to our Terms of Service and Privacy Policy',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      '${AppConstants.appName} v${AppConstants.appVersion}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
          ),
    );
  }
}
