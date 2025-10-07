import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromNickname;
  final String toNickname;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? actedAt;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromNickname,
    required this.toNickname,
    required this.status,
    required this.createdAt,
    this.actedAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUid: data['fromUid'] ?? '',
      toUid: data['toUid'] ?? '',
      fromNickname: data['fromNickname'] ?? '',
      toNickname: data['toNickname'] ?? '',
      status: _statusFromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      actedAt: data['actedAt'] != null
          ? (data['actedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static FriendRequestStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }

  String get statusString {
    switch (status) {
      case FriendRequestStatus.accepted:
        return 'accepted';
      case FriendRequestStatus.rejected:
        return 'rejected';
      case FriendRequestStatus.pending:
        return 'pending';
    }
  }
}

class Friend {
  final String uid;
  final String nickname;
  final DateTime friendsSince;

  Friend({
    required this.uid,
    required this.nickname,
    required this.friendsSince,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend(
      uid: data['uid'] ?? '',
      nickname: data['nickname'] ?? '',
      friendsSince: (data['friendsSince'] as Timestamp).toDate(),
    );
  }
}

class UserProfile {
  final String uid;
  final String nickname;
  final String nicknameLower;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.nickname,
    required this.nicknameLower,
    this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: data['uid'] ?? '',
      nickname: data['nickname'] ?? '',
      nicknameLower: data['nicknameLower'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Singleton pattern
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  /// Get current user UID
  String? get currentUserUid => _firebaseAuth.currentUser?.uid;

  /// Search users by nickname
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();

      print('DEBUG: Searching users with query: $queryLower');

      // Search by nickname (case insensitive)
      final snapshot = await _firestore
          .collection('users')
          .where('nicknameLower', isGreaterThanOrEqualTo: queryLower)
          .where('nicknameLower', isLessThan: queryLower + '\uf8ff')
          .limit(20)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} users');

      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((user) => user.uid != currentUserUid) // Exclude current user
          .toList();
    } catch (e) {
      print('ERROR searching users: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mencari user. Periksa Firestore Rules.');
      }
      return [];
    }
  }

  /// Get user by nickname
  Future<UserProfile?> getUserByNickname(String nickname) async {
    try {
      final nicknameLower = nickname.toLowerCase();
      final nicknameDoc =
          await _firestore.collection('nicknames').doc(nicknameLower).get();

      if (!nicknameDoc.exists) return null;

      final uid = nicknameDoc.data()?['uid'];
      if (uid == null) return null;

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) return null;

      return UserProfile.fromFirestore(userDoc);
    } catch (e) {
      print('Error getting user by nickname: $e');
      return null;
    }
  }

  /// Send friend request
  Future<Map<String, dynamic>> sendFriendRequest(String toNickname) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login untuk mengirim friend request');
    }

    try {
      print('DEBUG: Sending friend request to: $toNickname');

      // Get target user
      final targetUser = await getUserByNickname(toNickname);
      if (targetUser == null) {
        throw Exception('User dengan nickname "$toNickname" tidak ditemukan');
      }

      print('DEBUG: Found target user: ${targetUser.uid}');

      if (targetUser.uid == currentUser.uid) {
        throw Exception('Tidak bisa mengirim friend request ke diri sendiri');
      }

      // Get current user profile
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!currentUserDoc.exists) {
        throw Exception(
            'Profile tidak ditemukan. Silakan setup nickname terlebih dahulu');
      }

      final currentUserNickname = currentUserDoc.data()?['nickname'];
      if (currentUserNickname == null) {
        throw Exception('Silakan setup nickname terlebih dahulu');
      }

      print('DEBUG: Current user nickname: $currentUserNickname');

      // Check if friend request already exists
      final existingRequest = await _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: currentUser.uid)
          .where('toUid', isEqualTo: targetUser.uid)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request sudah pernah dikirim');
      }

      // Check reverse friend request
      final reverseRequest = await _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: targetUser.uid)
          .where('toUid', isEqualTo: currentUser.uid)
          .get();

      if (reverseRequest.docs.isNotEmpty) {
        throw Exception('User ini sudah mengirim friend request ke kamu');
      }

      // Check if already friends
      final friendship = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetUser.uid)
          .get();

      if (friendship.exists) {
        throw Exception('Kalian sudah berteman');
      }

      // Create friend request
      final friendRequestData = {
        'fromUid': currentUser.uid,
        'toUid': targetUser.uid,
        'fromNickname': currentUserNickname,
        'toNickname': targetUser.nickname,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('DEBUG: Creating friend request with data: $friendRequestData');

      await _firestore.collection('friendRequests').add(friendRequestData);

      print('DEBUG: Friend request created successfully');

      return {
        'success': true,
        'message': 'Friend request berhasil dikirim ke ${targetUser.nickname}'
      };
    } catch (e) {
      print('ERROR sending friend request: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mengirim friend request. Periksa Firestore Rules.');
      }
      throw Exception(e.toString());
    }
  }

  /// Get incoming friend requests (to current user)
  Future<List<FriendRequest>> getIncomingFriendRequests() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return [];

    try {
      print(
          'DEBUG: Getting incoming friend requests for user: ${currentUser.uid}');

      final snapshot = await _firestore
          .collection('friendRequests')
          .where('toUid', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} incoming requests');

      return snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('ERROR getting incoming friend requests: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mengakses friend requests. Periksa Firestore Rules.');
      }
      return [];
    }
  }

  /// Get outgoing friend requests (from current user)
  Future<List<FriendRequest>> getOutgoingFriendRequests() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return [];

    try {
      print(
          'DEBUG: Getting outgoing friend requests for user: ${currentUser.uid}');

      final snapshot = await _firestore
          .collection('friendRequests')
          .where('fromUid', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} outgoing requests');

      return snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('ERROR getting outgoing friend requests: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa mengakses friend requests. Periksa Firestore Rules.');
      }
      return [];
    }
  }

  /// Accept friend request
  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login');
    }

    try {
      print('DEBUG: Accepting friend request: $requestId');

      return await _firestore
          .runTransaction<Map<String, dynamic>>((transaction) async {
        // Get friend request
        final requestDoc = await transaction
            .get(_firestore.collection('friendRequests').doc(requestId));

        if (!requestDoc.exists) {
          throw Exception('Friend request tidak ditemukan');
        }

        final requestData = requestDoc.data()!;
        print('DEBUG: Friend request data: $requestData');

        if (requestData['toUid'] != currentUser.uid) {
          throw Exception('Unauthorized');
        }

        if (requestData['status'] != 'pending') {
          throw Exception('Friend request sudah diproses');
        }

        // Update friend request status
        transaction.update(requestDoc.reference, {
          'status': 'accepted',
          'actedAt': FieldValue.serverTimestamp(),
        });

        // Add to both users' friends collection
        final fromUid = requestData['fromUid'];
        final toUid = requestData['toUid'];
        final fromNickname = requestData['fromNickname'];
        final toNickname = requestData['toNickname'];

        print(
            'DEBUG: Creating friendship between $fromNickname and $toNickname');

        // Add friend to current user (toUid)
        transaction.set(
            _firestore
                .collection('users')
                .doc(toUid)
                .collection('friends')
                .doc(fromUid),
            {
              'uid': fromUid,
              'nickname': fromNickname,
              'friendsSince': FieldValue.serverTimestamp(),
            });

        // Add friend to sender (fromUid)
        transaction.set(
            _firestore
                .collection('users')
                .doc(fromUid)
                .collection('friends')
                .doc(toUid),
            {
              'uid': toUid,
              'nickname': toNickname,
              'friendsSince': FieldValue.serverTimestamp(),
            });

        print('DEBUG: Friend request accepted successfully');

        return {
          'success': true,
          'message': 'Friend request dari $fromNickname diterima!'
        };
      });
    } catch (e) {
      print('ERROR accepting friend request: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa menerima friend request. Periksa Firestore Rules.');
      }
      throw Exception(e.toString());
    }
  }

  /// Reject friend request
  Future<Map<String, dynamic>> rejectFriendRequest(String requestId) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login');
    }

    try {
      print('DEBUG: Rejecting friend request: $requestId');

      final requestDoc =
          await _firestore.collection('friendRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Friend request tidak ditemukan');
      }

      final requestData = requestDoc.data()!;
      print('DEBUG: Friend request data: $requestData');

      if (requestData['toUid'] != currentUser.uid) {
        throw Exception('Unauthorized');
      }

      if (requestData['status'] != 'pending') {
        throw Exception('Friend request sudah diproses');
      }

      // Update friend request status
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'rejected',
        'actedAt': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Friend request rejected successfully');

      return {
        'success': true,
        'message': 'Friend request dari ${requestData['fromNickname']} ditolak'
      };
    } catch (e) {
      print('ERROR rejecting friend request: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied: Tidak bisa menolak friend request. Periksa Firestore Rules.');
      }
      throw Exception(e.toString());
    }
  }

  /// Get friends list
  Future<List<Friend>> getFriends() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .orderBy('friendsSince', descending: true)
          .get();

      return snapshot.docs.map((doc) => Friend.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  /// Remove friend
  Future<Map<String, dynamic>> removeFriend(String friendUid) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User harus login');
    }

    try {
      return await _firestore
          .runTransaction<Map<String, dynamic>>((transaction) async {
        // Remove from current user's friends
        transaction.delete(_firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('friends')
            .doc(friendUid));

        // Remove from friend's friends
        transaction.delete(_firestore
            .collection('users')
            .doc(friendUid)
            .collection('friends')
            .doc(currentUser.uid));

        return {'success': true, 'message': 'Teman berhasil dihapus'};
      });
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
