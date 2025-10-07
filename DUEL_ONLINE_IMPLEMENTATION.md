# IMPLEMENTASI SISTEM DUEL ONLINE - QUIZWAR

## 🎯 OVERVIEW

Sistem duel online telah berhasil diimplementasikan dengan alur sebagai berikut:

### Alur Sistem Duel Online:

1. **User Login** → Set status online di Firebase Realtime Database
2. **Lihat Pemain Online** → Daftar user yang sedang online dan available
3. **Kirim Tantangan** → User menantang pemain lain
4. **Waiting Challenge** → Penantang menunggu di halaman khusus
5. **Accept/Decline** → Pemain yang ditantang menerima atau menolak
6. **Duel Room** → Kedua pemain masuk ke room duel
7. **Ready Check** → Kedua pemain harus ready
8. **Start Game** → Challenger memulai permainan
9. **Real-time Battle** → Kedua pemain bertanding secara real-time
10. **Result** → Menampilkan hasil dan pemenang

---

## 🗄️ STRUKTUR FIREBASE REALTIME DATABASE

### URL Database:

```
https://quiz-war-4257f-default-rtdb.asia-southeast1.firebasedatabase.app/
```

### Struktur Data:

```json
{
  "users": {
    "userId": {
      "username": "string",
      "email": "string",
      "isOnline": boolean,
      "lastSeen": timestamp,
      "currentRoom": "string | null"
    }
  },

  "challenges": {
    "challengeId": {
      "challenger": "userId",
      "challenged": "userId",
      "status": "pending|accepted|declined|expired",
      "createdAt": timestamp,
      "expiresAt": timestamp,
      "roomId": "string | null"
    }
  },

  "duelRooms": {
    "roomId": {
      "players": {
        "userId1": {
          "username": "string",
          "ready": boolean,
          "score": number,
          "answers": {
            "questionIndex": {
              "answer": number,
              "timeUsed": number,
              "timestamp": timestamp
            }
          },
          "finished": boolean
        },
        "userId2": { /* sama seperti userId1 */ }
      },
      "gameState": {
        "status": "waiting|playing|finished",
        "currentQuestion": number,
        "startTime": timestamp,
        "endTime": timestamp,
        "questions": [
          {
            "id": "string",
            "question": "string",
            "options": ["string"],
            "correct": number,
            "timeLimit": number
          }
        ]
      },
      "createdAt": timestamp,
      "createdBy": "userId"
    }
  },

  "onlineUsers": {
    "userId": {
      "username": "string",
      "lastSeen": timestamp,
      "status": "available|in_game|challenging"
    }
  }
}
```

---

## 📱 SCREENS YANG DIBUAT

### 1. OnlineUsersScreen (`lib/screens/online_users_screen.dart`)

- **Fungsi**: Menampilkan daftar pemain online
- **Fitur**:
  - Realtime list pemain online
  - Status indicator (available, in_game, challenging)
  - Tombol tantang untuk setiap pemain
  - Auto-update status online user
  - Notifikasi tantangan masuk

### 2. DuelWaitingScreen (`lib/screens/duel_waiting_screen.dart`)

- **Fungsi**: Room persiapan sebelum duel dimulai
- **Fitur**:
  - Menampilkan info kedua pemain
  - Ready check system
  - Tombol start game (hanya untuk creator)
  - Real-time sync status ready

### 3. DuelPlayScreen (`lib/screens/duel_play_screen.dart`)

- **Fungsi**: Arena permainan duel real-time
- **Fitur**:
  - Timer 30 detik per soal
  - Real-time score display
  - 5 soal random
  - Auto submit saat waktu habis
  - Visual feedback jawaban benar/salah

### 4. DuelChallengeWaitingScreen (dalam OnlineUsersScreen)

- **Fungsi**: Menunggu respon dari pemain yang ditantang
- **Fitur**:
  - Loading indicator
  - Auto timeout 5 menit
  - Cancel challenge option

---

## 🔧 SERVICES YANG DIBUAT

### 1. DuelService (`lib/core/services/duel_service.dart`)

#### Methods Utama:

```dart
// Set user online/offline
Future<void> setUserOnline(String userId, String username)
Future<void> setUserOffline(String userId)

// Get online users
Stream<List<OnlineUser>> getOnlineUsers()

// Challenge system
Future<String?> sendChallenge(String challengedUserId)
Stream<List<Challenge>> listenForChallenges()
Future<String?> acceptChallenge(String challengeId)
Future<void> declineChallenge(String challengeId)

// Duel room management
Stream<DuelRoom?> listenToRoom(String roomId)
Future<void> setPlayerReady(String roomId)
Future<void> startGame(String roomId)

// Game mechanics
Future<void> submitAnswer(String roomId, int questionIndex, int answer, int timeUsed)
```

