import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/theme.dart';
import 'package:ptsd_relief_app/routes.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:ptsd_relief_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeController(LightTheme()),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeController>().value;
    SizeConfig().init(context);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        scaffoldBackgroundColor: currentTheme.backgroundColor,
        // You can add other properties based on the AppTheme you have
      ),
      debugShowCheckedModeBanner: false,
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
      routes: routes,
    );
  }
}
