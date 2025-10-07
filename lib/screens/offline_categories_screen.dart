import 'package:flutter/material.dart';
import '../core/services/offline_quiz_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import 'quiz_screen.dart';

class OfflineCategoriesScreen extends StatefulWidget {
  const OfflineCategoriesScreen({super.key});

  @override
  State<OfflineCategoriesScreen> createState() =>
      _OfflineCategoriesScreenState();
}

class _OfflineCategoriesScreenState extends State<OfflineCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final OfflineQuizService _quizService = OfflineQuizService();
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startQuiz(String categoryId, String categoryName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuizScreen(categoryId: categoryId, categoryName: categoryName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppConstants.mediumAnimation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _quizService.getAvailableCategories();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildCategoriesList(categories),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline Quiz Categories',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.offline_bolt,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Mode',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enjoy quizzes without internet connection!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(List<Map<String, dynamic>> categories) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppConstants.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Category',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                    0.65, // Changed from 0.85 to 0.65 for taller cards
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(category);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final color = Color(category['color'] as int);
    final iconName = category['icon'] as String;

    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'science':
          return Icons.science;
        case 'history_edu':
          return Icons.history_edu;
        case 'sports_soccer':
          return Icons.sports_soccer;
        case 'movie':
          return Icons.movie;
        default:
          return Icons.quiz;
      }
    }

    return GestureDetector(
      onTap: () => _startQuiz(category['id'], category['name']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with icon and color
            Container(
              height: 70, // Reduced from 80 to 70
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.largeBorderRadius),
                  topRight: Radius.circular(AppConstants.largeBorderRadius),
                ),
              ),
              child: Icon(
                getIcon(iconName),
                size: 36, // Reduced from 40 to 36
                color: color,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12), // Reduced from 16 to 12
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['name'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            // Changed from titleLarge to titleMedium
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6), // Reduced from 8 to 6
                    Expanded(
                      child: Text(
                        category['description'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              // Changed from bodyMedium to bodySmall
                              color: AppTheme.textSecondary,
                              height: 1.3, // Reduced from 1.4 to 1.3
                            ),
                        maxLines: 2, // Reduced from 3 to 2
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      children: [
                        Icon(
                          Icons.quiz,
                          size: 14, // Reduced from 16 to 14
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${category['totalQuestions']} Questions',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2), // Reduced from 4 to 2
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 14, // Reduced from 16 to 14
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            category['difficulty'],
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Start quiz button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // Reduced from 16 to 12
              child: ElevatedButton(
                onPressed: () => _startQuiz(category['id'], category['name']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10), // Reduced from 12 to 10
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultBorderRadius),
                  ),
                ),
                child: Text(
                  'Start Quiz',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        // Changed from labelLarge to labelMedium
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
