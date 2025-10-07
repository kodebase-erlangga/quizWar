# Testing Guide - Friends Feature

## Setup untuk Testing

### 1. Pastikan Prerequisites

- Firestore Rules sudah aktif
- User sudah memiliki nickname (dari testing sebelumnya)
- Aplikasi sudah berjalan

### 2. Akses ke Firestore Console

Buka Firebase Console > Firestore Database > Data untuk memantau perubahan data

## Langkah Testing - Fitur Add Friends

### Step 1: Akses Friends Screen

1. Login ke aplikasi dengan Google/Anonymous
2. Di HomeScreen, klik card **"Friends"** (icon people, warna pink)
3. Aplikasi akan navigasi ke FriendsScreen

### Step 2: Navigasi Add Friends

1. Di FriendsScreen, klik tombol **"Tambah Teman"** (biru)
2. Aplikasi akan navigasi ke AddFriendsScreen
3. Verifikasi UI menampilkan:
   - Search box dengan placeholder "Ketik nickname..."
   - Info box biru dengan petunjuk
   - Empty state dengan icon search

### Step 3: Search Users

1. Di search box, ketik nickname user lain (misalnya teman kamu)
2. Aplikasi akan melakukan search otomatis setelah 500ms
3. Verifikasi:
   - Loading indicator muncul saat search
   - Hasil search muncul dalam card
   - User sendiri tidak muncul dalam hasil

### Step 4: Send Friend Request

1. Pada hasil search, klik tombol **"Tambah"** pada user yang diinginkan
2. Verifikasi:
   - Snackbar hijau muncul: "Friend request berhasil dikirim ke [nickname]"
   - User tersebut hilang dari hasil search
   - Tidak bisa mengirim request lagi ke user yang sama

### Step 5: Verifikasi di Firestore

1. Buka Firebase Console > Firestore > Collection `friendRequests`
2. Cari dokumen baru dengan fields:
   ```
   {
     "fromUid": "your-uid",
     "toUid": "friend-uid",
     "fromNickname": "your-nickname",
     "toNickname": "friend-nickname",
     "status": "pending",
     "createdAt": [timestamp]
   }
   ```

## Testing - Friend Requests Management

### Step 1: Akses Friend Requests

1. Dari FriendsScreen, klik tombol **"Requests"** (orange)
2. Aplikasi akan navigasi ke FriendRequestsScreen dengan 2 tabs:
   - **Masuk**: Requests yang diterima
   - **Keluar**: Requests yang dikirim

### Step 2: View Outgoing Requests

1. Klik tab "Keluar"
2. Verifikasi menampilkan friend requests yang sudah dikirim
3. Status menunjukkan "Menunggu" (orange badge)

### Step 3: Simulate Incoming Request

Untuk test incoming request, butuh user kedua:

1. **Setup User Kedua:**

   - Login dengan akun Google berbeda (atau anonymous)
   - Claim nickname berbeda
   - Kirim friend request ke user pertama

2. **Pada User Pertama:**
   - Buka FriendsScreen (akan ada notifikasi request baru)
   - Klik "Requests" → Tab "Masuk"
   - Verifikasi request dari user kedua muncul

### Step 4: Accept/Reject Friend Request

1. **Untuk Reject:**

   - Klik tombol "Tolak" (merah)
   - Verifikasi snackbar: "Friend request dari [nickname] ditolak"
   - Request hilang dari daftar

2. **Untuk Accept:**
   - Klik tombol "Terima" (hijau)
   - Verifikasi snackbar: "Friend request dari [nickname] diterima!"
   - Request hilang dari daftar

### Step 5: Verifikasi Friendship di Firestore

Setelah accept friend request:

1. **Check Collection `friendRequests`:**

   - Status berubah menjadi "accepted"
   - Field `actedAt` ditambahkan

