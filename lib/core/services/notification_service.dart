import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'challenge_service.dart';

enum NotificationType {
  friendRequest,
  friendAccepted,
  challengeReceived,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? fromUserId;
  final String? fromUserNickname;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.fromUserId,
    this.fromUserNickname,
    required this.createdAt,
    this.data,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChallengeService _challengeService = ChallengeService();

  StreamSubscription? _friendRequestSubscription;
  StreamSubscription? _challengeSubscription;
  StreamSubscription? _friendAcceptedSubscription;

  final StreamController<List<AppNotification>> _notificationsController =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsController.stream;

  List<AppNotification> _currentNotifications = [];

  void startListening() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) return;

    _listenToFriendRequests();
    _listenToChallenges();
    _listenToFriendAccepted();
  }

  void stopListening() {
    _friendRequestSubscription?.cancel();
    _challengeSubscription?.cancel();
    _friendAcceptedSubscription?.cancel();
  }

  void _listenToFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _friendRequestSubscription = _firestore
        .collection('friendRequests')
        .where('toUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final friendRequestNotifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return AppNotification(
          id: 'friend_request_${doc.id}',
          type: NotificationType.friendRequest,
          title: 'Permintaan Pertemanan',
          message: '${data['fromNickname']} ingin berteman dengan kamu',
          fromUserId: data['fromUid'],
          fromUserNickname: data['fromNickname'],
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          data: {'requestId': doc.id, 'fromUid': data['fromUid']},
        );
      }).toList();

      _updateNotifications(
          NotificationType.friendRequest, friendRequestNotifications);
    });
  }

  void _listenToChallenges() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _challengeSubscription =
        _challengeService.getIncomingChallenges().listen((challenges) {
      final challengeNotifications = challenges.map((challenge) {
        return AppNotification(
          id: 'challenge_${challenge.id}',
          type: NotificationType.challengeReceived,
          title: 'Tantangan Duel',
          message: '${challenge.challengerName} menantangmu untuk duel!',
          fromUserId: challenge.challengerId,
          fromUserNickname: challenge.challengerName,
          createdAt: challenge.createdAt,
          data: {
            'challengeId': challenge.id,
            'questionBankId': challenge.questionBankId,
            'questionBankName': challenge.questionBankName,
          },
        );
      }).toList();

      _updateNotifications(
          NotificationType.challengeReceived, challengeNotifications);
    });
  }

  void _listenToFriendAccepted() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _friendAcceptedSubscription = _firestore
        .collection('friendRequests')
        .where('fromUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
      final acceptedNotifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return AppNotification(
          id: 'friend_accepted_${doc.id}',
          type: NotificationType.friendAccepted,
          title: 'Pertemanan Diterima',
          message: '${data['toNickname']} menerima permintaan pertemananmu',
          fromUserId: data['toUid'],
          fromUserNickname: data['toNickname'],
          createdAt:
              (data['actedAt'] as Timestamp? ?? data['createdAt'] as Timestamp)
                  .toDate(),
          data: {'friendUid': data['toUid']},
        );
      }).toList();

      _updateNotifications(
          NotificationType.friendAccepted, acceptedNotifications);
    });
  }

  void _updateNotifications(
      NotificationType type, List<AppNotification> newNotifications) {
    // Remove old notifications of this type
    _currentNotifications
        .removeWhere((notification) => notification.type == type);

    // Add new notifications
    _currentNotifications.addAll(newNotifications);

    // Sort by creation date (newest first)
    _currentNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Emit updated list
    _notificationsController.add(List.from(_currentNotifications));
  }

  int get unreadCount => _currentNotifications.where((n) => !n.isRead).length;

  Future<void> markAsRead(String notificationId) async {
    final index =
        _currentNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _currentNotifications[index] = AppNotification(
        id: _currentNotifications[index].id,
        type: _currentNotifications[index].type,
        title: _currentNotifications[index].title,
        message: _currentNotifications[index].message,
        fromUserId: _currentNotifications[index].fromUserId,
        fromUserNickname: _currentNotifications[index].fromUserNickname,
        createdAt: _currentNotifications[index].createdAt,
        data: _currentNotifications[index].data,
        isRead: true,
      );
      _notificationsController.add(List.from(_currentNotifications));
    }
  }

  Future<void> markAllAsRead() async {
    _currentNotifications = _currentNotifications.map((notification) {
      return AppNotification(
        id: notification.id,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        fromUserId: notification.fromUserId,
        fromUserNickname: notification.fromUserNickname,
        createdAt: notification.createdAt,
        data: notification.data,
        isRead: true,
      );
    }).toList();
    _notificationsController.add(List.from(_currentNotifications));
  }

  void dispose() {
    stopListening();
    _notificationsController.close();
  }
}
