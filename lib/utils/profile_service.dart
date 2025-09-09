import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class ProfileService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final UserService _userService = UserService();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      print(
        'Attempting to pick image from ${fromCamera ? 'camera' : 'gallery'}',
      );

      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        print('Image picked successfully: ${image.path}');
        final file = File(image.path);

        // Verify file exists and has content
        if (await file.exists()) {
          final fileSize = await file.length();
          print('Image file size: $fileSize bytes');

          if (fileSize > 0) {
            return file;
          } else {
            print('Error: Image file is empty');
            throw Exception('Selected image file is empty');
          }
        } else {
          print('Error: Image file does not exist');
          throw Exception('Selected image file does not exist');
        }
      } else {
        print('No image selected by user');
        return null;
      }
    } catch (e) {
      print('Error picking image: $e');
      rethrow; // Re-throw to let caller handle the specific error
    }
  }

  /// Upload profile picture to Firebase Storage
  Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      print('Starting upload for user: ${currentUser.uid}');

      // Verify file exists before upload
      if (!await imageFile.exists()) {
        throw Exception('Image file no longer exists');
      }

      final fileSize = await imageFile.length();
      print('Uploading file size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Cannot upload empty file');
      }

      // Check file size limit (5MB)
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception(
          'Image file is too large. Please select an image smaller than 5MB.',
        );
      }

      // Create a unique filename
      final fileName =
          'profile_pictures/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('Upload filename: $fileName');

      // Upload to Firebase Storage with metadata
      final ref = _storage.ref().child(fileName);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': currentUser.uid,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );

      print('Starting Firebase Storage upload...');
      final uploadTask = ref.putFile(imageFile, metadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('Upload completed successfully');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');

      // Verify the URL is accessible
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL from Firebase Storage');
      }

      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'storage/unauthorized':
          throw Exception(
            'You don\'t have permission to upload images. Please check your account settings.',
          );
        case 'storage/canceled':
          throw Exception('Upload was canceled. Please try again.');
        case 'storage/unknown':
          throw Exception(
            'An unknown error occurred during upload. Please try again.',
          );
        case 'storage/object-not-found':
          throw Exception(
            'Failed to create file in storage. Please try again.',
          );
        case 'storage/bucket-not-found':
          throw Exception(
            'Firebase Storage is not set up. Please configure Firebase Storage in the Firebase Console.',
          );
        case 'storage/project-not-found':
          throw Exception(
            'Project configuration error. Please contact support.',
          );
        case 'storage/quota-exceeded':
          throw Exception('Storage quota exceeded. Please contact support.');
        case 'storage/unauthenticated':
          throw Exception('Authentication expired. Please log in again.');
        case 'storage/retry-limit-exceeded':
          throw Exception(
            'Upload failed after multiple attempts. Please check your internet connection.',
          );
        default:
          // Check if error message indicates Storage is not set up
          if (e.message?.contains('Firebase Storage has not been set up') ==
                  true ||
              e.message?.contains('storage bucket') == true) {
            throw Exception(
              'Firebase Storage is not set up. Please configure Firebase Storage in the Firebase Console.',
            );
          }
          throw Exception(
            'Upload failed: ${e.message ?? 'Unknown Firebase error'}',
          );
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Update user's profile picture URL in Firestore
  Future<bool> updateProfilePicture(String imageUrl) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Update the user document with the new profile picture URL
      await _userService.updateUser(currentUser.uid, {
        'profilePictureUrl': imageUrl,
      });

      return true;
    } catch (e) {
      print('Error updating profile picture: $e');
      return false;
    }
  }

  /// Complete flow: pick image, upload, and update user
  Future<bool> changeProfilePicture({bool fromCamera = false}) async {
    try {
      print('Starting profile picture change process...');

      // Pick image
      final imageFile = await pickImage(fromCamera: fromCamera);
      if (imageFile == null) {
        print('No image selected, operation canceled by user');
        return false;
      }

      // Upload to Firebase Storage
      final imageUrl = await uploadProfilePicture(imageFile);
      if (imageUrl == null) {
        throw Exception('Upload failed - no URL returned');
      }

      // Update user document
      final success = await updateProfilePicture(imageUrl);
      if (!success) {
        throw Exception('Failed to update user profile with new image URL');
      }

      print('Profile picture change completed successfully');
      return true;
    } catch (e) {
      print('Error changing profile picture: $e');
      rethrow; // Let the UI handle the error message
    }
  }

  /// Delete profile picture (set to null)
  Future<bool> removeProfilePicture() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Update the user document to remove profile picture URL
      await _userService.updateUser(currentUser.uid, {
        'profilePictureUrl': null,
      });

      return true;
    } catch (e) {
      print('Error removing profile picture: $e');
      return false;
    }
  }
}
