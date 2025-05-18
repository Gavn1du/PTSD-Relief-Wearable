import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/size_config.dart';

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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: SizeConfig.horizontal! * 90,
                  height: SizeConfig.vertical! * 30,
                  child: Card(
                    color: Color.fromARGB(255, 103, 92, 91),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Common Tips",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Card(
                                  color: const Color.fromARGB(
                                    255,
                                    242,
                                    247,
                                    242,
                                  ),
                                  child: const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: SizeConfig.horizontal! * 90,
                  height: SizeConfig.vertical! * 50,
                  child: Card(
                    color: const Color.fromARGB(255, 103, 92, 91),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Saved Chats",
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              Card(
                                color: const Color.fromARGB(255, 242, 247, 242),
                                child: InkWell(
                                  onDoubleTap: () {
                                    // This card will hold a value, we then build a route to the chat screen
                                    // we give the value as an optional parameter
                                    // If the Chat screen is given this parameter, it will also scroll to that spot
                                    // in addition to the default behaviors.
                                  },
                                  child: SizedBox(
                                    width: SizeConfig.horizontal! * 90,
                                    height: SizeConfig.vertical! * 20,
                                    child: const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 2),
    );
  }
}
