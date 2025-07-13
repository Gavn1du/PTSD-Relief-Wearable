import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/screens/detailscreen.dart';
import 'package:ptsd_relief_app/services/data.dart';

class Historyscreen extends StatefulWidget {
  const Historyscreen({super.key});

  @override
  State<Historyscreen> createState() => _HistoryscreenState();
}

class _HistoryscreenState extends State<Historyscreen> {
  List<List<dynamic>> historyData = [];

  @override
  void initState() {
    super.initState();
    // Attempt to load the history data from the database
    // data format example: [] <-- datetime, highest heartrate, AI generated title, activities
    Data.getStringListData('history')
        .then((value) {
          if (value == null) {
            // If no history data is found, you might want to show a message or handle it accordingly
            print('No history data found.');

            // for now, just add a test entry
            historyData.add([
              DateTime.now(),
              120, // Example highest heart rate
              'AI Generated Title', // Example AI title
              ['Activity 1', 'Activity 2'], // Example activities
            ]);

            setState(() {
              // Trigger a rebuild to show the test entry
            });
          } else {
            // Process the history data as needed
            print('History data loaded: $value');
            // parse through each entry
            for (String entry in value) {
              var parts = entry.split(',');

              DateTime dateTime = DateTime.parse(parts[0]);
              int highestHeartRate = int.parse(parts[1]);
              String aiTitle = parts[2];
              List<String> activities = parts.sublist(3);
              // Add the parsed data to the historyData list
              historyData.add([
                dateTime,
                highestHeartRate,
                aiTitle,
                activities,
              ]);
            }

            setState(() {});
          }
        })
        .catchError((error) {
          // Handle any errors that occur while fetching the data
          print('Error loading history data: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    print('Building Historyscreen with ${historyData.length} entries');
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: SafeArea(
        child: Center(
          child: ListView.builder(
            // shrinkWrap: true,
            itemCount: historyData.length,
            itemBuilder: (context, index) {
              return HistoryCard(
                timestamp: historyData[index][0],
                highestHeartRate: historyData[index][1],
                aiTitle: historyData[index][2],
                activities: List<String>.from(historyData[index][3]),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 1),
    );
  }
}

class HistoryCard extends StatefulWidget {
  const HistoryCard({
    super.key,
    required this.timestamp,
    required this.highestHeartRate,
    required this.aiTitle,
    required this.activities,
  });

  final DateTime timestamp;
  final int highestHeartRate;
  final String aiTitle;
  final List<String> activities;

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  String formatDateTime(DateTime dateTime) {
    // Format the date and time as needed
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              formatDateTime(DateTime.now()),
              style: TextStyle(fontSize: 20),
            ),
            IconButton(
              icon: Icon(Icons.more_horiz),
              onPressed: () {
                HapticFeedback.lightImpact();
                // Head over to the detail screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => DetailScreen(
                          timestamp: widget.timestamp,
                          highestHeartrate: widget.highestHeartRate,
                          aiTitle: widget.aiTitle,
                          activities: widget.activities,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
