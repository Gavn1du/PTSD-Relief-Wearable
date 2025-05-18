import 'package:ptsd_relief_app/screens/helpscreen.dart';
import 'package:ptsd_relief_app/screens/historyscreen.dart';
import 'package:ptsd_relief_app/screens/homescreen.dart';
import 'package:ptsd_relief_app/screens/recscreen.dart';
import 'package:ptsd_relief_app/screens/splashscreen.dart';

var routes = {
  // '/': (context) => const Splashscreen(),
  '/': (context) => const Homescreen(),
  '/history': (context) => const Historyscreen(),
  '/help': (context) => const Helpscreen(),
  '/rec': (context) => const Recscreen(),
  '/home': (context) => const Homescreen(),
};
