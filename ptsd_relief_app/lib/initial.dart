import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ptsd_relief_app/screens/loginscreen.dart';
import 'package:ptsd_relief_app/screens/homescreen.dart';
import 'package:ptsd_relief_app/services/data.dart';

class Initial extends StatelessWidget {
  const Initial({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = Auth().user;

    if (user == null) {
      return const Loginscreen();
    }

    final userRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');

    return StreamBuilder(
      stream: userRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Loginscreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          Map<String, dynamic> userData = {};
          final dataSnapshot = snapshot.data!.snapshot;
          if (dataSnapshot.value != null) {
            userData = Map<String, dynamic>.from(dataSnapshot.value as Map);
            print("User data changed: $userData");
          }
          Data().saveFirebaseData("data", userData);
        }

        return const Homescreen();
      },
    );
  }
}
