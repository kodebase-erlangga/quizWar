import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script untuk upload sample questions ke Firebase
///
/// Jalankan dengan: dart upload_questions.dart

void main() async {
  print('🚀 Starting question upload to Firebase...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;

    // Read sample question data
    final file = File('sample_question_data.json');
    if (!file.existsSync()) {
      print('❌ File sample_question_data.json tidak ditemukan');
      return;
    }

    final jsonString = await file.readAsString();
    final data = json.decode(jsonString) as Map<String, dynamic>;

    print('📊 Found ${data.keys.length} question banks in sample data');

    // Upload each question bank
    for (final entry in data.entries) {
      final bankId = entry.key;
      final bankData = entry.value as Map<String, dynamic>;

      print('\n📚 Uploading question bank: $bankId');
      print('   Name: ${bankData['name']}');
      print('   Subject: ${bankData['subject']}');

      // Extract items (questions)
      final items = bankData['items'] as Map<String, dynamic>? ?? {};
      print('   Questions: ${items.length}');

      // Prepare bank document (without items)
      final bankDocument = Map<String, dynamic>.from(bankData);
      bankDocument.remove('items'); // Remove items from main document
      bankDocument['totalQuestions'] = items.length;
      bankDocument['createdAt'] = FieldValue.serverTimestamp();

      // Upload question bank document
      await firestore.collection('questionBanks').doc(bankId).set(bankDocument);
      print('✅ Question bank uploaded: $bankId');

      // Upload each question as sub-document
      for (final itemEntry in items.entries) {
        final questionId = itemEntry.key;
        final questionData = itemEntry.value as Map<String, dynamic>;

        // Add metadata
        questionData['createdAt'] = FieldValue.serverTimestamp();
        questionData['createdBy'] = 'system';

        await firestore
            .collection('questionBanks')
            .doc(bankId)
            .collection('items')
            .doc(questionId)
            .set(questionData);

        print(
            '  ✅ Question uploaded: $questionId - ${questionData['question']?.toString().substring(0, 50)}...');
      }

      print('🎯 Completed uploading ${items.length} questions for $bankId');
    }

    print('\n🎉 All question banks uploaded successfully!');

    // Verify upload
    print('\n🔍 Verifying upload...');
    final banksSnapshot = await firestore.collection('questionBanks').get();
    print('📊 Total question banks in Firebase: ${banksSnapshot.docs.length}');

    for (final doc in banksSnapshot.docs) {
      final itemsSnapshot = await firestore
          .collection('questionBanks')
          .doc(doc.id)
          .collection('items')
          .get();
      print('   ${doc.id}: ${itemsSnapshot.docs.length} questions');
    }
  } catch (e) {
    print('❌ Error uploading questions: $e');
    print('Stack trace: $e');
  }
}
