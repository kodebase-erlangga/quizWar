import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('Creating missing question banks and sample questions...');

  try {
    // Create Matematika5-main question bank if it doesn't exist
    await createQuestionBankIfNotExists(
      firestore,
      'Matematika5-main',
      'Matematika Kelas 5',
      'Kumpulan soal matematika untuk kelas 5',
      'Matematika',
      '5',
    );

    // Create General7-main question bank if it doesn't exist
    await createQuestionBankIfNotExists(
      firestore,
      'General7-main',
      'General Kelas 7',
      'Kumpulan soal umum untuk kelas 7',
      'General',
      '7',
    );

    // Add sample questions to General7-main
    await addSampleQuestionsToBank(firestore, 'General7-main');

    // Add sample questions to Matematika5-main
    await addSampleQuestionsToBank(firestore, 'Matematika5-main');

    // Verify all question banks
    await verifyQuestionBanks(firestore);
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> createQuestionBankIfNotExists(
  FirebaseFirestore firestore,
  String bankId,
  String name,
  String description,
  String subject,
  String grade,
) async {
  final doc = await firestore.collection('questionBanks').doc(bankId).get();

  if (!doc.exists) {
    await firestore.collection('questionBanks').doc(bankId).set({
      'name': name,
      'description': description,
      'subject': subject,
      'grade': grade,
      'totalQuestions': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('Created question bank: $bankId');
  } else {
    print('Question bank already exists: $bankId');
  }
}

Future<void> addSampleQuestionsToBank(
    FirebaseFirestore firestore, String bankId) async {
  final items = await firestore
      .collection('questionBanks')
      .doc(bankId)
      .collection('items')
      .get();

  if (items.docs.isNotEmpty) {
    print('Questions already exist in $bankId, skipping sample creation');
    return;
  }

  List<Map<String, dynamic>> sampleQuestions = [];

  if (bankId == 'General7-main') {
    sampleQuestions = [
      {
        'question': 'Apa ibukota negara Indonesia?',
        'options': ['Jakarta', 'Surabaya', 'Bandung', 'Medan'],
        'correctAnswer': 0,
        'explanation': 'Jakarta adalah ibukota negara Indonesia',
        'difficulty': 'easy',
        'subject': 'General',
        'grade': '7',
        'points': 10,
        'timeSuggestionSec': 15,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question': 'Siapa presiden pertama Indonesia?',
        'options': ['Soeharto', 'Soekarno', 'Habibie', 'Megawati'],
        'correctAnswer': 1,
        'explanation': 'Soekarno adalah presiden pertama Indonesia',
        'difficulty': 'easy',
        'subject': 'General',
        'grade': '7',
        'points': 10,
        'timeSuggestionSec': 15,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }
    ];
  } else if (bankId == 'Matematika5-main') {
    sampleQuestions = [
      {
        'question': 'Hasil dari 25 + 17 adalah?',
        'options': ['40', '41', '42', '43'],
        'correctAnswer': 2,
        'explanation': '25 + 17 = 42',
        'difficulty': 'easy',
        'subject': 'Matematika',
        'grade': '5',
        'points': 10,
        'timeSuggestionSec': 20,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'question': 'Hasil dari 8 × 7 adalah?',
        'options': ['54', '55', '56', '57'],
        'correctAnswer': 2,
        'explanation': '8 × 7 = 56',
        'difficulty': 'medium',
        'subject': 'Matematika',
        'grade': '5',
        'points': 15,
        'timeSuggestionSec': 25,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }
    ];
  }

  // Add the sample questions
  for (int i = 0; i < sampleQuestions.length; i++) {
    await firestore
        .collection('questionBanks')
        .doc(bankId)
        .collection('items')
        .add(sampleQuestions[i]);
  }

  // Update question bank total count
  await firestore.collection('questionBanks').doc(bankId).update({
    'totalQuestions': sampleQuestions.length,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  print('Added ${sampleQuestions.length} sample questions to $bankId');
}

Future<void> verifyQuestionBanks(FirebaseFirestore firestore) async {
  print('\n=== VERIFICATION ===');
  final snapshot = await firestore.collection('questionBanks').get();
  print('Total question banks: ${snapshot.docs.length}');

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final items = await doc.reference.collection('items').get();

    print('\n--- ${doc.id} ---');
    print('Name: ${data['name']}');
    print('Subject: ${data['subject']}');
    print('Grade: ${data['grade']}');
    print('Stored Total: ${data['totalQuestions']}');
    print('Actual Items: ${items.docs.length}');

    if (items.docs.isNotEmpty) {
      print('Sample question: ${items.docs.first.data()['question']}');
    }
  }
}
