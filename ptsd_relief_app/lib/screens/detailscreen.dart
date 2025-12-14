import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/size_config.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.timestamp,
    required this.highestHeartrate,
    required this.aiTitle,
    required this.activities,
  });

  final DateTime timestamp;
  final int highestHeartrate;
  final String aiTitle;
  final List<String> activities;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String formatDateTime(DateTime dateTime) {
    // Format the date and time as needed
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(formatDateTime(widget.timestamp)),
            // SizedBox(width: 10),
            // Text("10:00 AM"),
            SizedBox(width: SizeConfig.horizontal! * 16),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: SizeConfig.horizontal! * 90,
              height: SizeConfig.vertical! * 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(255, 103, 92, 91),
              ),
              child: Column(
                children: [
                  SizedBox(height: SizeConfig.vertical! * 2),
                  Text(
                    "Highest Heartrate: ${widget.highestHeartrate} bpm",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  // Text(
                  //   widget.aiTitle,
                  //   style: TextStyle(fontSize: 20, color: Colors.white),
                  // ),
                  SizedBox(height: SizeConfig.vertical! * 1),
                  Text(
                    "Suggested Activities",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.activities.length,
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            SizedBox(
                              width: SizeConfig.horizontal! * 10,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  8.5,
                                  0,
                                  0,
                                  0,
                                ),
                                child: Text(
                                  "${index + 1}. ",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: SizeConfig.horizontal! * 77,
                              height: SizeConfig.vertical! * 8,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text(
                                      widget.activities[index],
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
