import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/theme.dart';

class ButtonFormat extends StatefulWidget {
  final bool isSelected;
  final String title;
  final VoidCallback onPressed;

  const ButtonFormat({
    super.key,
    required this.isSelected,
    required this.title,
    required this.onPressed,
  });

  @override
  State<ButtonFormat> createState() => _ButtonFormatState();
}

class _ButtonFormatState extends State<ButtonFormat> {
  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.watch<ThemeController>().value;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 40) * 0.33,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              widget.isSelected
                  ? theme.activeButton
                  : const Color.fromARGB(255, 241, 241, 241),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: widget.onPressed,
        child: Text(
          widget.title,
          style: TextStyle(
            color:
                widget.isSelected
                    ? const Color.fromARGB(255, 252, 252, 252)
                    : const Color.fromARGB(255, 166, 28, 28),
          ),
        ),
      ),
    );
  }
}
