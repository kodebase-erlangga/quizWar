import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('🔍 Checking existing question banks in database...');
  print('===============================================');

  try {
    // Just verify what question banks exist - don't create hard-coded ones
    await verifyQuestionBanks(firestore);

    print('\n✅ Database check complete!');
    print(
        'ℹ️  The app will automatically create question banks when users add questions.');
    print('ℹ️  No manual setup needed - the system is now fully automated!');
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> verifyQuestionBanks(FirebaseFirestore firestore) async {
  print('\n📊 CURRENT QUESTION BANKS IN DATABASE:');
  print('======================================');

  final snapshot = await firestore.collection('questionBanks').get();
  print('📋 Total question banks found: ${snapshot.docs.length}');

  if (snapshot.docs.isEmpty) {
    print('\n📭 No question banks found in database yet.');
    print('ℹ️  This is normal for a fresh installation.');
    print(
        'ℹ️  Question banks will be created automatically when users add questions.');
    return;
  }

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final items = await doc.reference.collection('items').get();

    print('\n📚 ${doc.id}:');
    print('   📛 Name: ${data['name'] ?? 'No name'}');
    print('   📖 Subject: ${data['subject'] ?? 'No subject'}');
    print('   🎓 Grade: ${data['grade'] ?? 'No grade'}');
    print('   📊 Stored Total: ${data['totalQuestions'] ?? 0}');
    print('   📝 Actual Questions: ${items.docs.length}');
    print(
        '   👤 Created by: ${data['isUserGenerated'] == true ? 'User' : 'System'}');

    if (items.docs.isNotEmpty) {
      final sampleQuestion = items.docs.first.data();
      print('   💡 Sample question: "${sampleQuestion['question']}"');
    }

    // Check for data consistency
    if (items.docs.length != (data['totalQuestions'] ?? 0)) {
      print('   ⚠️  Inconsistent count detected - will be auto-fixed by app');
    }
  }

  print('\n🎯 SUMMARY:');
  print('- Question banks are managed automatically by the app');
  print('- User-created questions will create new banks as needed');
  print('- All existing question banks will appear in the online quiz screen');
}
