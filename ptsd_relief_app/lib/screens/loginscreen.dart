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
            Container(),
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
