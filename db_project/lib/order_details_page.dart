import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OrderDetailsPage extends StatefulWidget {
  final int orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late Database database;
  List<Map<String, dynamic>> orderDetails = [];

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    String dbPath = join(await getDatabasesPath(), 'pos_database.db');
    database = await openDatabase(dbPath);
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    final List<Map<String, dynamic>> result = await database.rawQuery('''
      SELECT m.menu_name, od.order_menu_count, od.order_sub_total
      FROM `order_details` od
      JOIN `menu` m ON od.menu_id = m.menu_id
      WHERE od.order_id = ?
    ''', [widget.orderId]);

    setState(() {
      orderDetails = result;
    });
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: ListView.builder(
        itemCount: orderDetails.length,
        itemBuilder: (context, index) {
          final detail = orderDetails[index];
          return ListTile(
            title: Text('메뉴: ${detail['menu_name']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('수량: ${detail['order_menu_count']}'),
                Text('소계: ${detail['order_sub_total']} 원'),
              ],
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
