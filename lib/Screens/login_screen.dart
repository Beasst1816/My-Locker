import 'package:flutter/material.dart';
import 'package:mylocker/Screens/dashboard_screen_student.dart';
import 'package:mylocker/Screens/guard_dashboard_screen.dart'; // NEW
import 'package:mylocker/Widgets/custom_textfield.dart';
import 'package:mylocker/Screens/registration_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Core login + RBAC routing logic
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    final String email    = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Step 1: Authenticate
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;

      // Step 2: Email verification gate
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Email Not Verified'),
            content: const Text(
              'Please verify your email address before logging in.\n\n'
                  'Check your inbox for a verification link, or request a new one below.',
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  try {
                    final UserCredential temp = await FirebaseAuth.instance
                        .signInWithEmailAndPassword(
                        email: email, password: password);
                    await temp.user!.sendEmailVerification();
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Verification email resent.')),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                            Text('Could not resend. Try again shortly.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.email_outlined),
                label: const Text('Resend Verification Email'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      // Step 3: Fetch Firestore profile
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      // Step 4: Validate the document exists before reading any fields
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User profile not found. Contact your administrator.')),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      final Map<String, dynamic> data =
      userDoc.data() as Map<String, dynamic>;

      final String role =
          data['role'] as String? ?? 'student'; // Safe default
      final String enrollment =
          data['enrollment_number'] as String? ?? '';

      // Step 5: Persist session for SplashScreen restoration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_student_id', enrollment);
      await prefs.setString('saved_role', role);

      if (!mounted) return;

      // Step 6: RBAC routing — pushAndRemoveUntil clears the entire
      // navigation stack so the hardware back button cannot return
      // the user to the login screen after a successful login.
      switch (role) {
        case 'admin':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                (route) => false,
          );

        case 'guard':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GuardDashboardScreen()),
                (route) => false,
          );

        case 'student':
        default:
        // Default catches any missing or unrecognised role value
        // and routes safely to the student dashboard.
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DashboardScreenStudent(studentID: enrollment),
            ),
                (route) => false,
          );
      }
    } on FirebaseAuthException catch (e) {
      final String message = switch (e.code) {
        'user-not-found'     => 'No account found for that email.',
        'wrong-password'     => 'Incorrect password. Please try again.',
        'invalid-email'      => 'The email address is badly formatted.',
        'user-disabled'      => 'This account has been disabled.',
        'invalid-credential' => 'Invalid credentials. Please try again.',
        _                    => 'Login failed. Please try again.',
      };
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 100),
                CustomTextfield(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),
                const SizedBox(height: 8.0),
                CustomTextfield(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: passwordController,
                ),
                const SizedBox(height: 24.0),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  // Extracted to a named method — keeps build() clean
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 55),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}