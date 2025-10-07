import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('Creating General7-main question bank...');

  try {
    // Create General7-main document with basic metadata
    await firestore.collection('questionBanks').doc('General7-main').set({
      'name': 'General Kelas 7',
      'description': 'Kumpulan soal umum kelas 7',
      'subject': 'General',
      'grade': '7',
      'totalQuestions': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('Successfully created General7-main question bank');

    // Verify both documents exist
    final snapshot = await firestore.collection('questionBanks').get();
    print('Total question banks: ${snapshot.docs.length}');

    for (final doc in snapshot.docs) {
      print('Document ID: ${doc.id}');
      print('Document data: ${doc.data()}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }

  print('Done');
}