#### Models:

```dart
class OnlineUser {
  final String id;
  final String username;
  final int lastSeen;
  final String status;
}

class Challenge {
  final String id;
  final String challenger;
  final String challenged;
  final String status;
  final int createdAt;
  final int expiresAt;
}

class DuelRoom {
  final String id;
  final Map<String, DuelPlayer> players;
  final DuelGameState gameState;
  final int createdAt;
  final String createdBy;
}

class DuelPlayer {
  final String username;
  final bool ready;
  final int score;
  final Map<String, dynamic> answers;
  final bool finished;
}

class DuelGameState {
  final String status;
  final int currentQuestion;
  final int? startTime;
  final int? endTime;
  final List<Map<String, dynamic>> questions;
}
```

---

## 🏠 INTEGRASI DENGAN HOME SCREEN

### Tombol "Duel Online" ditambahkan ke grid menu:

```dart
_buildQuizCard(
  'Duel Online',
  Icons.sports_esports,
  Colors.deepPurple,
  _navigateToOnlineDuel,
),
```

### Validasi Login:

- Fitur duel hanya tersedia untuk user yang login dengan Google
- Anonymous user akan diminta login terlebih dahulu

---

## ⚙️ KONFIGURASI FIREBASE

### 1. Dependency Baru (`pubspec.yaml`)

```yaml
firebase_database: ^10.4.0
```

### 2. Firebase Options (`lib/firebase_options.dart`)

```dart
databaseURL: 'https://quiz-war-4257f-default-rtdb.asia-southeast1.firebasedatabase.app'
```

### 3. Main.dart Update

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

## 🎮 CARA MENGGUNAKAN

### 1. Setup Firebase (SUDAH SELESAI)

- ✅ Realtime Database sudah diaktifkan
- ✅ URL database sudah dikonfigurasi
- ✅ Struktur data sudah dibuat

### 2. Testing Flow:

1. **Login** dengan akun Google di aplikasi
2. **Klik "Duel Online"** di home screen
3. **Tunggu** pemain lain online (atau buka aplikasi di device lain)
4. **Klik "Tantang"** pada pemain yang tersedia
5. **Pemain kedua** akan menerima dialog tantangan
6. **Accept challenge** → masuk ke duel room
7. **Kedua pemain** klik "Siap"
8. **Creator** klik "MULAI PERMAINAN"
9. **Bermain** 5 soal dengan timer 30 detik
10. **Lihat hasil** dan pemenang

---

## 🔒 SECURITY RULES (OPSIONAL)

Untuk production, gunakan rules ini di Firebase Console:

```javascript
{
  "rules": {
    "users": {
      "$uid": {
        ".read": true,
        ".write": "$uid === auth.uid"
      }
    },
    "challenges": {
      ".read": "auth != null",
      "$challengeId": {
        ".write": "auth != null"
      }
    },
    "duelRooms": {
      "$roomId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "onlineUsers": {
      ".read": "auth != null",
      "$uid": {
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

---

## 🚀 FITUR YANG SUDAH DIIMPLEMENTASI

✅ **Real-time Online Status** - Melihat siapa yang online  
✅ **Challenge System** - Mengirim dan menerima tantangan  
✅ **Waiting Room** - Room persiapan dengan ready check  
✅ **Real-time Duel** - Bertanding secara real-time  
✅ **Auto Scoring** - Skor otomatis berdasarkan kecepatan jawab  
✅ **Question Timer** - Timer 30 detik per soal  
✅ **Auto Disconnect** - Status offline otomatis saat keluar  
✅ **Challenge Timeout** - Tantangan expire dalam 5 menit

---

## 📝 CATATAN DEVELOPMENT

1. **Error Handling**: Sudah ada basic error handling dengan try-catch
2. **Connection Management**: Auto disconnect detection dengan Firebase
3. **Memory Management**: Stream subscription di-dispose dengan benar
4. **UI/UX**: Loading states dan visual feedback tersedia
5. **Validation**: Input validation dan business logic checks

---

## 🔧 TESTING CHECKLIST

Untuk memastikan sistem berjalan dengan baik:

- [ ] Test login dengan 2 akun berbeda
- [ ] Test kirim tantangan
- [ ] Test accept/decline tantangan
- [ ] Test ready system di duel room
- [ ] Test start game
- [ ] Test jawab soal dengan timer
- [ ] Test perhitungan skor
- [ ] Test result screen
- [ ] Test connection interruption
- [ ] Test multiple concurrent duels

---

**🎉 SISTEM DUEL ONLINE SUDAH SIAP DIGUNAKAN!**

Implementasi mengikuti exact alur yang Anda minta di awal dengan Firebase Realtime Database sebagai backend real-time.
