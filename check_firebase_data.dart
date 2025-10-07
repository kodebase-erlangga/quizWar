import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  print('🔍 FIREBASE DATA STRUCTURE CHECKER');
  print('=====================================');

  try {
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;

    print('\n📊 CHECKING QUESTION BANKS COLLECTION...');
    await checkQuestionBanksStructure(firestore);

    print('\n🔧 CREATING MISSING QUESTION BANKS...');
    await createMissingQuestionBanks(firestore);

    print('\n✅ VERIFICATION COMPLETE');
    await verifyAllQuestionBanks(firestore);
  } catch (e) {
    print('❌ ERROR: $e');
  }
}

Future<void> checkQuestionBanksStructure(FirebaseFirestore firestore) async {
  final snapshot = await firestore.collection('questionBanks').get();

  print(
      '📋 Found ${snapshot.docs.length} documents in questionBanks collection:');

  for (final doc in snapshot.docs) {
    print('\n📄 Document ID: ${doc.id}');
    print('📝 Document Data: ${doc.data()}');

    // Check items subcollection
    final itemsSnapshot = await doc.reference.collection('items').get();
    print('📦 Items count: ${itemsSnapshot.docs.length}');

    if (itemsSnapshot.docs.isNotEmpty) {
      print('📋 Sample item IDs:');
      for (int i = 0; i < 3 && i < itemsSnapshot.docs.length; i++) {
        print('   - ${itemsSnapshot.docs[i].id}');
      }
    }
  }
}

Future<void> createMissingQuestionBanks(FirebaseFirestore firestore) async {
  // Check and create Matematika5-main
  await createQuestionBankIfMissing(
    firestore,
    'Matematika5-main',
    'Matematika Kelas 5',
    'Kumpulan soal matematika untuk kelas 5',
    'Matematika',
    '5',
  );

  // Check and create General7-main
  await createQuestionBankIfMissing(
    firestore,
    'General7-main',
    'General Kelas 7',
    'Kumpulan soal umum untuk kelas 7',
    'General',
    '7',
  );
}

