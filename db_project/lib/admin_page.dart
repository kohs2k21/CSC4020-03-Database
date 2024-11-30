import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'order_details_page.dart';
import 'inventory_tab.dart';
import 'sales_chart.dart';

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
  bool showCompletedOrders = true;

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
      ORDER BY o.order_time 
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
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
            InventoryTab(database: database),
            SalesChart(dailySales: dailySales)
          ],
        ),
      ),
    );
  }

  Future<void> _updateInventory(int itemId, double newQuantity) async {
    await database.update(
      'inventory',
      {'item_quantity': newQuantity},
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    _fetchInventory();
  }

  void _showUpdateInventoryDialog(Map<String, dynamic> item) {
    final TextEditingController quantityController = TextEditingController();
    quantityController.text = item['item_quantity'].toString();

    showDialog<void>(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${item['item_name']} 재고량 변경'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: '새로운 재고량 (${item['item_unit']})'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final double newQuantity =
                    double.parse(quantityController.text);
                _updateInventory(item['item_id'], newQuantity);
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderList() {
    List<Map<String, dynamic>> filteredOrders = showCompletedOrders
        ? orders
        : orders.where((order) => order['order_status'] != '완료').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '완료된 주문 표시',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: showCompletedOrders,
                onChanged: (bool value) {
                  setState(() {
                    showCompletedOrders = value;
                  });
                },
                activeColor: Colors.lightGreen,
                inactiveThumbColor: Colors.red,
                inactiveTrackColor: Colors.red[200],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 5,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  title: Text(
                    '주문 번호: ${order['wait_number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8.0),
                      Text('주문 상태: ${order['order_status']}'),
                      Text('주문 시간: ${order['order_time']}'),
                      Text('가격: ${order['total_price']} 원'),
                      Text('결제 방식: ${order['payment_type']}'),
                    ],
                  ),
                  trailing: Switch(
                    value: order['order_status'] == '완료',
                    onChanged: (value) {
                      _toggleOrderStatus(
                          order['order_id'], order['order_status']);
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red[200],
                  ),
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
          ),
        ),
      ],
    );
  }
}
