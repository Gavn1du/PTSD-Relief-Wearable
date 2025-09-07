import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/components/navbar.dart';

class Addpatientscreen extends StatefulWidget {
  const Addpatientscreen({super.key});

  @override
  State<Addpatientscreen> createState() => _AddpatientscreenState();
}

class _AddpatientscreenState extends State<Addpatientscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Patient Name',
                ),
                onChanged: (value) {
                  // Handle search logic here
                  Data.searchPatientsByName(value).then((results) {
                    // Update the UI with search results
                    print(results);
                  });
                },
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text('Jack Smith'),
                    subtitle: Text('ID: 12345'),
                    trailing: Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 1, accountType: 'nurse'),
    );
  }
}
