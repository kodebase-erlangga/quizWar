import 'package:flutter/material.dart';
import '../core/services/friend_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with TickerProviderStateMixin {
  final FriendService _friendService = FriendService();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendRequests();
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

    _animationController.forward();
  }

  Future<void> _loadFriendRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final incoming = await _friendService.getIncomingFriendRequests();
      final outgoing = await _friendService.getOutgoingFriendRequests();

      if (mounted) {
        setState(() {
          _incomingRequests = incoming;
          _outgoingRequests = outgoing;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Gagal memuat friend requests: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptFriendRequest(FriendRequest request) async {
    try {
      final result = await _friendService.acceptFriendRequest(request.id);

      if (mounted && result['success'] == true) {
        _showSuccessMessage(result['message']);
        _loadFriendRequests(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    }
  }

  Future<void> _rejectFriendRequest(FriendRequest request) async {
    try {
      final result = await _friendService.rejectFriendRequest(request.id);

      if (mounted && result['success'] == true) {
        _showSuccessMessage(result['message']);
        _loadFriendRequests(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
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
    _tabController.dispose();
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildIncomingTab(),
                            _buildOutgoingTab(),
                          ],
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
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
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
              'Friend Requests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox, size: 18),
                const SizedBox(width: 8),
                Text('Masuk (${_incomingRequests.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.outbox, size: 18),
                const SizedBox(width: 8),
                Text('Keluar (${_outgoingRequests.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTab() {
    if (_incomingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        title: 'Tidak Ada Request Masuk',
        subtitle: 'Belum ada yang mengirim friend request ke kamu',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: _incomingRequests.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.smallPadding),
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        return _buildIncomingRequestCard(request);
      },
    );
  }

  Widget _buildOutgoingTab() {
    if (_outgoingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.outbox,
        title: 'Tidak Ada Request Keluar',
        subtitle: 'Kamu belum mengirim friend request ke siapapun',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: _outgoingRequests.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.smallPadding),
      itemBuilder: (context, index) {
        final request = _outgoingRequests[index];
        return _buildOutgoingRequestCard(request);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.largeBorderRadius),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(FriendRequest request) {
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
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  request.fromNickname.isNotEmpty
                      ? request.fromNickname[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: AppConstants.defaultPadding),

              // Request info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fromNickname,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ingin berteman dengan kamu',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(request.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.defaultPadding),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectFriendRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.smallBorderRadius),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'Tolak',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptFriendRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.smallBorderRadius),
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Terima',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestCard(FriendRequest request) {
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
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              request.toNickname.isNotEmpty
                  ? request.toNickname[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: AppConstants.defaultPadding),

          // Request info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.toNickname,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dikirim ${_formatDate(request.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(request.status).withOpacity(0.2),
              borderRadius:
                  BorderRadius.circular(AppConstants.smallBorderRadius),
              border: Border.all(
                color: _getStatusColor(request.status),
                width: 1,
              ),
            ),
            child: Text(
              _getStatusText(request.status),
              style: TextStyle(
                color: _getStatusColor(request.status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.accepted:
        return Colors.green;
      case FriendRequestStatus.rejected:
        return Colors.red;
      case FriendRequestStatus.pending:
        return Colors.orange;
    }
  }

  String _getStatusText(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.accepted:
        return 'Diterima';
      case FriendRequestStatus.rejected:
        return 'Ditolak';
      case FriendRequestStatus.pending:
        return 'Menunggu';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} bulan lalu';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }
}
