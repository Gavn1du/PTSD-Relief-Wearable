import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ptsd_relief_app/screens/loginscreen.dart';
import 'package:ptsd_relief_app/screens/homescreen.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/services/llm.dart';

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

          // Check for BPM anomalies
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
          if (userData.containsKey("BPM") && userData["BPM"] > 100) {
            DateTime now = DateTime.now();
            int highestHeartRate = userData["BPM"];
            String aiTitle = "";

            // Generate AI suggested activities based on BPM
            String prompt =
                "Generate a comma separated list of 1-10 suggested activites for someone with a BPM of $highestHeartRate. The activities should be suitable for someone with PTSD.";
            Llm().sendMessage(prompt).then((response) {
              // print for now
              print("AI suggested activities: $response");
              List<String> activities = response["message"]["content"].split(
                ',',
              );
              // Keep only the first 10 activities
              activities = activities.take(10).toList();
              String activitiesString = activities.join(',');

              String entry =
                  "$now,$highestHeartRate,$aiTitle,$activitiesString";
              Data.saveAnomaly(entry);
            });

            // Data.saveAnomaly("");
          }
        }

        return const Homescreen();
      },
    );
  }
}
