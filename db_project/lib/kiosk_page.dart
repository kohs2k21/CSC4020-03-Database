import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  _KioskPageState createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final List<Map<String, dynamic>> _cartItems = [];
  late Database database;
  Map<String, List<Map<String, dynamic>>> categorizedMenus = {
    '버거': [],
    '음료': [],
    '디저트': []
  };

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    String dbPath = join(await getDatabasesPath(), 'pos_database.db');
    database = await openDatabase(dbPath);
    _fetchMenus();
  }

  Future<void> _fetchMenus() async {
    final List<Map<String, dynamic>> categories =
        await database.query('category');
    final List<Map<String, dynamic>> menus = await database.query('menu');

    Map<String, List<Map<String, dynamic>>> tempCategorizedMenus = {};
    for (var category in categories) {
      String categoryName = category['category_name'];
      tempCategorizedMenus[categoryName] = menus
          .where((menu) => menu['category_id'] == category['category_id'])
          .toList();
    }

    setState(() {
      categorizedMenus = tempCategorizedMenus;
    });
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  void _addToCart(String item, int quantity, int price) {
    setState(() {
      bool itemExists = false;
      for (var cartItem in _cartItems) {
        if (cartItem['item'] == item) {
          cartItem['quantity'] += quantity;
          itemExists = true;
          break;
        }
      }
      if (!itemExists) {
        _cartItems.add({'item': item, 'quantity': quantity, 'price': price});
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  Future<void> _showQuantityDialog(String item, int price) async {
    int quantity = 1;
    await showDialog<int>(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '수량 선택',
            style: TextStyle(fontSize: 18),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('수량을 선택하세요:', textAlign: TextAlign.center),
                  DropdownButton<int>(
                    value: quantity,
                    onChanged: (int? newValue) {
                      setState(() {
                        quantity = newValue!;
                      });
                    },
                    items: List<int>.generate(10, (int index) => index + 1)
                        .map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
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
                Navigator.of(context).pop(quantity);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null) {
        _addToCart(item, value, price);
      }
    });
  }

  Future<void> _showOrderCompleteDialog(int waitNumber) async {
    await showDialog<void>(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('주문 완료'),
          content: Text('주문이 완료되었습니다. 대기번호: $waitNumber'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPaymentMethodDialog() async {
    String? selectedPaymentMethod;
    await showDialog<String>(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('결제 방식 선택'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RadioListTile<String>(
                    title: const Text('신용카드'),
                    value: 'credit_card',
                    groupValue: selectedPaymentMethod,
                    onChanged: (String? value) {
                      setState(() {
                        selectedPaymentMethod = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('현금'),
                    value: 'cash',
                    groupValue: selectedPaymentMethod,
                    onChanged: (String? value) {
                      setState(() {
                        selectedPaymentMethod = value;
                      });
                    },
                  ),
                ],
              );
            },
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
                Navigator.of(context).pop(selectedPaymentMethod);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    ).then((value) async {
      if (value != null) {
        await _handleOrder(value);
      }
    });
  }

  Future<void> _handleOrder(String paymentMethod) async {
    int totalPrice = _calculateTotalPrice();
    int waitNumber = await _getNextWaitNumber();

    // 주문 테이블에 데이터 삽입
    int orderId = await database.insert('order', {
      'order_status': 'preparing',
      'wait_number': waitNumber,
      // 'dine_option': '매장식사', // 필요에 따라 사용
      'total_price': totalPrice,
      'payment_method':
          paymentMethod == 'credit_card' ? 1 : 2, // 1: 신용카드, 2: 현금
    });

    // 주문 상세 테이블에 데이터 삽입
    for (var cartItem in _cartItems) {
      int menuId = await _getMenuIdByName(cartItem['item']);
      await database.insert('order_details', {
        'order_id': orderId,
        'menu_id': menuId,
        'order_menu_count': cartItem['quantity'],
        'order_sub_total': cartItem['quantity'] * cartItem['price'],
      });
    }

    _clearCart();
    _showOrderCompleteDialog(waitNumber);
  }

  Future<int> _getNextWaitNumber() async {
    final result = await database
        .rawQuery('SELECT MAX(wait_number) as max_wait_number FROM `order`');
    int? maxWaitNumber = result.first['max_wait_number'] as int?;
    return (maxWaitNumber ?? 0) + 1;
  }

  Future<int> _getMenuIdByName(String menuName) async {
    final result = await database
        .query('menu', where: 'menu_name = ?', whereArgs: [menuName]);
    return result.first['menu_id'] as int;
  }

  int _calculateTotalPrice() {
    int total = 0;
    for (var cartItem in _cartItems) {
      total += (cartItem['quantity'] * cartItem['price'] as int);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: categorizedMenus.keys.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kiosk System'),
          backgroundColor: Colors.lightBlue,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            unselectedLabelColor: Colors.white70,
            labelColor: Colors.white,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
            tabs: categorizedMenus.keys
                .map((category) => Tab(text: category))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: categorizedMenus.keys
              .map((category) => _buildMenuList(category))
              .toList(),
        ),
        endDrawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.lightBlue,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white, size: 30),
                    SizedBox(width: 10),
                    Text(
                      '장바구니',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ..._cartItems.map((item) => ListTile(
                    title: Text(item['item']),
                    subtitle:
                        Text('가격: ${item['price']} 원  x ${item['quantity']}'),
                    trailing: Text(
                      '${item['price'] * item['quantity']} 원',
                      style: const TextStyle(fontSize: 18), // 가격 텍스트 크기 키움
                    ),
                  )),
              ListTile(
                title: const Text('합계'),
                trailing: Text(
                  '${_calculateTotalPrice()} 원',
                  style: const TextStyle(fontSize: 18), // 합계 텍스트 크기 키움
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _showPaymentMethodDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text('주문하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(String category) {
    return ListView.builder(
      itemCount: categorizedMenus[category]?.length ?? 0,
      itemBuilder: (context, index) {
        final menu = categorizedMenus[category]![index];
        String imageUrl = menu['menu_image_url'];
        String imagePath = 'assets/image/$imageUrl';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
          leading: SizedBox(
            width: 100, // 이미지 크기를 더 키움
            height: 100, // 적절한 높이 값 설정
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0), // 모서리를 둥글게 설정 (선택 사항)
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset('assets/image/no_image.png',
                      fit: BoxFit.contain);
                },
              ),
            ),
          ),
          title: Text(
            menu['menu_name'],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (menu['menu_description'] != null &&
                  menu['menu_description'].isNotEmpty)
                Text(
                  menu['menu_description'],
                  style: const TextStyle(fontSize: 18),
                ),
              Text(
                '가격: ${menu['menu_price']}원',
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          onTap: () =>
              _showQuantityDialog(menu['menu_name'], menu['menu_price']),
        );
      },
    );
  }
}
