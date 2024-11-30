import 'package:flutter/material.dart';

class SalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailySales;

  const SalesChart({super.key, required this.dailySales});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: dailySales.length,
      itemBuilder: (context, index) {
        final sale = dailySales[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: ListTile(
            title: Text('날짜: ${sale['date']}'),
            subtitle: Text('매출: ${sale['total_sales']} 원'),
          ),
        );
      },
    );
  }
}
