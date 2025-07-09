import 'package:driving/dashboard.dart';
import 'package:driving/services/app_bindings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for Windows
  sqfliteFfiInit();

  // Set the database factory to use FFI
  databaseFactory = databaseFactoryFfi;
  runApp(GetMaterialApp(
    initialBinding: AppBindings(),
    home: DashboardScreen(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Driving School Management',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => DashboardScreen()),
      ],
    );
  }
}
