import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ptsd_relief_app/components/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ptsd_relief_app/services/data.dart';

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
  Map<String, dynamic> firebaseData = {};

  late final double nowMillis;
  late final double oneHourAgoMillis;
  late final List<FlSpot> timeSpots;

  int currentBPM = 0;
  List<BPMData> sortedBPMData = [];

  List<Color> gradientColors = [
    AppColors.contentColorCyan,
    AppColors.contentColorBlue,
  ];

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    Widget text;
    DateTime now = DateTime.now();
    DateTime fifteenMinutesAgo = now.subtract(const Duration(minutes: 15));
    String formattedTime = DateFormat('HH:mm').format(fifteenMinutesAgo);
    DateTime thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
    String formattedTime30 = DateFormat('HH:mm').format(thirtyMinutesAgo);
    DateTime fortyFiveMinutesAgo = now.subtract(const Duration(minutes: 45));
    String formattedTime45 = DateFormat('HH:mm').format(fortyFiveMinutesAgo);
    DateTime oneHourAgo = now.subtract(const Duration(hours: 1));
    String formattedTime60 = DateFormat('HH:mm').format(oneHourAgo);
    switch (value.toInt()) {
      case 0:
        text = Text(formattedTime60, style: style);
        break;
      case 15:
        text = Text(formattedTime45, style: style);
        break;
      case 30:
        text = Text(formattedTime30, style: style);
        break;
      case 45:
        text = Text(formattedTime, style: style);
        break;
      case 60:
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

  LineChartData mainData() {
    // final now = DateTime.now();
    // final oneHourAgo = now.subtract(const Duration(hours: 1));

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
      maxX: 60,
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
    Data.getFirebaseData("data").then((data) {
      setState(() {
        if (data != null) firebaseData = data;
      });
    });

    final now = DateTime.now();
    nowMillis = now.millisecondsSinceEpoch.toDouble();
    oneHourAgoMillis =
        now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch
            .toDouble();

    timeSpots = [
      FlSpot(oneHourAgoMillis, 3),
      FlSpot(oneHourAgoMillis + (nowMillis - oneHourAgoMillis) * 0.25, 2),
      FlSpot(oneHourAgoMillis + (nowMillis - oneHourAgoMillis) * 0.5, 5),
      FlSpot(oneHourAgoMillis + (nowMillis - oneHourAgoMillis) * 0.75, 3.1),
      FlSpot(nowMillis, 4),
    ];

    // Fetch the BPM data from shared preferences
    // example data format: ["2023-10-01T12:00:00.000Z,67", "2023-10-01T12:05:00.000Z,70"]
    SharedPreferences.getInstance().then((prefs) {
      List<String>? bpmDataStrings = prefs.getStringList('bpmData');
      if (bpmDataStrings != null) {
        sortedBPMData =
            bpmDataStrings.map((data) {
              final parts = data.split(',');
              final time = DateTime.parse(parts[0]);
              final bpm = int.parse(parts[1]);
              return BPMData(time, bpm);
            }).toList();

        sortedBPMData.sort((a, b) => a.time.compareTo(b.time));
      }
    });

    // add example data for debug
    sortedBPMData.addAll([
      BPMData(DateTime.now().subtract(Duration(minutes: 5)), 67),
      BPMData(DateTime.now().subtract(Duration(minutes: 10)), 70),
      BPMData(DateTime.now().subtract(Duration(minutes: 15)), 65),
    ]);

    // create the timespots for the chart
    timeSpots.clear();
    for (var bpmData in sortedBPMData) {
      int minutesAgo = DateTime.now().difference(bpmData.time).inMinutes;
      double xValue = (60 - minutesAgo).toDouble();
      if (xValue < 0 || xValue > 60) continue; // Skip
      timeSpots.add(FlSpot(xValue, bpmData.bpm.toDouble()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home Screen'),
      // ),
      body: SafeArea(
        child: Center(
          child: Column(
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
                        Text(
                          currentBPM.toString(),
                          style: TextStyle(fontSize: 20),
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
                    child: LineChart(mainData()),
                  ),
                ),
              ),
              SizedBox(
                height: SizeConfig.horizontal! * 80,
                width: SizeConfig.horizontal! * 80,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(13.0),
                    child:
                        (sortedBPMData.isNotEmpty)
                            ? ListView.builder(
                              itemCount: sortedBPMData.length,
                              itemBuilder: (context, index) {
                                final bpmData = sortedBPMData[index];
                                return RecommendationCard(
                                  bpm: bpmData.bpm,
                                  time: bpmData.time,
                                );
                              },
                            )
                            : Center(
                              child: Text(
                                'No BPM history available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
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
      bottomNavigationBar: Navbar(currentIndex: 0),
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
