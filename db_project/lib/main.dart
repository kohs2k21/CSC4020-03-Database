import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'POS System'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Database database;
  List<Map<String, dynamic>> menus = [];

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    // 데이터베이스 파일 경로 설정
    String dbPath = join(await getDatabasesPath(), 'pos_database.db');

    // 기존 데이터베이스 열기
    database = await openDatabase(dbPath);
    _fetchMenus();
  }

  Future<void> _fetchMenus() async {
    final List<Map<String, dynamic>> maps = await database.query('menu');
    setState(() {
      menus = maps;
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
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: menus.length,
        itemBuilder: (context, index) {
          String imageUrl = menus[index]['menu_image_url'];
          String imagePath = 'assets/image/$imageUrl';

          return ListTile(
            leading: Image.asset(
              imagePath,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset('assets/image/no_image.png');
              },
            ),
            title: Text(menus[index]['menu_name']),
            subtitle: Text('Price: \$${menus[index]['menu_price']}'),
          );
        },
      ),
    );
  }
}