Future<void> createQuestionBankIfMissing(
  FirebaseFirestore firestore,
  String bankId,
  String name,
  String description,
  String subject,
  String grade,
) async {
  final doc = await firestore.collection('questionBanks').doc(bankId).get();

  if (!doc.exists) {
    print('📝 Creating question bank: $bankId');
    await firestore.collection('questionBanks').doc(bankId).set({
      'name': name,
      'description': description,
      'subject': subject,
      'grade': grade,
      'totalQuestions': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add sample questions
    await addSampleQuestions(firestore, bankId, subject, grade);

    // Update question count
    final itemsSnapshot = await firestore
        .collection('questionBanks')
        .doc(bankId)
        .collection('items')
        .get();

    await firestore.collection('questionBanks').doc(bankId).update({
      'totalQuestions': itemsSnapshot.docs.length,
    });

    print('✅ Created $bankId with ${itemsSnapshot.docs.length} questions');
  } else {
    print('ℹ️ Question bank already exists: $bankId');

    // Check if it has items
    final itemsSnapshot = await doc.reference.collection('items').get();
    if (itemsSnapshot.docs.isEmpty) {
      print('📝 Adding sample questions to existing bank: $bankId');
      await addSampleQuestions(firestore, bankId, subject, grade);

      // Update question count
      final newItemsSnapshot = await doc.reference.collection('items').get();
      await doc.reference.update({
        'totalQuestions': newItemsSnapshot.docs.length,
      });
    }
  }
}

Future<void> addSampleQuestions(
  FirebaseFirestore firestore,
  String bankId,
  String subject,
  String grade,
) async {
  List<Map<String, dynamic>> sampleQuestions = [];

  if (subject == 'Matematika' && grade == '5') {
    sampleQuestions = [
      {
        'question': 'Berapa hasil dari 25 × 4?',
        'options': ['100', '90', '110', '80', '120'],
        'correctAnswer': 0,
        'explanation':
            '25 × 4 = 100. Dapat dihitung dengan 25 × 4 = 25 + 25 + 25 + 25 = 100',
        'difficulty': 'medium',
        'subject': subject,
        'grade': grade,
        'points': 10,
        'timeSuggestionSec': 15,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question':
            'Jika sebuah segitiga memiliki alas 8 cm dan tinggi 6 cm, berapa luasnya?',
        'options': ['24 cm²', '48 cm²', '14 cm²', '32 cm²', '16 cm²'],
        'correctAnswer': 0,
        'explanation': 'Luas segitiga = ½ × alas × tinggi = ½ × 8 × 6 = 24 cm²',
        'difficulty': 'medium',
        'subject': subject,
        'grade': grade,
        'points': 15,
        'timeSuggestionSec': 20,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question': 'Berapa hasil dari 144 ÷ 12?',
        'options': ['12', '10', '14', '11', '13'],
        'correctAnswer': 0,
        'explanation': '144 ÷ 12 = 12. Dapat dicek dengan 12 × 12 = 144',
        'difficulty': 'easy',
        'subject': subject,
        'grade': grade,
        'points': 10,
        'timeSuggestionSec': 15,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }
    ];
  } else if (subject == 'General' && grade == '7') {
    sampleQuestions = [
      {
        'question': 'Siapa presiden pertama Indonesia?',
        'options': ['Soekarno', 'Soeharto', 'B.J. Habibie', 'Megawati', 'SBY'],
        'correctAnswer': 0,
        'explanation':
            'Soekarno adalah presiden pertama Republik Indonesia yang menjabat dari 1945-1967',
        'difficulty': 'easy',
        'subject': subject,
        'grade': grade,
        'points': 10,
        'timeSuggestionSec': 15,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question': 'Apa ibu kota Indonesia?',
        'options': ['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang'],
        'correctAnswer': 0,
        'explanation':
            'Jakarta adalah ibu kota negara Indonesia sejak kemerdekaan',
        'difficulty': 'easy',
        'subject': subject,
        'grade': grade,
        'points': 5,
        'timeSuggestionSec': 10,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question': 'Berapa jumlah provinsi di Indonesia saat ini?',
        'options': ['34', '32', '35', '33', '36'],
        'correctAnswer': 0,
        'explanation':
            'Indonesia memiliki 34 provinsi termasuk DKI Jakarta, DI Yogyakarta, dan Aceh',
        'difficulty': 'medium',
        'subject': subject,
        'grade': grade,
        'points': 15,
        'timeSuggestionSec': 20,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }
    ];
  }

  // Add questions to Firestore
  for (final questionData in sampleQuestions) {
    await firestore
        .collection('questionBanks')
        .doc(bankId)
        .collection('items')
        .add(questionData);
  }

  print('📝 Added ${sampleQuestions.length} sample questions to $bankId');
}

Future<void> verifyAllQuestionBanks(FirebaseFirestore firestore) async {
  print('\n📊 FINAL VERIFICATION:');
  print('=====================');

  final snapshot = await firestore.collection('questionBanks').get();

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final itemsSnapshot = await doc.reference.collection('items').get();

    print('\n📚 ${doc.id}:');
    print('   Name: ${data['name'] ?? 'No name'}');
    print('   Subject: ${data['subject'] ?? 'No subject'}');
    print('   Grade: ${data['grade'] ?? 'No grade'}');
    print('   Questions: ${itemsSnapshot.docs.length}');
    print('   Stored total: ${data['totalQuestions'] ?? 0}');

    if (itemsSnapshot.docs.length != (data['totalQuestions'] ?? 0)) {
      print('   ⚠️ Mismatch detected! Updating...');
      await doc.reference.update({'totalQuestions': itemsSnapshot.docs.length});
      print('   ✅ Updated totalQuestions to ${itemsSnapshot.docs.length}');
    }
  }

  print('\n🎉 All question banks verified and ready!');
}
