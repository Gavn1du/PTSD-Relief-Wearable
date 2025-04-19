import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/screens/homescreen.dart';
import 'package:ptsd_relief_app/screens/historyscreen.dart';
import 'package:ptsd_relief_app/screens/recscreen.dart';
import 'package:ptsd_relief_app/screens/helpscreen.dart';

// ignore: must_be_immutable
class Navbar extends StatefulWidget {
  Navbar({super.key, required this.currentIndex});

  int currentIndex;

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  Route _noAnimationRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: widget.currentIndex,
      onDestinationSelected: (int index) {
        setState(() {
          if (index != widget.currentIndex) {
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  _noAnimationRoute(const Homescreen()),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  _noAnimationRoute(const Historyscreen()),
                );
                break;
              case 2:
                Navigator.pushReplacement(
                  context,
                  _noAnimationRoute(const Recscreen()),
                );
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  _noAnimationRoute(const Helpscreen()),
                );
                break;
            }
          }
        });
      },
      indicatorColor: Colors.amber,
      destinations: const <Widget>[
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.lightbulb), label: 'Tips'),
        NavigationDestination(icon: Icon(Icons.mode_comment), label: 'Chat'),
      ],
    );
  }
}
