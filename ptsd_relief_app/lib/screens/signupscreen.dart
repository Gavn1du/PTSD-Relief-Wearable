import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/auth.dart';

class Signupscreen extends StatefulWidget {
  const Signupscreen({super.key});

  @override
  State<Signupscreen> createState() => _SignupscreenState();
}

class _SignupscreenState extends State<Signupscreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  int selectedRoleIndex = -1;

  bool validInfo() {
    // valid role
    if (selectedRoleIndex == -1) {
      return false;
    }

    // valid email
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailController.text)) {
      return false;
    }

    // password length >= 6 and includes a special character
    if (passwordController.text.length < 6 ||
        !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(passwordController.text)) {
      return false;
    }

    // password == confirm password
    if (passwordController.text != confirmPasswordController.text) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
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
                  controller: emailController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Password',
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Confirm Password',
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedRoleIndex == 0
                                  ? const Color.fromARGB(255, 122, 182, 231)
                                  : const Color.fromARGB(255, 241, 241, 241),
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRoleIndex = 0;
                          });
                        },
                        child: Text("Nurse"),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedRoleIndex == 1
                                  ? const Color.fromARGB(255, 122, 182, 231)
                                  : const Color.fromARGB(255, 241, 241, 241),
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRoleIndex = 1;
                          });
                        },
                        child: Text("Patient"),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              selectedRoleIndex == 2
                                  ? const Color.fromARGB(255, 122, 182, 231)
                                  : const Color.fromARGB(255, 241, 241, 241),
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRoleIndex = 2;
                          });
                        },
                        child: Text("Individual"),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed:
                      validInfo()
                          ? () {
                            // Navigator.pushNamed(context, '/home');
                            Auth()
                                .signUp(
                                  emailController.text,
                                  passwordController.text,
                                  selectedRoleIndex,
                                )
                                .then((user) {
                                  if (user != null) {
                                    Navigator.pushNamed(context, '/home');
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Sign Up Failed")),
                                    );
                                  }
                                });
                          }
                          : null,
                  child: Text("Create Account"),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Back to Login"),
            ),
          ],
        ),
      ),
    );
  }
}
