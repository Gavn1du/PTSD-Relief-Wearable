import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/theme.dart';
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
  int account_type = -1; // 0 = none, 1 = nurse,

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
    final AppTheme theme = context.watch<ThemeController>().value;
    return Scaffold(
      body: Center(
        child:
            (account_type > -1)
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    (account_type != 1)
                        ? Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: TextField(
                            style: TextStyle(color: theme.textColor),
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
                            Data().setPatientName(_nameController.text).then((
                              value,
                            ) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Name changed successfully!'),
                                ),
                              );
                            });
                          },
                          child: Text('Change Name'),
                        )
                        : Container(),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ThemeController>().toggle();
                      },
                      child: Text("Toggle Theme"),
                    ),
                    SizedBox(height: SizeConfig.vertical! * 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          // Implement logout functionality here
                          Auth().signOut().then((_) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (_) => false,
                            );
                          });
                        },
                        child: Text('Logout'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _confirmAndDeleteAccount,
                        child: const Text('Delete Account'),
                      ),
                    ),
                  ],
                )
                : Container(),
      ),
      bottomNavigationBar: Navbar(
        currentIndex:
            (account_type == -1)
                ? 0
                : account_type == 1
                ? 2
                : 4,
        accountType:
            (account_type == -1)
                ? ""
                : account_type == 1
                ? 'nurse'
                : 'patient',
      ),
    );
  }

  Future<void> _confirmAndDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
              'This will permanently delete your account and associated data. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await Auth().deleteAccount();
      await Auth().signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'requires-recent-login') {
        message = 'Please log in again to delete your account.';
      } else {
        message = 'Failed to delete account: ${e.message ?? e.code}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account.')),
      );
    }
  }
}
