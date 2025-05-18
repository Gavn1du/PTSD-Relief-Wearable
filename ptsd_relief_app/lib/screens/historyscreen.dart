import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/screens/detailscreen.dart';

class Historyscreen extends StatefulWidget {
  const Historyscreen({super.key});

  @override
  State<Historyscreen> createState() => _HistoryscreenState();
}

class _HistoryscreenState extends State<Historyscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: SafeArea(
        child: Center(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 10,
            itemBuilder: (context, index) {
              return HistoryCard();
            },
          ),
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 1),
    );
  }
}

class HistoryCard extends StatefulWidget {
  const HistoryCard({super.key});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('01/01/2025 3:27 PM', style: TextStyle(fontSize: 20)),
            IconButton(
              icon: Icon(Icons.more_horiz),
              onPressed: () {
                HapticFeedback.lightImpact();
                // Head over to the detail screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DetailScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