2. **Check Sub-collection `friends`:**
   - `/users/{user1}/friends/{user2}` dibuat
   - `/users/{user2}/friends/{user1}` dibuat
   - Kedua dokumen memiliki fields:
     ```
     {
       "uid": "friend-uid",
       "nickname": "friend-nickname",
       "friendsSince": [timestamp]
     }
     ```

## Testing - Friends List

### Step 1: View Friends List

1. Kembali ke FriendsScreen
2. Verifikasi:
   - Daftar teman muncul di bagian bawah
   - Counter "Teman (X)" sesuai jumlah
   - Setiap friend card menampilkan avatar, nickname, dan "Berteman sejak"

### Step 2: Remove Friend

1. Pada friend card, klik icon menu (3 dots)
2. Pilih "Hapus Teman"
3. Confirm di dialog
4. Verifikasi:
   - Snackbar: "Teman berhasil dihapus"
   - Friend hilang dari daftar
   - Data friendship terhapus dari Firestore

## Expected Results & Error Cases

### ✅ Success Cases:

1. **Search berhasil** → User ditemukan dan ditampilkan
2. **Send request berhasil** → Data tersimpan di `/friendRequests`
3. **Accept request berhasil** → Friendship dibuat di kedua user
4. **Friends list updated** → UI menampilkan teman terbaru

### ❌ Error Cases:

1. **Duplicate request** → "Friend request sudah pernah dikirim"
2. **Self request** → "Tidak bisa mengirim friend request ke diri sendiri"
3. **User not found** → "User dengan nickname tidak ditemukan"
4. **Already friends** → "Kalian sudah berteman"
5. **Reverse request exists** → "User ini sudah mengirim friend request ke kamu"

## Firestore Data Structure

### Collections yang Digunakan:

1. **`/friendRequests/{requestId}`**

   ```javascript
   {
     fromUid: string,
     toUid: string,
     fromNickname: string,
     toNickname: string,
     status: "pending" | "accepted" | "rejected",
     createdAt: timestamp,
     actedAt?: timestamp  // only when processed
   }
   ```

2. **`/users/{uid}/friends/{friendUid}`**

   ```javascript
   {
     uid: string,
     nickname: string,
     friendsSince: timestamp
   }
   ```

3. **`/users/{uid}`** (existing)

   ```javascript
   {
     uid: string,
     nickname: string,
     nicknameLower: string,
     createdAt: timestamp,
     updatedAt: timestamp
   }
   ```

4. **`/nicknames/{nicknameLower}`** (existing)
   ```javascript
   {
     uid: string,
     claimedAt: timestamp
   }
   ```

## Testing Checklist

### Basic Navigation:

- [ ] HomeScreen → FriendsScreen
- [ ] FriendsScreen → AddFriendsScreen
- [ ] FriendsScreen → FriendRequestsScreen
- [ ] Navigation back buttons work

### Add Friends:

- [ ] Search users by nickname
- [ ] Send friend request successfully
- [ ] Handle duplicate requests
- [ ] Handle self-requests
- [ ] Data saved to Firestore

### Friend Requests:

- [ ] View outgoing requests
- [ ] View incoming requests
- [ ] Accept friend request
- [ ] Reject friend request
- [ ] Real-time UI updates

### Friends List:

- [ ] Display friends correctly
- [ ] Show friendship duration
- [ ] Remove friend functionality
- [ ] Empty state handling

### Error Handling:

- [ ] Network errors handled gracefully
- [ ] Permission errors shown clearly
- [ ] Loading states work properly
- [ ] Success/error feedback shown

## Performance Considerations

1. **Search Debouncing**: Search dilakukan setelah 500ms delay
2. **Pagination**: Hasil search dibatasi 20 users
3. **Real-time**: Data di-refresh setelah operasi berhasil
4. **Efficient Queries**: Menggunakan index yang tepat di Firestore

## Next Steps

Setelah testing berhasil:

1. Implementasi real-time listeners untuk friend requests
2. Tambah push notifications untuk friend requests
3. Implementasi online status friends
4. Tambah fitur game invitation via friends list
