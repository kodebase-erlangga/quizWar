import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/duel_service.dart';
import '../core/services/online_quiz_service.dart';
import '../models/quiz_models.dart';
import 'duel_waiting_screen.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({Key? key}) : super(key: key);

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen>
    with TickerProviderStateMixin {
  final DuelService _duelService = DuelService();
  StreamSubscription? _onlineFriendsSubscription;
  StreamSubscription? _challengesSubscription;
  StreamSubscription? _acceptedChallengesSubscription;
  late TabController _tabController;
  Set<String> _handledChallengeIds = {}; // Track already handled challenges

  List<OnlineUser> _onlineFriends = [];
  List<Challenge> _pendingChallenges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Clear any previous tracking
    _handledChallengeIds.clear();

    _initializeOnlineStatus();
    _listenToOnlineFriends();
    _listenToChallenges();
    _listenToAcceptedChallenges();
  }

  void _initializeOnlineStatus() async {
    // Set user as online when screen loads
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _duelService.setUserOnline(currentUser.uid, 'User');
      }
    } catch (e) {
      print('Error setting user online: $e');
    }
  }

  void _listenToOnlineFriends() {
    _onlineFriendsSubscription =
        _duelService.getOnlineFriends().listen((friends) {
      if (mounted) {
        setState(() {
          _onlineFriends = friends;
        });
      }
    });
  }

  void _listenToChallenges() {
    print('🔄 Setting up challenge listener in OnlineUsersScreen');
    _challengesSubscription =
        _duelService.listenForChallenges().listen((challenges) {
      print('📱 OnlineUsersScreen received ${challenges.length} challenges');
      for (var challenge in challenges) {
        print(
            '🎯 Challenge: ${challenge.challengerName} -> ${challenge.challengedName}');
      }
      if (mounted) {
        setState(() {
          _pendingChallenges = challenges;
        });
      }
    }, onError: (error) {
      print('❌ Error listening to challenges: $error');
    });
  }

  void _listenToAcceptedChallenges() {
    print('🔄 Setting up accepted challenge listener for challenger');
    _acceptedChallengesSubscription =
        _duelService.listenForAcceptedChallenges().listen((acceptedChallenges) {
      print('📱 Received ${acceptedChallenges.length} accepted challenges');

      for (var challenge in acceptedChallenges) {
        // Skip if already handled this challenge
        if (_handledChallengeIds.contains(challenge.id)) {
          continue;
        }

        if (challenge.duelId != null && mounted) {
          print(
              '🎯 New challenge accepted! Navigating to duel room: ${challenge.duelId}');

          // Mark as handled in memory
          _handledChallengeIds.add(challenge.id);

          // Mark as navigated in database to prevent future auto-navigation
          _duelService.markChallengeAsNavigated(challenge.id);

          // Navigate to duel waiting screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DuelWaitingScreen(roomId: challenge.duelId!),
            ),
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${challenge.challengedName} menerima tantangan!'),
              backgroundColor: Colors.green,
            ),
          );

          break; // Only handle one accepted challenge at a time
        }
      }
    }, onError: (error) {
      print('❌ Error listening to accepted challenges: $error');
    });
  }

  Future<void> _sendChallenge(String userId, String userNickname) async {
    // Show question bank selection dialog
    final selectedQuestionBank = await _showQuestionBankSelectionDialog();
    if (selectedQuestionBank == null) {
      return; // User cancelled
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final challengeId = await _duelService.sendChallenge(
        userId,
        userNickname,
        selectedQuestionBank: selectedQuestionBank,
      );
      if (challengeId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Tantangan ${selectedQuestionBank.name} berhasil dikirim ke $userNickname\nMenunggu respons...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Don't navigate yet - wait for challenge to be accepted
        // The challenge acceptance will be handled by the listener
        print('🎯 Challenge sent, waiting for acceptance...');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim tantangan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<QuestionBank?> _showQuestionBankSelectionDialog() async {
    try {
      final questionBanks = await _duelService.getAvailableQuestionBanks();

      if (questionBanks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada bank soal tersedia'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      return await showDialog<QuestionBank>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Pilih Mata Pelajaran'),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: questionBanks.length,
                itemBuilder: (context, index) {
                  final bank = questionBanks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          bank.subject.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        bank.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${bank.subject} • Kelas ${bank.grade}'),
                          Text(
                            '${bank.totalQuestions} soal',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).pop(bank);
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Batal'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memuat bank soal: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _acceptChallenge(String challengeId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final duelId = await _duelService.acceptChallenge(challengeId);
      if (duelId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tantangan diterima'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to waiting screen with correct duelId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DuelWaitingScreen(roomId: duelId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat ruang duel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _declineChallenge(String challengeId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _duelService.declineChallenge(challengeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tantangan ditolak'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duel Online'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Teman Online (${_onlineFriends.length})'),
            Tab(text: 'Tantangan (${_pendingChallenges.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOnlineFriendsTab(),
          _buildChallengesTab(),
        ],
      ),
    );
  }

  Widget _buildOnlineFriendsTab() {
    if (_onlineFriends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada teman yang online',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Teman Anda akan muncul di sini ketika online',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _onlineFriends.length,
      itemBuilder: (context, index) {
        final friend = _onlineFriends[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                friend.nickname.isNotEmpty
                    ? friend.nickname[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              friend.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: friend.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(friend.isOnline ? 'Online' : 'Offline'),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _sendChallenge(friend.id, friend.nickname),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Tantang'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengesTab() {
    if (_pendingChallenges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_martial_arts,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada tantangan',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tantangan dari teman akan muncul di sini',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pendingChallenges.length,
      itemBuilder: (context, index) {
        final challenge = _pendingChallenges[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                challenge.challengerName.isNotEmpty
                    ? challenge.challengerName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              challenge.challengerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menantang Anda untuk duel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '📚 ${challenge.questionBankName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${challenge.questionBankSubject} • Kelas ${challenge.questionBankGrade} • ${challenge.totalQuestions} soal',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatTimestamp(challenge.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => _declineChallenge(challenge.id),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _isLoading ? null : () => _acceptChallenge(challenge.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Terima'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inDays} hari lalu';
    }
  }

  @override
  void dispose() {
    _onlineFriendsSubscription?.cancel();
    _challengesSubscription?.cancel();
    _acceptedChallengesSubscription?.cancel();
    _tabController.dispose();

    // Clear handled challenges tracking
    _handledChallengeIds.clear();

    // Set user as offline when leaving screen
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _duelService.setUserOffline(currentUser.uid);
      }
    } catch (e) {
      print('Error setting user offline: $e');
    }
    super.dispose();
  }
}
