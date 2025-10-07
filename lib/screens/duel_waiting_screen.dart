import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/duel_service.dart';
import 'duel_play_screen.dart';

class DuelWaitingScreen extends StatefulWidget {
  final String roomId;

  const DuelWaitingScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<DuelWaitingScreen> createState() => _DuelWaitingScreenState();
}

class _DuelWaitingScreenState extends State<DuelWaitingScreen> {
  final DuelService _duelService = DuelService();
  StreamSubscription? _roomSubscription;

  DuelRoom? _room;
  bool _isReady = false;
  bool _canStart = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _listenToRoom();
  }

  void _listenToRoom() {
    _roomSubscription = _duelService.listenToRoom(widget.roomId).listen((room) {
      if (mounted && room != null) {
        print('🎮 Room update: ${room.challengerId} vs ${room.challengedId}');
        print(
            '🎮 Ready status: challenger=${room.challengerReady}, challenged=${room.challengedReady}');
        print('🎮 Current user: $_currentUserId');
        print('🎮 Room status: ${room.status}');

        setState(() {
          _room = room;

          // Check if current user is ready
          if (_currentUserId != null) {
            if (_currentUserId == room.challengerId) {
              _isReady = room.challengerReady;
              print('🎮 Challenger ready status: $_isReady');
            } else if (_currentUserId == room.challengedId) {
              _isReady = room.challengedReady;
              print('🎮 Challenged ready status: $_isReady');
            }
          }

          // Check if both players are ready and current user is challenger
          _canStart = room.challengerReady &&
              room.challengedReady &&
              room.challengerId == _currentUserId &&
              room.status == 'waiting';
          print('🎮 Can start game: $_canStart');
        });

        // Auto navigate to game if status is playing
        if (room.status == 'playing') {
          print('🎮 Navigating to game screen...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DuelPlayScreen(roomId: widget.roomId),
            ),
          );
        }
      }
    });
  }

  void _toggleReady() async {
    print('🎮 Toggle ready called. Current ready status: $_isReady');
    if (!_isReady && _currentUserId != null && _room != null) {
      final isChallenger = _currentUserId == _room!.challengerId;
      print('🎮 Setting player ready. Is challenger: $isChallenger');

      try {
        await _duelService.setPlayerReady(widget.roomId, isChallenger);
        print('🎮 Successfully set player ready');
      } catch (e) {
        print('🎮 Error setting player ready: $e');

        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengatur status siap: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print(
          '🎮 Cannot toggle ready: isReady=$_isReady, userId=$_currentUserId, room=${_room != null}');
    }
  }

  void _startGame() async {
    if (_canStart) {
      await _duelService.startGame(widget.roomId);
    }
  }

  void _leaveDuelRoom() async {
    try {
      // Set user as offline or cancel duel if needed
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && _room != null) {
        // If game hasn't started, we could cancel the duel
        if (_room!.status == 'waiting') {
          // You might want to add a method to cancel/delete duel room
          print('🚪 User leaving duel room: ${widget.roomId}');
        }

        // Set user offline
        await _duelService.setUserOffline(currentUser.uid);
      }
    } catch (e) {
      print('❌ Error leaving duel room: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final challenger = {
      'id': _room!.challengerId,
      'name': _room!.challengerName,
      'ready': _room!.challengerReady
    };
    final challenged = {
      'id': _room!.challengedId,
      'name': _room!.challengedName,
      'ready': _room!.challengedReady
    };
    final players = [challenger, challenged];
    final isCreator = _room!.challengerId == _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Duel'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Room info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Room Duel',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Room ID: ${widget.roomId}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '5 Soal • 30 Detik per soal',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Players status
            const Text(
              'Pemain',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final playerId = player['id'] as String;
                  final playerName = player['name'] as String;
                  final playerReady = player['ready'] as bool;
                  final isCurrentUser = playerId == _currentUserId;

                  return Card(
                    color: isCurrentUser ? Colors.blue.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            playerReady ? Colors.green : Colors.grey,
                        child: Icon(
                          playerReady ? Icons.check : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        playerName + (isCurrentUser ? ' (Anda)' : ''),
                        style: TextStyle(
                          fontWeight: isCurrentUser
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        playerReady ? 'Siap' : 'Belum siap',
                        style: TextStyle(
                          color: playerReady ? Colors.green : Colors.grey,
                        ),
                      ),
                      trailing: isCurrentUser && !_isReady
                          ? ElevatedButton(
                              onPressed: _toggleReady,
                              child: const Text('Siap'),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),

            // Game status and start button
            if (_room!.status == 'waiting') ...[
              const SizedBox(height: 16),
              if (!_isReady)
                const Text(
                  'Tekan "Siap" untuk melanjutkan',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                )
              else if (!_canStart && isCreator)
                const Text(
                  'Menunggu pemain lain siap...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                )
              else if (!isCreator)
                const Text(
                  'Menunggu host memulai permainan...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              const SizedBox(height: 24),
              if (_canStart)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'MULAI PERMAINAN',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // Leave room button
            TextButton(
              onPressed: () {
                _leaveDuelRoom();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Keluar dari Room',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}
