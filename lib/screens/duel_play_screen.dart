import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/duel_service.dart';
import 'duel_result_screen.dart';
import 'duel_waiting_result_screen.dart';

class DuelPlayScreen extends StatefulWidget {
  final String roomId;

  const DuelPlayScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends State<DuelPlayScreen> {
  final DuelService _duelService = DuelService();
  StreamSubscription? _roomSubscription;
  Timer? _questionTimer;

  DuelRoom? _room;
  String? _currentUserId;
  int _currentQuestionIndex = 0;
  int _timeLeft = 20;
  int? _selectedAnswer;
  bool _hasAnswered = false;

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

        final isChallenger = _currentUserId == room.challengerId;
        final currentUserFinished =
            isChallenger ? room.challengerFinished : room.challengedFinished;
        final opponentFinished =
            isChallenger ? room.challengedFinished : room.challengerFinished;

        // Check if both players are finished - go to results
        if (room.challengerFinished && room.challengedFinished) {
          _navigateToResult();
          return;
        }

        // Check if current user finished but opponent hasn't - go to waiting
        if (currentUserFinished && !opponentFinished) {
          _navigateToWaitingResult();
          return;
        }

        // Check if game is finished
        if (room.status == 'finished') {
          _navigateToResult();
          return;
        }

        // Start question timer if game is playing
        if (room.status == 'playing' && _questionTimer == null) {
          _startQuestionTimer();
        }
      }
    });
  }

  void _startQuestionTimer() {
    _timeLeft = 20;
    _hasAnswered = false;
    _selectedAnswer = null;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeLeft--;
        });

        if (_timeLeft <= 0) {
          _submitAnswer(-1); // Time's up, submit no answer
        }
      }
    });
  }

  void _selectAnswer(int answerIndex) {
    if (!_hasAnswered && _timeLeft > 0) {
      setState(() {
        _selectedAnswer = answerIndex;
      });
    }
  }

  void _submitAnswer(int answerIndex) async {
    if (_hasAnswered) return;

    setState(() {
      _hasAnswered = true;
    });

    _questionTimer?.cancel();

    final timeUsed = 20 - _timeLeft;
    final isChallenger = _currentUserId == _room?.challengerId;
    await _duelService.submitAnswer(
      widget.roomId,
      _currentQuestionIndex,
      answerIndex,
      timeUsed,
      isChallenger,
    );

    // Show result popup
    _showAnswerResult(answerIndex);

    // Wait a moment then move to next question or finish
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      if (_currentQuestionIndex < (_room?.questions.length ?? 1) - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
        _startQuestionTimer();
      } else {
        // All questions answered, mark player as finished
        final isChallenger = _currentUserId == _room?.challengerId;
        await _duelService.markPlayerFinished(widget.roomId, isChallenger);

        // Navigation will be handled by _listenToRoom based on opponent status
      }
    }
  }

  void _showAnswerResult(int answerIndex) {
    if (!mounted) return; // Add mounted check

    if (_room == null || _currentQuestionIndex >= _room!.questions.length)
      return;

    final question = _room!.questions[_currentQuestionIndex];
    final correctAnswer = question['correct'] as int? ?? 0;
    final isCorrect = answerIndex == correctAnswer;
    final explanation =
        question['explanation'] as String? ?? 'Tidak ada penjelasan tersedia.';
    final selectedOptionText =
        answerIndex >= 0 && answerIndex < (question['options'] as List).length
            ? (question['options'] as List)[answerIndex]
            : 'Tidak ada jawaban';
    final correctOptionText =
        correctAnswer < (question['options'] as List).length
            ? (question['options'] as List)[correctAnswer]
            : 'Tidak diketahui';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 30,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Benar!' : 'Salah!',
                style: TextStyle(
                  color: isCorrect ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (answerIndex >= 0) ...[
                const Text('Jawaban Anda:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(selectedOptionText),
                const SizedBox(height: 12),
              ],
              const Text('Jawaban yang benar:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(correctOptionText,
                  style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
              const Text('Penjelasan:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(explanation),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DuelResultScreen(duelId: widget.roomId),
      ),
    );
  }

  void _navigateToWaitingResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DuelWaitingResultScreen(roomId: widget.roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null || _room!.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final question = _room!.questions[_currentQuestionIndex];
    final challenger = {
      'id': _room!.challengerId,
      'name': _room!.challengerName,
      'score': _room!.challengerScore
    };
    final challenged = {
      'id': _room!.challengedId,
      'name': _room!.challengedName,
      'score': _room!.challengedScore
    };
    final players = [challenger, challenged];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Soal ${_currentQuestionIndex + 1}/${_room!.questions.length}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Timer and scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Timer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _timeLeft <= 10 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_timeLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Scores
                Row(
                  children: players.map((player) {
                    final playerId = player['id'] as String;
                    final playerName = player['name'] as String;
                    final playerScore = player['score'] as int;
                    final isCurrentUser = playerId == _currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Colors.blue : Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$playerScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Question
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      question['question'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Answer options
            Expanded(
              child: ListView.builder(
                itemCount: (question['options'] as List).length,
                itemBuilder: (context, index) {
                  final option = (question['options'] as List)[index];
                  final isSelected = _selectedAnswer == index;
                  final correctAnswer = question['correct'] as int?;
                  final isCorrect =
                      correctAnswer != null && index == correctAnswer;

                  Color backgroundColor = Colors.white;
                  Color borderColor = Colors.grey.shade300;
                  Color textColor = Colors.black;

                  if (_hasAnswered) {
                    if (isCorrect) {
                      backgroundColor = Colors.green.shade100;
                      borderColor = Colors.green;
                      textColor = Colors.green.shade800;
                    } else if (isSelected && !isCorrect) {
                      backgroundColor = Colors.red.shade100;
                      borderColor = Colors.red;
                      textColor = Colors.red.shade800;
                    }
                  } else if (isSelected) {
                    backgroundColor = Colors.blue.shade100;
                    borderColor = Colors.blue;
                    textColor = Colors.blue.shade800;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _hasAnswered ? null : () => _selectAnswer(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(
                                        65 + index), // A, B, C, D
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_hasAnswered && isCorrect)
                                const Icon(Icons.check_circle,
                                    color: Colors.green),
                              if (_hasAnswered && isSelected && !isCorrect)
                                const Icon(Icons.cancel, color: Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Submit button
            if (_selectedAnswer != null && !_hasAnswered)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _submitAnswer(_selectedAnswer!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'JAWAB',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
    _questionTimer?.cancel();
    super.dispose();
  }
}
