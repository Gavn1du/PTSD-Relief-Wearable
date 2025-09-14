import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/components/navbar.dart';

class Addpatientscreen extends StatefulWidget {
  const Addpatientscreen({super.key});

  @override
  State<Addpatientscreen> createState() => _AddpatientscreenState();
}

class _AddpatientscreenState extends State<Addpatientscreen> {
  List<Map<String, dynamic>> searchResults = [];

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
                  // TODO: TEST THIS
                  // Handle search logic here
                  Data.searchPatientsByName(value).then((results) {
                    // Update the UI with search results
                    print(results);
                    Data.getFirebaseDataFromSharedPref('data').then((data) {
                      List<String> existingPatientIds = data?['patients'];
                      results.removeWhere(
                        (patient) =>
                            existingPatientIds.contains(patient['uid']),
                      );

                      setState(() {
                        searchResults = results;
                      });
                    });
                  });
                },
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final patient = searchResults[index];
                  return ListTile(
                    title: Text(patient['displayName'] ?? patient['uid']),
                    subtitle: Text('ID: ${patient['uid']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        // Handle add patient logic here
                        print('Add patient: ${patient['uid']}');
                        Data.addPatient(patient['uid']).then((success) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Patient added successfully'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add patient')),
                            );
                          }
                        });
                      },
                    ),
                  );
                },
                // children: [
                //   ListTile(
                //     title: Text('Jack Smith'),
                //     subtitle: Text('ID: 12345'),
                //     trailing: Icon(Icons.add),
                //   ),
                // ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 1, accountType: 'nurse'),
    );
  }
}
