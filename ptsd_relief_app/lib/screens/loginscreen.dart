import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/theme.dart';
import 'package:ptsd_relief_app/services/auth.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.watch<ThemeController>().value;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: EdgeInsets.only(top: 150),
              child: Image.asset(
                'assets/app icon.jpg',
                height: 150,
                width: 150,
              ),
            ),
            Column(
              children: [
                TextField(
                  style: TextStyle(color: theme.textColor),
                  controller: emailController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 10),
                TextField(
                  style: TextStyle(color: theme.textColor),
                  controller: passwordController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Password',
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Auth()
                        .signIn(emailController.text, passwordController.text)
                        .then((user) {
                          if (user == null) {
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Login failed. Please try again.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pushNamed(context, '/home');
                        });
                  },
                  child: Text("Login"),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Disclaimer: This app is for educational and general wellness purposes only. It is not a medical device and is not a substitute for professional medical advice, diagnosis, or treatment. If you have health concerns, consult a qualified healthcare professional. If you are in crisis or may harm yourself, contact local emergency services immediately.",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text("No Account? Sign Up", style: theme.signupText),
            ),
          ],
        ),
      ),
    );
  }
}
