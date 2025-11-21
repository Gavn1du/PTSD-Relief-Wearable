import 'package:ptsd_relief_app/screens/helpscreen.dart';
import 'package:ptsd_relief_app/screens/historyscreen.dart';
import 'package:ptsd_relief_app/screens/homescreen.dart';
import 'package:ptsd_relief_app/screens/recscreen.dart';
import 'package:ptsd_relief_app/screens/splashscreen.dart';
import 'package:ptsd_relief_app/screens/loginscreen.dart';
import 'package:ptsd_relief_app/screens/signupscreen.dart';
import 'package:ptsd_relief_app/screens/settingsscreen.dart';
import 'package:ptsd_relief_app/screens/medsources.dart';
import 'package:ptsd_relief_app/initial.dart';

var routes = {
  // '/': (context) => const Splashscreen(),
  '/': (context) => const Initial(),
  '/history': (context) => const Historyscreen(),
  '/help': (context) => const Helpscreen(),
  '/rec': (context) => const Recscreen(),
  '/home': (context) => const Homescreen(),
  '/login': (context) => const Loginscreen(),
  '/signup': (context) => const Signupscreen(),
  '/settings': (context) => const SettingsScreen(),
  '/medsources': (context) => const MedsourcesScreen(),
};
