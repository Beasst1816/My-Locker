import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mylocker/Screens/login_screen.dart';
import 'package:mylocker/Screens/dashboard_screen_student.dart';
import 'package:mylocker/Screens/guard_dashboard_screen.dart'; // NEW
import 'package:mylocker/Screens/Admin/admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Step 1: Brief splash pause for branding
    await Future.delayed(const Duration(seconds: 2));

    // Step 2: Read persisted session data
    final prefs = await SharedPreferences.getInstance();
    final String? savedID = prefs.getString('saved_student_id');
    final String? savedRole = prefs.getString('saved_role'); // NEW

    if (!mounted) return;

    // Step 3: No saved session → go to Login
    if (savedID == null || savedRole == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    // Step 4: RBAC restore — send to the correct dashboard

    if (savedRole == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else if (savedRole == 'guard') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GuardDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreenStudent(studentID: savedID),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'MyLocker',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            CircularProgressIndicator(strokeWidth: 2), // Shows while routing
          ],
        ),
      ),
    );
  }
}
