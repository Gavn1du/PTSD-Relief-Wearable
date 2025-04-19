import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';

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
      body: const Center(child: Text('Welcome to the Home Screen!')),
      bottomNavigationBar: Navbar(currentIndex: 1),
    );
  }
}
