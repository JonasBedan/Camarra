import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  Future<User?> registerWithEmail(
    String email,
    String password,
    String username, {
    bool? darkModeEnabled,
  }) async {
    try {
      // First create the user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Reserve username and create user doc (after authentication)
      if (result.user != null) {
        try {
          // Fail-fast if already taken via public usernames collection
          if (await _userService.isUsernameTaken(username)) {
            await result.user!.delete();
            throw Exception('Username "$username" is already taken.');
          }

          // Atomically reserve username
          await _userService.reserveUsername(username, result.user!.uid);

          // Sanity check against users collection after auth (requires auth)
          if (await _userService.doesUserExistWithUsername(username)) {
            await result.user!.delete();
            throw Exception('Username "$username" is already taken.');
          }

          // Create user document
          await _userService.createUser(
            email,
            username,
            darkModeEnabled: darkModeEnabled,
          );
        } catch (e) {
          // Rollback auth account if reservation failed
          await result.user!.delete();
          rethrow;
        }
      }

      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String uid) async {
    final user = await _userService.getUser(uid);
    if (user == null) return false;

    return user.onboarding.mood.isNotEmpty &&
        user.onboarding.goal.isNotEmpty &&
        user.onboarding.mode.isNotEmpty &&
        user.onboarding.socialComfort.isNotEmpty &&
        user.onboarding.talkFrequency.isNotEmpty;
  }
}
