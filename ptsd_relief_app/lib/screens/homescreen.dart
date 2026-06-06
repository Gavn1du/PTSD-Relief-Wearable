import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/services/auth.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ptsd_relief_app/components/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ptsd_relief_app/services/data.dart';
import 'package:ptsd_relief_app/components/patient_card.dart';
import 'package:ptsd_relief_app/screens/patientdetail.dart';
import 'package:ptsd_relief_app/services/bluetooth_connection.dart';

class BPMData {
  final DateTime time;
  final int bpm;

  BPMData(this.time, this.bpm);
}

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  static const Duration _chartWindow = Duration(minutes: 5);

  Map<String, dynamic> firebaseData = {};

  int account_type = -1; // 0 = individual account, 1 = nurse, 2 = patient

  int currentBPM = 0;
  List<BPMData> sortedBPMData = [];
  BluetoothConnectionService? _bluetooth;
  DateTime? _lastRecordedBluetoothUpdate;
  String? selectedCheckIn;
  DateTime? lastCheckInTime;

  final List<_CheckInOption> checkInOptions = const [
    _CheckInOption(label: 'Calm', emoji: '🙂'),
    _CheckInOption(label: 'Okay', emoji: '😐'),
    _CheckInOption(label: 'Anxious', emoji: '😟'),
    _CheckInOption(label: 'Overwhelmed', emoji: '😣'),
  ];

  List<Color> gradientColors = [
    AppColors.contentColorCyan,
    AppColors.contentColorBlue,
  ];

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    Widget text;
    DateTime now = DateTime.now();
    switch (value.toInt()) {
      case 0:
        text = Text(
          DateFormat('HH:mm').format(now.subtract(const Duration(minutes: 5))),
          style: style,
        );
        break;
      case 1:
        text = Text(
          DateFormat('HH:mm').format(now.subtract(const Duration(minutes: 4))),
          style: style,
        );
        break;
      case 2:
        text = Text(
          DateFormat('HH:mm').format(now.subtract(const Duration(minutes: 3))),
          style: style,
        );
        break;
      case 3:
        text = Text(
          DateFormat('HH:mm').format(now.subtract(const Duration(minutes: 2))),
          style: style,
        );
        break;
      case 4:
        text = Text(
          DateFormat('HH:mm').format(now.subtract(const Duration(minutes: 1))),
          style: style,
        );
        break;
      case 5:
        text = const Text('Now', style: style);
        break;
      default:
        text = const Text('', style: style);
        break;
    }

    return SideTitleWidget(meta: meta, child: text);

    // final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    // final label = DateFormat('HH:mm').format(date);
    // return SideTitleWidget(meta: meta, child: Text(label, style: style));
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);
    String text;
    switch (value.toInt()) {
      case 60:
        text = '60';
        break;
      case 90:
        text = '90';
        break;
      case 120:
        text = '120';
        break;
      default:
        return Container();
    }

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  LineChartData mainData(List<FlSpot> timeSpots) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: AppColors.mainGridLineColor,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: AppColors.mainGridLineColor,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 0,
      maxX: 5,
      minY: 30,
      maxY: 150,
      lineBarsData: [
        LineChartBarData(
          spots: timeSpots,
          isCurved: true,
          gradient: LinearGradient(colors: gradientColors),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors:
                  gradientColors
                      .map((color) => color.withValues(alpha: 0.3))
                      .toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    // get the current firebase data
    var uid = Auth().user?.uid;
    Data.getFirebaseData("users/$uid").then((data) {
      setState(() {
        if (data != null) firebaseData = data;

        if (firebaseData.containsKey('type')) {
          if (firebaseData['type'] == 'nurse') {
            account_type = 1;
          } else if (firebaseData['type'] == 'patient') {
            account_type = 2;
          } else {
            account_type = 0;
          }
        }

        if (firebaseData.containsKey('BPM')) {
          currentBPM = int.tryParse(firebaseData['BPM'].toString()) ?? 0;
        }
      });
    });

    // Fetch the BPM data from shared preferences
    // example data format: ["2023-10-01T12:00:00.000Z,67", "2023-10-01T12:05:00.000Z,70"]
    SharedPreferences.getInstance().then((prefs) {
      List<String>? bpmDataStrings = prefs.getStringList('bpmData');
      if (bpmDataStrings != null) {
        final cutoff = DateTime.now().subtract(_chartWindow);
        final savedBpmData =
            bpmDataStrings
                .map(_parseBpmData)
                .whereType<BPMData>()
                .where((data) => !data.time.isBefore(cutoff))
                .toList()
              ..sort((a, b) => a.time.compareTo(b.time));

        final combinedByTime = <int, BPMData>{
          for (final data in savedBpmData)
            data.time.microsecondsSinceEpoch: data,
          for (final data in sortedBPMData.where(
            (data) => !data.time.isBefore(cutoff),
          ))
            data.time.microsecondsSinceEpoch: data,
        };
        sortedBPMData =
            combinedByTime.values.toList()
              ..sort((a, b) => a.time.compareTo(b.time));
      }

      final savedCheckIn = prefs.getString('latestCheckIn');
      final savedCheckInTime = prefs.getString('latestCheckInTime');
      if (mounted) {
        setState(() {
          selectedCheckIn = savedCheckIn;
          lastCheckInTime =
              savedCheckInTime == null
                  ? null
                  : DateTime.parse(savedCheckInTime);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bluetooth = context.read<BluetoothConnectionService>();
    if (_bluetooth != bluetooth) {
      _bluetooth?.removeListener(_recordLatestBluetoothBpm);
      _bluetooth = bluetooth;
      _bluetooth!.addListener(_recordLatestBluetoothBpm);
      _recordLatestBluetoothBpm();
    }
  }

  BPMData? _parseBpmData(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;

    final time = DateTime.tryParse(parts[0]);
    final bpm = int.tryParse(parts[1]);
    if (time == null || bpm == null) return null;
    return BPMData(time, bpm);
  }

  void _recordLatestBluetoothBpm() {
    final bpm = _bluetooth?.liveBpm;
    final receivedAt = _bluetooth?.liveBpmUpdatedAt;
    if (bpm == null ||
        receivedAt == null ||
        receivedAt == _lastRecordedBluetoothUpdate) {
      return;
    }

    _lastRecordedBluetoothUpdate = receivedAt;
    final cutoff = receivedAt.subtract(_chartWindow);
    final updatedData = [
      ...sortedBPMData.where((data) => !data.time.isBefore(cutoff)),
      BPMData(receivedAt, bpm),
    ]..sort((a, b) => a.time.compareTo(b.time));

    if (mounted) {
      setState(() {
        sortedBPMData = updatedData;
      });
    }
    _saveBpmData(updatedData);
  }

  Future<void> _saveBpmData(List<BPMData> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bpmData',
      data
          .map((sample) => '${sample.time.toIso8601String()},${sample.bpm}')
          .toList(),
    );
  }

  List<FlSpot> _chartSpots(int displayedBpm) {
    final now = DateTime.now();
    final cutoff = now.subtract(_chartWindow);
    final spots =
        sortedBPMData.where((data) => !data.time.isBefore(cutoff)).map((data) {
          final elapsedMinutes =
              data.time.difference(cutoff).inMilliseconds /
              Duration.millisecondsPerMinute;
          return FlSpot(
            elapsedMinutes.clamp(0, 5).toDouble(),
            data.bpm.toDouble(),
          );
        }).toList();

    if (displayedBpm > 0) {
      spots.add(FlSpot(5, displayedBpm.toDouble()));
    }
    return spots;
  }

  @override
  void dispose() {
    _bluetooth?.removeListener(_recordLatestBluetoothBpm);
    super.dispose();
  }

  Future<void> _saveCheckIn(String label) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await prefs.setString('latestCheckIn', label);
    await prefs.setString('latestCheckInTime', now.toIso8601String());

    if (!mounted) return;
    setState(() {
      selectedCheckIn = label;
      lastCheckInTime = now;
    });
  }

  String get _checkInSubtitle {
    if (selectedCheckIn == null || lastCheckInTime == null) {
      return 'A quick check-in can help connect how you feel with what your body is doing.';
    }

    final formattedTime = DateFormat('HH:mm').format(lastCheckInTime!);
    return 'Last check-in: $selectedCheckIn at $formattedTime';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child:
                (account_type == -1)
                    ? Center(child: CircularProgressIndicator())
                    : (account_type == 1)
                    ? StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Data.nursePatientsDetailsStream(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        print("SNAP DATA: ${snap.data}");
                        final patients = snap.data ?? const [];
                        print("PATIENTS DATA: $patients");

                        if (patients.isEmpty) {
                          return ListView(
                            children: [
                              Text(
                                "No patients yet. Add them from Add Patient tab.",
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: patients.length,
                          itemBuilder: (context, index) {
                            final p = patients[index];
                            return PatientCard(
                              status: (p['status' ?? ""]).toString(),
                              name: (p['name'] ?? "").toString(),
                              location:
                                  (p['room'] ?? "No location recorded")
                                      .toString(),
                              heartRate: p['BPM'] ?? 0,
                              onTap: () {
                                // MAKE ACTUAL PAGE
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => Patientdetail(
                                          patient: {
                                            // name, bpm, bpm_data, location
                                            'uid': p['uid'] ?? '',
                                            'name': p['name'] ?? '',
                                            'bpm': p['BPM'] ?? 0,
                                            'bpm_data': p['bpm_data'] ?? [],
                                            'room': p['room'] ?? '',
                                          },
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    )
                    : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: SizeConfig.vertical! * 6,
                          width: SizeConfig.horizontal! * 80,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Consumer2<Data, BluetoothConnectionService>(
                                    builder: (context, data, bluetooth, child) {
                                      final displayedBpm =
                                          bluetooth.liveBpm ??
                                          int.tryParse(
                                            data.userData["BPM"].toString(),
                                          ) ??
                                          currentBPM;
                                      return Text(
                                        displayedBpm.toString(),
                                        style: TextStyle(fontSize: 20),
                                      );
                                    },
                                  ),
                                  Text('BPM'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: SizeConfig.horizontal! * 80,
                          width: SizeConfig.horizontal! * 80,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child:
                                  Consumer2<Data, BluetoothConnectionService>(
                                    builder: (context, data, bluetooth, child) {
                                      final displayedBpm =
                                          bluetooth.liveBpm ??
                                          int.tryParse(
                                            data.userData["BPM"].toString(),
                                          ) ??
                                          currentBPM;
                                      final spots = _chartSpots(displayedBpm);
                                      return LineChart(mainData(spots));
                                    },
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: SizeConfig.horizontal! * 80,
                          width: SizeConfig.horizontal! * 80,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: _CheckInCard(
                                subtitle: _checkInSubtitle,
                                selectedCheckIn: selectedCheckIn,
                                options: checkInOptions,
                                onSelected: _saveCheckIn,
                              ),
                            ),
                          ),
                        ),
                        // SizedBox(
                        //   height: SizeConfig.vertical! * 6,
                        //   width: SizeConfig.horizontal! * 80,
                        //   child: Card(
                        //     child: Padding(
                        //       padding: const EdgeInsets.all(8.0),
                        //       child: Row(
                        //         children: [
                        //           Text('67', style: TextStyle(fontSize: 20)),
                        //           Text('BPM'),
                        //         ],
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
          ),
        ),
      ),
      bottomNavigationBar: Navbar(
        currentIndex: 0,
        accountType:
            (account_type == -1)
                ? ""
                : (account_type == 1)
                ? 'nurse'
                : 'patient',
      ),
    );
  }
}

class _CheckInOption {
  const _CheckInOption({required this.label, required this.emoji});

  final String label;
  final String emoji;
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.subtitle,
    required this.selectedCheckIn,
    required this.options,
    required this.onSelected,
  });

  final String subtitle;
  final String? selectedCheckIn;
  final List<_CheckInOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling right now?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                options.map((option) {
                  final isSelected = option.label == selectedCheckIn;
                  return ChoiceChip(
                    label: Text('${option.emoji}  ${option.label}'),
                    selected: isSelected,
                    onSelected: (_) => onSelected(option.label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isSelected ? Colors.black : Colors.black87,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          if (selectedCheckIn != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.contentColorBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                selectedCheckIn == 'Calm' || selectedCheckIn == 'Okay'
                    ? 'Thanks for checking in. Keeping these small moments gives your trends more meaning over time.'
                    : 'Thanks for checking in. If you want support, the Tips or Chat tabs are one tap away.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class RecommendationCard extends StatefulWidget {
  const RecommendationCard({super.key, required this.bpm, required this.time});

  final int bpm;
  final DateTime time;

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(widget.bpm.toString(), style: TextStyle(fontSize: 20)),
                Text('BPM'),
              ],
            ),
            Text(
              '${widget.time.hour}:${widget.time.minute.toString().padLeft(2, '0')} (${DateFormat('dd/MM/yyyy').format(widget.time)})',
            ),
          ],
        ),
      ),
    );
  }
}
