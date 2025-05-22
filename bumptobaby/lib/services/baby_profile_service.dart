import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/models/baby_profile.dart';
import 'package:bumptobaby/services/diary_service.dart';
import 'dart:developer' as developer;

class BabyProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DiaryService _diaryService = DiaryService();
  
  // Get the current user ID
  String? get _userId => _auth.currentUser?.uid;
  
  // Check if user is logged in
  bool get isUserLoggedIn => _userId != null;

  // Get reference to baby profiles collection for current user
  CollectionReference<Map<String, dynamic>> get _profilesCollection {
    if (_userId == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('babyProfiles');
  }


  
  // Create a new baby profile
  Future<BabyProfile> createBabyProfile({
    required String name,
    DateTime? dateOfBirth,
    required bool isPregnancy,
    DateTime? dueDate,
    String? gender,
  }) async {
    try {
      if (_userId == null) {
        developer.log('Cannot create baby profile: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Creating baby profile for user: $_userId with name: $name', name: 'BabyProfileService');
      
      // Ensure the user document exists
      await _firestore.collection('users').doc(_userId).set({
        'name': _auth.currentUser?.displayName ?? 'User',
        'email': _auth.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      
      // Create the data to be saved
      final Map<String, dynamic> profileData = {
        'name': name,
        'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
        'isPregnancy': isPregnancy,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Create the document in Firestore
      final docRef = await _profilesCollection.add(profileData);
      final String profileId = docRef.id;
      
      developer.log('Created baby profile: $profileId with data: $profileData', name: 'BabyProfileService');
      
      // Create a BabyProfile object with the generated ID
      final profile = BabyProfile(
        id: profileId,
        name: name,
        dateOfBirth: dateOfBirth,
        isPregnancy: isPregnancy,
        dueDate: dueDate,
        gender: gender,
      );
      
      // Set this profile as the current one
      await setCurrentBabyProfile(profile.id);
      
      developer.log('Returning new baby profile with ID: ${profile.id}', name: 'BabyProfileService');
      return profile;
    } catch (e) {
      developer.log('Error creating baby profile: $e', name: 'BabyProfileService');
      rethrow;
    }
  }
  
  // Get all baby profiles for the current user
  Future<List<BabyProfile>> getBabyProfiles() async {
    try {
      if (_userId == null) {
        developer.log('Cannot get baby profiles: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Fetching baby profiles for user: $_userId', name: 'BabyProfileService');
      
      final snapshot = await _profilesCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      developer.log('Retrieved ${snapshot.docs.length} baby profiles from Firebase with IDs: ${snapshot.docs.map((d) => d.id).join(", ")}', name: 'BabyProfileService');
      
      return snapshot.docs.map((doc) => BabyProfile.fromFirestore(doc)).toList();
    } catch (e) {
      developer.log('Error getting baby profiles: $e', name: 'BabyProfileService');
      return [];
    }
  }
  
  // Update an existing baby profile
  Future<void> updateBabyProfile(BabyProfile profile) async {
    try {
      if (_userId == null) {
        developer.log('Cannot update baby profile: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Updating baby profile: ${profile.id}', name: 'BabyProfileService');
      
      final Map<String, dynamic> updateData = {
        'name': profile.name,
        'dateOfBirth': profile.dateOfBirth != null ? Timestamp.fromDate(profile.dateOfBirth!) : null,
        'isPregnancy': profile.isPregnancy,
        'dueDate': profile.dueDate != null ? Timestamp.fromDate(profile.dueDate!) : null,
        'gender': profile.gender,
        'points': profile.points,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _profilesCollection.doc(profile.id).update(updateData);
      
      developer.log('Successfully updated baby profile: ${profile.id}', name: 'BabyProfileService');
    } catch (e) {
      developer.log('Error updating baby profile: $e', name: 'BabyProfileService');
      rethrow;
    }
  }
  
  // Delete a baby profile and all associated diary entries
  Future<void> deleteBabyProfile(String profileId) async {
    try {
      if (_userId == null) {
        developer.log('Cannot delete baby profile: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Deleting baby profile: $profileId', name: 'BabyProfileService');
      
      // First delete all diary entries for this profile
      await _diaryService.deleteAllDiaryEntries(profileId);
      
      // Then delete the profile itself
      await _profilesCollection.doc(profileId).delete();
      
      developer.log('Successfully deleted baby profile: $profileId', name: 'BabyProfileService');
    } catch (e) {
      developer.log('Error deleting baby profile: $e', name: 'BabyProfileService');
      rethrow;
    }
  }
  
  // Get a specific baby profile by ID
  Future<BabyProfile?> getBabyProfile(String profileId) async {
    try {
      if (_userId == null) {
        developer.log('Cannot get baby profile: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Fetching baby profile: $profileId', name: 'BabyProfileService');
      
      final doc = await _profilesCollection.doc(profileId).get();
      
      if (doc.exists) {
        developer.log('Found baby profile: $profileId', name: 'BabyProfileService');
        return BabyProfile.fromFirestore(doc);
      } else {
        developer.log('Baby profile not found: $profileId', name: 'BabyProfileService');
        return null;
      }
    } catch (e) {
      developer.log('Error getting baby profile: $e', name: 'BabyProfileService');
      return null;
    }
  }

  // Store the user's current baby profile selection
  Future<void> setCurrentBabyProfile(String profileId) async {
    try {
      if (_userId == null) {
        developer.log('Cannot set current baby profile: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Setting current baby profile to: $profileId for user: $_userId', name: 'BabyProfileService');
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .update({
            'currentBabyProfileId': profileId,
            'lastUpdated': FieldValue.serverTimestamp()
          });
      
      developer.log('Successfully set current baby profile: $profileId', name: 'BabyProfileService');
    } catch (e) {
      // If the user document doesn't exist yet, create it
      if (e is FirebaseException && e.code == 'not-found') {
        try {
          await _firestore
              .collection('users')
              .doc(_userId)
              .set({
                'currentBabyProfileId': profileId,
                'email': _auth.currentUser?.email,
                'createdAt': FieldValue.serverTimestamp(),
                'lastUpdated': FieldValue.serverTimestamp()
              });
          developer.log('Created user document and set current baby profile: $profileId', name: 'BabyProfileService');
        } catch (innerException) {
          developer.log('Error creating user document: $innerException', name: 'BabyProfileService');
          rethrow;
        }
      } else {
        developer.log('Error setting current baby profile: $e', name: 'BabyProfileService');
        rethrow;
      }
    }
  }
  
  // Get the user's current baby profile selection
  Future<String?> getCurrentBabyProfileId() async {
    try {
      if (_userId == null) {
        developer.log('Cannot get current baby profile ID: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Fetching current baby profile ID for user: $_userId', name: 'BabyProfileService');
      
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();
      
      if (doc.exists) {
        final profileId = doc.data()?['currentBabyProfileId'] as String?;
        developer.log('Current baby profile ID: $profileId', name: 'BabyProfileService');
        return profileId;
      } else {
        developer.log('User document not found, creating one', name: 'BabyProfileService');
        
        // Create the user document if it doesn't exist
        await _firestore
            .collection('users')
            .doc(_userId)
            .set({
              'email': _auth.currentUser?.email,
              'createdAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp()
            });
        
        return null;
      }
    } catch (e) {
      developer.log('Error getting current baby profile ID: $e', name: 'BabyProfileService');
      return null;
    }
  }

  // Add points to a profile
  Future<void> addPointsToProfile(String profileId, int pointsToAdd) async {
    try {
      if (_userId == null) {
        developer.log('Cannot add points: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Adding $pointsToAdd points to profile: $profileId', name: 'BabyProfileService');
      
      // Use a transaction to ensure we're adding to the current value
      await _firestore.runTransaction((transaction) async {
        // Get the current profile document
        final profileDoc = await transaction.get(_profilesCollection.doc(profileId));
        
        if (!profileDoc.exists) {
          throw Exception('Profile not found');
        }
        
        // Get current points or default to 0
        final currentPoints = (profileDoc.data()?['points'] as int?) ?? 0;
        final newPoints = currentPoints + pointsToAdd;
        
        // Update the points field
        transaction.update(_profilesCollection.doc(profileId), {
          'points': newPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        developer.log('Updated points from $currentPoints to $newPoints for profile $profileId', name: 'BabyProfileService');
      });
      
      // Also update the user's total points
      await updateUserPoints(pointsToAdd);
      
    } catch (e) {
      developer.log('Error adding points to profile: $e', name: 'BabyProfileService');
      rethrow;
    }
  }
  
  // Add points directly to the user document
  Future<void> updateUserPoints(int pointsToAdd) async {
    try {
      if (_userId == null) {
        developer.log('Cannot update user points: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Adding $pointsToAdd points to user: $_userId', name: 'BabyProfileService');
      
      // Use a transaction to ensure we're adding to the current value
      await _firestore.runTransaction((transaction) async {
        // Get the current user document
        final userDoc = await transaction.get(_firestore.collection('users').doc(_userId));
        
        if (!userDoc.exists) {
          throw Exception('User document not found');
        }
        
        // Get current total points or default to 0
        final currentPoints = (userDoc.data()?['totalPoints'] as int?) ?? 0;
        final newPoints = currentPoints + pointsToAdd;
        
        // Update the total points field in the user document
        transaction.update(_firestore.collection('users').doc(_userId), {
          'totalPoints': newPoints,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        developer.log('Updated total points from $currentPoints to $newPoints for user $_userId', name: 'BabyProfileService');
      });
      
    } catch (e) {
      // If the user document doesn't have the totalPoints field yet
      if (e is FirebaseException && e.code == 'not-found') {
        try {
          // Try to update the user document with an initial points value
          await _firestore.collection('users').doc(_userId).set({
            'totalPoints': pointsToAdd,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          developer.log('Created totalPoints field for user $_userId with initial value: $pointsToAdd', name: 'BabyProfileService');
        } catch (innerException) {
          developer.log('Error creating totalPoints field: $innerException', name: 'BabyProfileService');
          rethrow;
        }
      } else {
        developer.log('Error updating user points: $e', name: 'BabyProfileService');
        rethrow;
      }
    }
  }
  
  // Get the user's total points
  Future<int> getUserTotalPoints() async {
    try {
      if (_userId == null) {
        developer.log('Cannot get user points: User not logged in', name: 'BabyProfileService');
        throw Exception('User not logged in');
      }
      
      developer.log('Fetching total points for user: $_userId', name: 'BabyProfileService');
      
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();
      
      if (doc.exists) {
        final totalPoints = (doc.data()?['totalPoints'] as int?) ?? 0;
        developer.log('User total points: $totalPoints', name: 'BabyProfileService');
        return totalPoints;
      } else {
        developer.log('User document not found, returning 0 points', name: 'BabyProfileService');
        return 0;
      }
    } catch (e) {
      developer.log('Error getting user total points: $e', name: 'BabyProfileService');
      return 0;
    }
  }
} 