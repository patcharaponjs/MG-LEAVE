
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/landing_screen.dart';
import 'screens/reset_password_screen.dart';
import 'config/supabase_config.dart';

// Navigator กลางสำหรับเปลี่ยนหน้าเมื่อได้รับลิงก์รีเซ็ตรหัสผ่าน
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

StreamSubscription<AuthState>? authSubscription;

// ใช้เก็บสถานะกรณี Supabase แจ้งเตือนก่อนแอปแสดงหน้าจอ
bool passwordRecoveryPending = false;

void openResetPasswordScreen() {
  final navigator = navigatorKey.currentState;

  if (navigator == null) {
    passwordRecoveryPending = true;
    return;
  }

  passwordRecoveryPending = false;

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (context) => const ResetPasswordScreen(),
    ),
    (route) => false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabasePublishableKey,
  );

  // ตรวจจับเหตุการณ์จาก Supabase Auth
  authSubscription =
      Supabase.instance.client.auth.onAuthStateChange.listen(
    (data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        openResetPasswordScreen();
      }
    },
  );

  runApp(const MGLeaveApp());
}

class MGLeaveApp extends StatefulWidget {
  const MGLeaveApp({super.key});

  @override
  State<MGLeaveApp> createState() => _MGLeaveAppState();
}

class _MGLeaveAppState extends State<MGLeaveApp> {
  @override
  void initState() {
    super.initState();

    // ตรวจสอบกรณีได้รับลิงก์ก่อนหน้าแอปพร้อมใช้งาน
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (passwordRecoveryPending) {
        openResetPasswordScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MG Leave Management',

      // Localization สำหรับ Material Widgets และ DatePicker
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],

      locale: const Locale('th', 'TH'),

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087FD0),
        ),
      ),

      // เปิดหน้าเว็บไซต์หลักก่อนเข้าสู่ระบบ
      home: const LandingScreen(),
    );
  }
}
