import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'order_details_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Database database;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> dailySales = [];

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    String dbPath = join(await getDatabasesPath(), 'pos_database.db');
    database = await openDatabase(dbPath);
    _fetchOrders();
    _fetchInventory();
    _fetchDailySales();
  }

  Future<void> _fetchOrders() async {
    final List<Map<String, dynamic>> result = await database.rawQuery('''
      SELECT o.order_id, o.order_status, o.order_time, o.wait_number, o.total_price, pm.payment_type
      FROM `order` o
      JOIN `payment_method` pm ON o.payment_method = pm.payment_method_id
      ORDER BY o.order_time DESC
    ''');

    setState(() {
      orders = result;
    });
  }

  Future<void> _fetchInventory() async {
    final List<Map<String, dynamic>> result = await database.query('inventory');
    setState(() {
      inventory = result;
    });
  }

  Future<void> _fetchDailySales() async {
    final List<Map<String, dynamic>> result = await database.rawQuery('''
      SELECT DATE(order_time) as date, SUM(total_price) as total_sales
      FROM `order`
      WHERE order_status = '완료'
      GROUP BY DATE(order_time)
      ORDER BY DATE(order_time) DESC
    ''');

    setState(() {
      dailySales = result;
    });
  }

  Future<void> _toggleOrderStatus(int orderId, String currentStatus) async {
    String newStatus = currentStatus == '준비중' ? '완료' : '준비중';
    await database.update(
      'order',
      {'order_status': newStatus},
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    _fetchOrders();
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Page'),
          backgroundColor: Colors.green,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
          bottom: const TabBar(
            labelColor: Colors.white, // 선택된 탭의 텍스트 색상
            unselectedLabelColor: Colors.white70, // 선택되지 않은 탭의 텍스트 색상
            tabs: [
              Tab(text: '주문목록'),
              Tab(text: '재고현황'),
              Tab(text: '매출'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(),
            _buildInventoryList(),
            _buildSalesInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: ListTile(
            title: Text('주문 번호: ${order['order_id']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('상태: ${order['order_status']}'),
                Text('시간: ${order['order_time']}'),
                Text('대기 번호: ${order['wait_number']}'),
                Text('총 가격: ${order['total_price']} 원'),
                Text('결제 방식: ${order['payment_type']}'),
              ],
            ),
            trailing: Switch(
              value: order['order_status'] == '완료',
              onChanged: (value) {
                _toggleOrderStatus(order['order_id'], order['order_status']);
              },
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red[200],
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      OrderDetailsPage(orderId: order['order_id']),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInventoryList() {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: ListTile(
            title: Text('재고: ${item['item_name']}'),
            subtitle: Text('수량: ${item['item_quantity']} ${item['item_unit']}'),
          ),
        );
      },
    );
  }

  Widget _buildSalesInfo() {
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
