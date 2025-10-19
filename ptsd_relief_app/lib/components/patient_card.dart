import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/size_config.dart';

class PatientCard extends StatefulWidget {
  const PatientCard({
    super.key,
    required this.name,
    required this.location,
    required this.heartRate,
    this.onTap,
  });

  final String name;
  final String location;
  final int heartRate;
  final VoidCallback? onTap;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.name, style: TextStyle(fontSize: 20)),
                  Text(widget.location, style: TextStyle(fontSize: 20)),
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
