import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// Fungsi test sederhana (Gen 1)
export const helloWorld = functions.https.onRequest((req, res) => {
  res.send("Hello from Gen1!");
});

// Callable function untuk claim nickname
export const claimNickname = functions.https.onCall(async (data, context) => {
  // Pastikan user sudah login
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to claim nickname'
    );
  }

  const uid = context.auth.uid;
  const { nickname } = data;

  // Validasi input
  if (!nickname || typeof nickname !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Nickname is required and must be a string'
    );
  }

  // Validasi format nickname
  const nicknameRegex = /^[a-zA-Z0-9_]{3,20}$/;
  if (!nicknameRegex.test(nickname)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Nickname must be 3-20 characters and contain only letters, numbers, and underscores'
    );
  }

  const nicknameLower = nickname.toLowerCase();

  try {
    // Gunakan transaction untuk memastikan atomicity
    const result = await db.runTransaction(async (transaction) => {
      // Cek apakah nickname sudah diambil
      const nicknameDoc = await transaction.get(db.collection('nicknames').doc(nicknameLower));
      
      if (nicknameDoc.exists) {
        throw new functions.https.HttpsError(
          'already-exists',
          'This nickname is already taken'
        );
      }

      // Cek apakah user sudah punya nickname
      const userDoc = await transaction.get(db.collection('users').doc(uid));
      
      if (userDoc.exists && userDoc.data()?.nickname) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'User already has a nickname'
        );
      }

      // Claim nickname di collection nicknames
      transaction.set(db.collection('nicknames').doc(nicknameLower), {
        uid: uid,
        claimedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update atau buat dokumen user
      const userData = {
        uid: uid,
        nickname: nickname,
        nicknameLower: nicknameLower,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (userDoc.exists) {
        transaction.update(db.collection('users').doc(uid), userData);
      } else {
        transaction.set(db.collection('users').doc(uid), {
          ...userData,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return { success: true, nickname: nickname };
    });

    return result;
  } catch (error) {
    console.error('Error claiming nickname:', error);
    
    // Jika error sudah berupa HttpsError, lempar ulang
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Error lainnya
    throw new functions.https.HttpsError(
      'internal',
      'Failed to claim nickname. Please try again.'
    );
  }
});