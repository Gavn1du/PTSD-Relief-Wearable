import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // sign up
  Future<User?> signUp(
    String email,
    String password,
    int accountType,
    String? fullName,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      Map<int, String> accountNumToName = {
        0: "nurse",
        1: "patient",
        2: "individual",
      };
      String accountTypeStr = accountNumToName[accountType] ?? "individual";

      // store in users/uid/type
      DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
        'users/${user?.uid}',
      );

      switch (accountType) {
        case 0:
          await userRef.set({'patients': [], 'type': accountTypeStr});
          break;
        case 1:
          await userRef.set({
            'status': 'healthy',
            'type': accountTypeStr,
            'name': fullName,
            'room': "",
            'ADM': "",
            'BPM': 0,
          });
          break;
        case 2:
          await userRef.set({'type': accountTypeStr});
          break;
      }

      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // sign in
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // forgot password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print(e.toString());
    }
  }

  // sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
    }
  }
}
