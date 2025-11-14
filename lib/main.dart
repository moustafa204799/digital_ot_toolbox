import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/dashboard_screen.dart';
import 'database/database_helper.dart';

// Global Notifier for Theme Control
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await DatabaseHelper.instance.insertInitialSkills();
  
  final settings = await DatabaseHelper.instance.getSettings();
  if (settings != null) {
    if (settings.themeMode == 'light') {
      themeNotifier.value = ThemeMode.light;
    } else if (settings.themeMode == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else {
      themeNotifier.value = ThemeMode.system;
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Digital OT Toolbox',
              themeMode: currentMode,
              
              // ☀️ Light Theme
              theme: ThemeData(
                brightness: Brightness.light,
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Colors.grey[50],
                // ✅ ضبط النص ليكون أسود في الوضع الفاتح
                textTheme: Typography.englishLike2018.apply(
                  fontSizeFactor: 1.sp,
                  bodyColor: Colors.black,
                  displayColor: Colors.black,
                ),
                useMaterial3: true,
                fontFamily: 'NotoSansArabic',
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                cardTheme: const CardThemeData(
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 2,
                ),
              ),
              
              // 🌙 Dark Theme
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primarySwatch: Colors.indigo,
                scaffoldBackgroundColor: const Color(0xFF121212),
                // ✅ ضبط النص ليكون أبيض في الوضع الداكن
                textTheme: Typography.englishLike2018.apply(
                  fontSizeFactor: 1.sp,
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
                useMaterial3: true,
                fontFamily: 'NotoSansArabic',
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1F1F1F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                cardTheme: const CardThemeData(
                  color: Color(0xFF1E1E1E),
                  surfaceTintColor: Color(0xFF1E1E1E),
                  elevation: 2,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Color(0xFF1F1F1F),
                  selectedItemColor: Colors.blueAccent,
                  unselectedItemColor: Colors.grey,
                ),
              ),
              
              locale: const Locale('ar'),
              home: const DashboardScreen(),
            );
          },
        );
      },
    );
  }
}