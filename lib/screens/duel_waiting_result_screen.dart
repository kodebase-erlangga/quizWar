import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/duel_service.dart';
import 'duel_result_screen.dart';

class DuelWaitingResultScreen extends StatefulWidget {
  final String roomId;

  const DuelWaitingResultScreen({Key? key, required this.roomId})
      : super(key: key);

  @override
  State<DuelWaitingResultScreen> createState() =>
      _DuelWaitingResultScreenState();
}

class _DuelWaitingResultScreenState extends State<DuelWaitingResultScreen> {
  final DuelService _duelService = DuelService();
  StreamSubscription? _roomSubscription;

  DuelRoom? _room;
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
        setState(() {
          _room = room;
        });

        // Check if both players are finished
        if (room.challengerFinished && room.challengedFinished) {
          // Both finished, navigate to results
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DuelResultScreen(duelId: widget.roomId),
            ),
          );
        }
      }
    });
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

    final isChallenger = _currentUserId == _room!.challengerId;
    final currentUserFinished =
        isChallenger ? _room!.challengerFinished : _room!.challengedFinished;
    final opponentFinished =
        isChallenger ? _room!.challengedFinished : _room!.challengerFinished;
    final opponentName =
        isChallenger ? _room!.challengedName : _room!.challengerName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menunggu Hasil'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty,
                size: 60,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Quiz Selesai!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Status message
            Text(
              currentUserFinished && opponentFinished
                  ? 'Kedua pemain telah selesai! Menghitung hasil...'
                  : currentUserFinished
                      ? 'Anda telah selesai. Menunggu $opponentName menyelesaikan quiz...'
                      : 'Menunggu hasil...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Progress indicators
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Status Pemain',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Challenger status
                    Row(
                      children: [
                        Icon(
                          _room!.challengerFinished
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _room!.challengerFinished
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_room!.challengerName}${_currentUserId == _room!.challengerId ? ' (Anda)' : ''}',
                            style: TextStyle(
                              fontWeight: _currentUserId == _room!.challengerId
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          _room!.challengerFinished ? 'Selesai' : 'Bermain...',
                          style: TextStyle(
                            color: _room!.challengerFinished
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Challenged status
                    Row(
                      children: [
                        Icon(
                          _room!.challengedFinished
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _room!.challengedFinished
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_room!.challengedName}${_currentUserId == _room!.challengedId ? ' (Anda)' : ''}',
                            style: TextStyle(
                              fontWeight: _currentUserId == _room!.challengedId
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          _room!.challengedFinished ? 'Selesai' : 'Bermain...',
                          style: TextStyle(
                            color: _room!.challengedFinished
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Loading indicator
            if (!(_room!.challengerFinished && _room!.challengedFinished))
              const CircularProgressIndicator(),
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
