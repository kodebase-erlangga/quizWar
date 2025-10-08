# Question Visibility Fix

## Problem Description

User-created questions were not appearing in the online quiz screen immediately after being uploaded to Firestore. The issue was that when users created questions, the questions were being saved to the subcollection (`items`) but the main question bank document was not being created or updated with proper metadata.

## Root Cause

The question creation flow in `lib/core/services/question_service.dart` was:

1. Saving questions to: `questionBanks/{bankId}/items/{questionId}`
2. But NOT ensuring that the parent document `questionBanks/{bankId}` existed
3. The online quiz service expects question banks to exist as documents in the `questionBanks` collection

## Solution Implemented

Enhanced the `createQuestion` method in `QuestionService` to:

### 1. Ensure Question Bank Exists (`_ensureQuestionBankExists`)

- Checks if the question bank document exists before creating questions
- Creates the question bank document with proper metadata if it doesn't exist
- Sets up all required fields:
  - `id`: Bank identifier (e.g., "Matematika7-main")
  - `name`: Display name (e.g., "Matematika Kelas 7")
  - `subject`: Subject name
  - `grade`: Grade level
  - `description`: Auto-generated description
  - `totalQuestions`: Initially 0, updated after question creation
  - `createdAt`/`updatedAt`: Timestamps
  - `isActive`: true
  - `isUserGenerated`: true (to distinguish from pre-loaded content)

### 2. Update Question Bank Metadata (`_updateQuestionBankMetadata`)

- Counts total questions in the bank after each question creation
- Updates the `totalQuestions` field in the question bank document
- Updates the `updatedAt` timestamp
- Ensures the question bank appears in online quiz listings

### 3. Enhanced Error Handling

- Added comprehensive error handling and logging
- Print statements for debugging (can be removed in production)
- Graceful error recovery for metadata updates

## Technical Details

### Modified Files

- `lib/core/services/question_service.dart`

### Key Changes

```dart
// Before: Only saved question to subcollection
await _firestore
    .collection('questionBanks')
    .doc(bankId)
    .collection('items')
    .doc(questionId)
    .set(question.toFirestore());

// After: Ensures parent document exists and updates metadata
await _ensureQuestionBankExists(bankId, question.subject, question.grade);
await _firestore
    .collection('questionBanks')
    .doc(bankId)
    .collection('items')
    .doc(questionId)
    .set(question.toFirestore());
await _updateQuestionBankMetadata(bankId);
```

### Data Structure

```
questionBanks/
├── {subject}{grade}-main/           <- Main document (now properly created)
│   ├── id: "Matematika7-main"
│   ├── name: "Matematika Kelas 7"
│   ├── totalQuestions: 5
│   ├── isUserGenerated: true
│   └── items/                       <- Subcollection
│       ├── question1
│       ├── question2
│       └── ...
```

## Expected Behavior After Fix

1. When a user creates questions, the question bank document is automatically created
2. The question bank appears immediately in the online quiz screen
3. The total question count is accurately maintained
4. User-generated content is properly distinguished from pre-loaded content

## Testing Recommendations

1. Create a new question through the app
2. Navigate to online quiz screen
3. Verify the subject/grade combination appears in the list
4. Verify the question count is accurate
5. Test with multiple questions in the same bank
6. Test with different subjects and grades

## Migration Considerations

For existing user-generated questions that may not have proper question bank documents:

- The fix will automatically create missing question bank documents when new questions are added to existing banks
- Consider running a one-time migration script to create question bank documents for existing user-generated content

## Performance Impact

- Minimal performance impact: Only 1-2 additional Firestore operations per question creation
- Read operations (checking if bank exists) are cached by Firestore
- Write operations (creating/updating bank document) are lightweight

## Future Enhancements

- Add batch operations for bulk question creation
- Implement soft delete for question banks
- Add question bank categorization and tagging
- Implement question bank sharing between users
