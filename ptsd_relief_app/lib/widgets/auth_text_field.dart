import 'package:flutter/material.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? changed;
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboard,
    required this.obscureText,
    required this.validator,
    this.changed,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(),

        // enabled: ,
        // focusedBorder: ,
        // errorBorder: ,
        // focusedErrorBorder: ,
        hintText: widget.hint,
      ),
      keyboardType: widget.keyboard,
      obscureText: widget.obscureText,
      onChanged: widget.changed,
      validator: widget.validator,
    );
  }
}
