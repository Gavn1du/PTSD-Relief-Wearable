import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';

class Recscreen extends StatefulWidget {
  const Recscreen({super.key});

  @override
  State<Recscreen> createState() => _RecscreenState();
}

class _RecscreenState extends State<Recscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: const Center(child: Text('Welcome to the Home Screen!')),
      bottomNavigationBar: Navbar(currentIndex: 2),
    );
  }
}
