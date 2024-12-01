import 'package:flutter/material.dart';

class SalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailySales;

  const SalesChart({super.key, required this.dailySales});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: SalesChartPainter(dailySales),
              child: Container(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: dailySales.length,
            itemBuilder: (context, index) {
              final sale = dailySales[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text('날짜: ${sale['date']}'),
                  subtitle: Text('매출: ${sale['total_sales']} 원'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SalesChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dailySales;

  SalesChartPainter(this.dailySales);

  @override
  void paint(Canvas canvas, Size size) {
    const double padding = 16.0;
    final double chartWidth = size.width - 2 * padding;
    final double chartHeight = size.height - 2 * padding;

    // 배경색과 그림자 추가
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final backgroundRect =
        Rect.fromLTWH(padding, padding, chartWidth, chartHeight);
    canvas.drawRect(backgroundRect, shadowPaint);
    canvas.drawRect(backgroundRect, backgroundPaint);

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double stepX = chartWidth / (dailySales.length - 1);
    final double maxY = dailySales
        .map((sale) => sale['total_sales'])
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    for (int i = 0; i < dailySales.length; i++) {
      final x = padding + i * stepX;
      final y = padding +
          chartHeight -
          (dailySales[i]['total_sales'] / maxY * chartHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < dailySales.length; i++) {
      final x = padding + i * stepX;
      final y = padding +
          chartHeight -
          (dailySales[i]['total_sales'] / maxY * chartHeight);

      textPainter.text = TextSpan(
        text: dailySales[i]['date'],
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, size.height - padding + 5));

      textPainter.text = TextSpan(
        text: '${dailySales[i]['total_sales']} 원',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height - 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
