import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/app_colors.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:intl/intl.dart';
import 'package:ptsd_relief_app/services/data.dart';

class Patientdetail extends StatefulWidget {
  const Patientdetail({super.key, required this.patient});

  final Map<String, dynamic> patient;

  @override
  State<Patientdetail> createState() => _PatientdetailState();
}

class _PatientdetailState extends State<Patientdetail> {
  TextEditingController locationController = TextEditingController();

  late final List<FlSpot> timeSpots;

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
    List<dynamic> bpmData = widget.patient['bpm_data'] ?? [];
    timeSpots = [];
    for (var dataPoint in bpmData) {
      double time = dataPoint['time'].toDouble();
      double bpm = dataPoint['bpm'].toDouble();
      timeSpots.add(FlSpot(time, bpm));
    }

    locationController.text = widget.patient['room'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          children: [
            Text(
              widget.patient['name'] ?? 'No Name',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "${widget.patient['bpm']?.toString() ?? '0'} BPM",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Change Location',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print(
                  'Saving new location: ${locationController.text} to patient ${widget.patient['uid']}',
                );
                // Handle save action
                Data.changePatientRoom(
                      widget.patient['uid'],
                      locationController.text,
                    )
                    .then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Location updated successfully'),
                        ),
                      );
                      Navigator.pushNamed(context, '/home');
                    })
                    .catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update location')),
                      );
                    });
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
