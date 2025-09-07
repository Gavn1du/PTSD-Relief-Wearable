import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/size_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> firebaseData = {};
  int account_type = 0; // 0 = none, 1 = nurse,

  TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // get the current firebase data
    var uid = Auth().user?.uid;
    Data.getFirebaseData("users/$uid").then((data) {
      setState(() {
        if (data != null) firebaseData = data;

        print("Firebase Data: $firebaseData");

        if (firebaseData.containsKey('type')) {
          if (firebaseData['type'] == 'nurse') {
            account_type = 1;
          } else if (firebaseData['type'] == 'patient') {
            account_type = 2;
          } else {
            account_type = 0;
          }
        }

        if (firebaseData.containsKey('name')) {
          _nameController.text = firebaseData['name'];
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (account_type != 1)
                ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Set Name Here',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                )
                : Container(),
            (account_type != 1)
                ? ElevatedButton(
                  onPressed: () {
                    // Implement change name functionality here
                    print("Changing name to ${_nameController.text}");
                    Data().setPatientName(_nameController.text).then((value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Name changed successfully!')),
                      );
                    });
                  },
                  child: Text('Change Name'),
                )
                : Container(),
            SizedBox(height: SizeConfig.vertical! * 40),
            ElevatedButton(
              onPressed: () {
                // Implement logout functionality here
                Auth().signOut().then((_) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                });
              },
              child: Text('Logout'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(
        currentIndex: account_type == 1 ? 2 : 4,
        accountType: account_type == 1 ? 'nurse' : 'patient',
      ),
    );
  }
}
