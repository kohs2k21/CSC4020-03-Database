import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class InventoryTab extends StatefulWidget {
  final Database database;

  const InventoryTab({super.key, required this.database});

  @override
  _InventoryTabState createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  List<Map<String, dynamic>> inventory = [];

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    final List<Map<String, dynamic>> result =
        await widget.database.query('inventory');
    setState(() {
      inventory = result;
    });
  }

  Future<void> _updateInventory(int itemId, double newQuantity) async {
    await widget.database.update(
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
      context: context,
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: ListTile(
            title: Text('${item['item_name']}'),
            subtitle: Text('수량: ${item['item_quantity']} ${item['item_unit']}'),
            onTap: () => _showUpdateInventoryDialog(item),
          ),
        );
      },
    );
  }
}
