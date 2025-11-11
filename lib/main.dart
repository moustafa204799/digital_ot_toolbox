// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart'; // 1. Add this import

import 'database/database_helper.dart';
import 'screens/dashboard_screen.dart'; 

void main() async {
  // Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Add this line to initialize Arabic date formatting
  await initializeDateFormatting('ar', null); 
  
  // Your existing database initializations
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.insertInitialSettings();
  await DatabaseHelper.instance.insertInitialSkills();
  
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Your ScreenUtilInit setup (from the previous step)
    return ScreenUtilInit(
      designSize: const Size(390, 844), 
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context , child) {
        return MaterialApp(
          title: 'Digital OT Toolbox',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: child, 
        );
      },
      child: const DashboardScreen(), 
    );
  }
}