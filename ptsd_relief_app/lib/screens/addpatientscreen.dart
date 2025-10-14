import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/theme.dart';

class Addpatientscreen extends StatefulWidget {
  const Addpatientscreen({super.key});

  @override
  State<Addpatientscreen> createState() => _AddpatientscreenState();
}

class _AddpatientscreenState extends State<Addpatientscreen> {
  String _query = "";
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.watch<ThemeController>().value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                style: TextStyle(color: theme.textColor),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Patient Name',
                ),
                onChanged: _onQueryChanged,
              ),
            ),

            // 1) Stream the nurse's current patients so we can exclude them live
            Expanded(
              child: StreamBuilder<Set<String>>(
                stream: Data.nursePatientIdsStream(),
                builder: (context, nurseSnap) {
                  final excluded = nurseSnap.data ?? <String>{};

                  // 2) Query userDirectory and exclude already-added UIDs
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Data.searchDirectoryExcluding(_query, excluded),
                    builder: (context, dirSnap) {
                      if (dirSnap.connectionState == ConnectionState.waiting &&
                          (nurseSnap.connectionState ==
                              ConnectionState.waiting)) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final list =
                          dirSnap.data ?? const <Map<String, dynamic>>[];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'No patients found',
                            style: TextStyle(color: theme.textColor),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final patient = list[index];
                          final display =
                              (patient['displayName'] ?? patient['uid'])
                                  .toString();
                          final uid = patient['uid'].toString();

                          return ListTile(
                            title: Text(
                              display,
                              style: TextStyle(color: theme.textColor),
                            ),
                            subtitle: Text(
                              'ID: $uid',
                              style: TextStyle(color: theme.textColor),
                            ),
                            trailing: IconButton(
                              color: theme.themeIconColor,
                              icon: const Icon(Icons.add),
                              onPressed: () async {
                                final ok = await Data.addPatient(uid);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Patient added successfully'
                                          : 'Failed to add patient',
                                    ),
                                  ),
                                );
                                // No manual removal—once RTDB updates, the stream excludes it.
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(currentIndex: 1, accountType: 'nurse'),
    );
  }
}
