import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProgressChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;

  const ProgressChart({super.key, required this.data, required this.title});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات كافية لعرض الرسم البياني', style: TextStyle(color: Colors.grey)),
      );
    }

    // تحويل البيانات القادمة من قاعدة البيانات إلى نقاط (X, Y)
    List<FlSpot> spots = [];
    List<String> dates = [];

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final date = DateTime.parse(row['date_created']);
      final value = (row['active_range'] as num).toDouble();
      
      spots.add(FlSpot(i.toDouble(), value));
      dates.add(DateFormat('MM/dd').format(date));
    }

    // حساب الحد الأقصى للمحور Y لإظهار الرسم بشكل جيد
    double maxY = 100; 
    if (spots.isNotEmpty) {
       double maxVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
       maxY = maxVal + 20; // إضافة هامش
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < dates.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(dates[index], style: const TextStyle(fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          interval: 1,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}