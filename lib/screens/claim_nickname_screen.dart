import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/auth_service.dart';
import '../core/services/nickname_service_simulation.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import 'home_screen.dart';

class ClaimNicknameScreen extends StatefulWidget {
  const ClaimNicknameScreen({super.key});

  @override
  State<ClaimNicknameScreen> createState() => _ClaimNicknameScreenState();
}

class _ClaimNicknameScreenState extends State<ClaimNicknameScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  final AuthService _authService = AuthService();
  final NicknameServiceSimulation _nicknameService =
      NicknameServiceSimulation();

  bool _isLoading = false;
  String? _errorText;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

  void _validateNickname(String nickname) {
    setState(() {
      _errorText = null;
    });

    if (nickname.isEmpty) {
      setState(() {
        _errorText = 'Nickname tidak boleh kosong';
      });
      return;
    }

    if (nickname.length < 3) {
      setState(() {
        _errorText = 'Nickname minimal 3 karakter';
      });
      return;
    }

    if (nickname.length > 20) {
      setState(() {
        _errorText = 'Nickname maksimal 20 karakter';
      });
      return;
    }

    final nicknameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!nicknameRegex.hasMatch(nickname)) {
      setState(() {
        _errorText = 'Nickname hanya boleh berisi huruf, angka, dan underscore';
      });
      return;
    }
  }

  Future<void> _claimNickname() async {
    final nickname = _nicknameController.text.trim();

    _validateNickname(nickname);
    if (_errorText != null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _nicknameService.claimNickname(nickname);

      if (result['success'] == true && mounted) {
        _showSuccessMessage(
            'Nickname "${result['nickname']}" berhasil diklaim!');

        // Navigate back to home after delay
        Future.delayed(const Duration(seconds: 2), () {
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
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        duration: const Duration(seconds: 3),
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
    _nicknameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentFirebaseUser;

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
                // Header
                _buildHeader(),

                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildUserInfo(user),
                          const SizedBox(height: 48),
                          _buildNicknameForm(),
                          const SizedBox(height: 32),
                          _buildClaimButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.textPrimary,
          ),
        ),
        Expanded(
          child: Text(
            'Pilih Nickname',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48), // Balance the back button
      ],
    );
  }

  Widget _buildUserInfo(User? user) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Icon(
                    user?.isAnonymous == true
                        ? Icons.person
                        : Icons.account_circle,
                    size: 35,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            user?.displayName ?? 'Guest User',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNicknameForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan Nickname Unik',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        Text(
          'Nickname akan digunakan untuk identitas kamu dalam permainan. Pilih yang unik dan mudah diingat!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),

        // Input field
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
            border: Border.all(
              color: _errorText != null
                  ? Colors.red.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _nicknameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            onChanged: _validateNickname,
            decoration: InputDecoration(
              hintText: 'contoh: player123',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: AppTheme.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppConstants.defaultPadding),
            ),
          ),
        ),

        // Error text
        if (_errorText != null) ...[
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
          ),
        ],

        // Guidelines
        const SizedBox(height: AppConstants.defaultPadding),
        Container(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aturan Nickname:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '• 3-20 karakter\n• Hanya huruf, angka, dan underscore (_)\n• Tidak boleh sama dengan pengguna lain',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClaimButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ||
                _errorText != null ||
                _nicknameController.text.trim().isEmpty
            ? null
            : _claimNickname,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Klaim Nickname',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }
}
