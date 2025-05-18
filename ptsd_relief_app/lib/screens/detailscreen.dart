import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/size_config.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("01/01/2020"),
            SizedBox(width: 10),
            Text("10:00 AM"),
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
                    "Highest Heartrate: 120 bpm",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  Text(
                    "Panic Attacks", // This will eventually be a title suggest by the AI
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: SizeConfig.vertical! * 1),
                  Text(
                    "Suggested Activities",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                              child: Text(
                                "1. ",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: SizeConfig.horizontal! * 80,
                              height: SizeConfig.vertical! * 8,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text(
                                      "Meditation for 20 minutes",
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
                        ),
                      ],
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
