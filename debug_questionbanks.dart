import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  print('🔍 Starting Firebase debug without initialization...');

  try {
    final firestore = FirebaseFirestore.instance;

    // Get all documents from questionBanks collection
    print('📊 Fetching all documents from questionBanks collection...');
    final snapshot = await firestore.collection('questionBanks').get();

    print('📈 Total documents found: ${snapshot.docs.length}');
    print('');

    for (int i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      final data = doc.data();

      print('${i + 1}. Document ID: ${doc.id}');
      print('   Data keys: ${data.keys.toList()}');
      print('   name: ${data['name'] ?? 'NOT_SET'}');
      print('   subject: ${data['subject'] ?? 'NOT_SET'}');
      print('   grade: ${data['grade'] ?? 'NOT_SET'}');
      print('   description: ${data['description'] ?? 'NOT_SET'}');
      print('   totalQuestions: ${data['totalQuestions'] ?? 'NOT_SET'}');
      print('   createdAt: ${data['createdAt'] ?? 'NOT_SET'}');
      print('   updatedAt: ${data['updatedAt'] ?? 'NOT_SET'}');

      // Check if items subcollection exists
      final itemsSnapshot = await doc.reference.collection('items').get();
      print('   items subcollection: ${itemsSnapshot.docs.length} documents');

      if (itemsSnapshot.docs.isNotEmpty) {
        print(
            '   Sample item IDs: ${itemsSnapshot.docs.take(3).map((e) => e.id).toList()}');
      }

      print('');
    }

    print('✅ Debug complete!');
  } catch (e) {
    print('❌ Error: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
