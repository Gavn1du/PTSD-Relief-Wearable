import 'package:flutter/material.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:ptsd_relief_app/size_config.dart';

class PatientCard extends StatefulWidget {
  const PatientCard({
    super.key,
    required this.name,
    this.location,
    required this.heartRate,
    this.onTap,
    required this.status,
  });

  final String name;
  final String? location;
  final int heartRate;
  final VoidCallback? onTap;
  final String? status;

  @override
  State<PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<PatientCard> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SizeConfig.horizontal! * 90,
      height: SizeConfig.vertical! * 10,
      child: InkWell(
        onTap: widget.onTap,
        child: Card(
          color:
              widget.status != "healthy"
                  ? Colors.red
                  : const Color.fromARGB(255, 228, 229, 229),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.name, style: TextStyle(fontSize: 20)),
                  Text(
                    (widget.location != null)
                        ? "${widget.location}"
                        : "No location provided",
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    "${widget.heartRate} BPM",
                    style: TextStyle(fontSize: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.favorite, color: Colors.red, size: 35),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
