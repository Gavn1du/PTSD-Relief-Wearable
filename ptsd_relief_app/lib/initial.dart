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
    // Data.clearAnomalyHistory();
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
          print("DataSnapshot: $dataSnapshot");
          if (dataSnapshot.value != null) {
            userData = Map<String, dynamic>.from(dataSnapshot.value as Map);
            print("User data changed: $userData");
          }
          Data().saveFirebaseDataToSharedPref("data", userData);

          // Keep live data synced for display. The app does not generate
          // health conclusions or condition-specific advice from sensor data.
          /**
             * // Process the history data as needed
                    print('History data loaded: $value');
                    // parse through each entry
                    for (String entry in value) {
                      var parts = entry.split(',');

                      DateTime dateTime = DateTime.parse(parts[0]);
                      int highestHeartRate = int.parse(parts[1]);
                      String aiTitle = parts[2];
                      List<String> activities = parts.sublist(3);
                      // Add the parsed data to the historyData list
                      historyData.add([
                        dateTime,
                        highestHeartRate,
                        aiTitle,
                        activities,
                      ]);
                    }
            */
        }

        return const Homescreen();
      },
    );
  }
}
