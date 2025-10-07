# Friends Feature Troubleshooting Guide

## Error Permission Denied - Solutions Applied

### 1. ✅ Firestore Rules Updated

- **Updated**: `firestore.rules` - Made friend requests read permission more permissive for debugging
- **Problem**: Previous rules were too restrictive for query operations
- **Solution**: Changed from individual user check to general signed-in user check

```javascript
// OLD (too restrictive)
allow read: if signedIn() &&
  (resource.data.fromUid == request.auth.uid ||
   resource.data.toUid == request.auth.uid);

// NEW (more permissive for debugging)
allow read: if signedIn();
```

### 2. ✅ Firestore Indexes Added

- **Added**: Composite indexes for friend requests queries
- **Problem**: Queries with `where + orderBy` need specific indexes
- **Solution**: Added indexes in `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "friendRequests",
      "fields": [
        { "fieldPath": "toUid", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "friendRequests",
      "fields": [
        { "fieldPath": "fromUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### 3. ✅ Enhanced Error Handling

- **Added**: Debug logging in FriendService methods
- **Added**: Specific permission error detection and user-friendly messages
- **Benefit**: Better error diagnosis and user feedback

## Testing Steps

### Step 1: Clear Browser Cache

1. Open Chrome DevTools (F12)
2. Go to Application/Storage tab
3. Clear all storage data
4. Refresh page and login again

### Step 2: Check Debug Console

1. Open Browser DevTools → Console tab
2. Look for DEBUG messages:
   ```
   DEBUG: Searching users with query: [nickname]
   DEBUG: Found X users
   DEBUG: Getting incoming friend requests for user: [uid]
   DEBUG: Found X incoming requests
   ```

### Step 3: Test Operations

1. **Search Users**: Type in search box, check console for debug output
2. **Send Friend Request**: Click "Tambah", check for success/error
3. **View Requests**: Navigate to requests screen, check for data loading

### Step 4: Check Firestore Data

1. Go to Firebase Console → Firestore Database
2. Verify data exists in collections:
   - `users` - User profiles with nicknames
   - `friendRequests` - Friend request documents
   - `users/{uid}/friends` - Friends sub-collections

## Common Error Solutions

### Error: "Missing or insufficient permissions"

**Cause**: Firestore Rules not deployed or user not authenticated
**Solutions**:

1. Redeploy rules: `firebase deploy --only firestore:rules`
2. Check user is logged in and has valid auth token
3. Verify rules allow the operation

### Error: "The query requires an index"

**Cause**: Missing composite index for complex queries
**Solutions**:

1. Deploy indexes: `firebase deploy --only firestore:indexes`
2. Wait for indexes to build (can take several minutes)
3. Check Firebase Console → Firestore → Indexes tab

### Error: "User dengan nickname tidak ditemukan"

**Cause**: Target user doesn't exist or nickname search failed
**Solutions**:

1. Verify target user has claimed a nickname
2. Check search query is exact match
3. Ensure user data exists in `/users` collection

### Error: "Network Error" or timeout

**Cause**: Firestore connection issues
**Solutions**:

1. Check internet connection
2. Try refreshing the page
3. Check Firebase project status

## Debug Information to Check

### In Browser Console:

```
DEBUG: Searching users with query: testuser
DEBUG: Found 1 users
DEBUG: Sending friend request to: testuser123
DEBUG: Found target user: ABC123
DEBUG: Current user nickname: myuser
DEBUG: Creating friend request with data: {...}
DEBUG: Friend request created successfully
```

### In Firestore Console:

```
Collection: friendRequests
Document ID: auto-generated
Fields:
- fromUid: "current-user-uid"
- toUid: "target-user-uid"
- fromNickname: "current-nickname"
- toNickname: "target-nickname"
- status: "pending"
- createdAt: [timestamp]
```

## Recovery Steps if Still Failing

### Option 1: Reset Rules to Debug Mode

Temporarily use very permissive rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Option 2: Test with Firebase Emulator

1. Install: `npm install -g firebase-tools`
2. Run: `firebase emulators:start --only firestore`
3. Point app to emulator for testing

### Option 3: Manual Data Creation

1. Go to Firestore Console
2. Manually create test friend request
3. Test UI reading functionality first

## Performance Considerations

### Index Building Time

- New indexes can take 5-15 minutes to build
- Large datasets may take longer
- Check Firebase Console → Firestore → Indexes for status

### Rule Deployment

- Rules deploy immediately
- May take 1-2 minutes for global propagation
- Test in incognito window to avoid cache

### Cache Issues

- Browser cache can interfere with auth tokens
- IndexedDB cache may store stale data
- Clear all browser data when testing

## Rollback Plan

If issues persist, rules can be reverted to original secure version:

```javascript
// Revert to original secure rules
match /friendRequests/{id} {
  allow read: if signedIn() &&
    (resource.data.fromUid == request.auth.uid ||
     resource.data.toUid == request.auth.uid);
  // ... rest of original rules
}
```

## Next Steps

1. **Test each operation** individually with debug console open
2. **Verify data flow** from UI → Service → Firestore
3. **Check rules logic** matches application requirements
4. **Optimize rules** once functionality confirmed working
5. **Remove debug logging** in production build
