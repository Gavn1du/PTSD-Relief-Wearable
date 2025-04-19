import 'package:flutter/material.dart';
import 'package:ptsd_relief_app/components/navbar.dart';
import 'package:ptsd_relief_app/size_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ptsd_relief_app/components/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  late final double nowMillis;
  late final double oneHourAgoMillis;
  late final List<FlSpot> timeSpots;

  List<Color> gradientColors = [
    AppColors.contentColorCyan,
    AppColors.contentColorBlue,
  ];

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    Widget text;
    switch (value.toInt()) {
      case 2:
        text = const Text('5:00', style: style);
        break;
      case 5:
        text = const Text('5:15', style: style);
        break;
      case 8:
        text = const Text('5:30', style: style);
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
      case 1:
        text = '60';
        break;
      case 3:
        text = '90';
        break;
      case 5:
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
      maxX: 11,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 3),
            FlSpot(2.6, 2),
            FlSpot(4.9, 5),
            FlSpot(6.8, 3.1),
            FlSpot(8, 4),
            FlSpot(9.5, 3),
            FlSpot(11, 4),
          ],
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
                        Text('67', style: TextStyle(fontSize: 20)),
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
                    padding: const EdgeInsets.all(13.0),
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
                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return const RecommendationCard();
                      },
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
  const RecommendationCard({super.key});

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
          children: [Text('67', style: TextStyle(fontSize: 20)), Text('BPM')],
        ),
      ),
    );
  }
}
