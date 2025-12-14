import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_home_project/auth/login.dart';
import 'package:smart_home_project/auth/sign_up.dart';
import 'package:smart_home_project/auth/start_page.dart';
import 'package:smart_home_project/pages/camera/camera_page.dart';
import 'package:smart_home_project/pages/home/home_page.dart';
import 'package:smart_home_project/profile/profile_page.dart';
import 'package:smart_home_project/services/notification_service.dart';  // ⭐ NEW

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // ⭐ NEW: Initialize notifications
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        fontFamily: "Poppins",
        useMaterial3: true,
      ),
      routes: {
        "/login": (context) => const LoginPage(),
        "/signup": (context) => const SignUpPage(),
        "/into": (context) => const SmartHomeIntroPage(),
        "/home": (context) => HomePage(),
        "/camera": (context) => const CameraPage(),
        "/profile": (context) => const ProfilePage(),
        
      },
      home: _isLoading
      ? const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        )
      : _user == null
          ? const SmartHomeIntroPage()
          : HomePage(),

    );
  }
}
