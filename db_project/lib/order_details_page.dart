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
  Map<int, List<Map<String, dynamic>>> recipeDetails = {};

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
      SELECT m.menu_name, od.order_menu_count, od.order_sub_total, m.menu_id
      FROM `order_details` od
      JOIN `menu` m ON od.menu_id = m.menu_id
      WHERE od.order_id = ?
    ''', [widget.orderId]);

    setState(() {
      orderDetails = result;
    });

    for (var order in result) {
      int menuId = order['menu_id'];
      await _fetchRecipeDetails(menuId);
    }
  }

  Future<void> _fetchRecipeDetails(int menuId) async {
    final List<Map<String, dynamic>> result = await database.rawQuery('''
      SELECT i.item_name, rd.quantity_required, i.item_unit
      FROM `RecipeDetails` rd
      JOIN `inventory` i ON rd.item_id = i.item_id
      WHERE rd.menu_id = ?
    ''', [menuId]);

    setState(() {
      recipeDetails[menuId] = result;
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
        title: const Text('주문 상세 정보'),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        itemCount: orderDetails.length,
        itemBuilder: (context, index) {
          final order = orderDetails[index];
          final menuId = order['menu_id'];
          final recipes = recipeDetails[menuId] ?? [];

          return ExpansionTile(
            title: Text(order['menu_name']),
            subtitle: Text(
                '수량 : ${order['order_menu_count']} - 소계 : ${order['order_sub_total']}'),
            children: recipes.map((recipe) {
              return ListTile(
                title: Text(recipe['item_name']),
                subtitle: Text(
                    '필요 수량: ${recipe['quantity_required']} ${recipe['item_unit']}'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
