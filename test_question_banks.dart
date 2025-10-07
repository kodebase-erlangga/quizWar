import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('Fetching all question banks...');

  try {
    final snapshot = await firestore.collection('questionBanks').get();
    print(
        'Found ${snapshot.docs.length} documents in questionBanks collection');

    for (final doc in snapshot.docs) {
      print('Document ID: ${doc.id}');
      print('Document data: ${doc.data()}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }
}
