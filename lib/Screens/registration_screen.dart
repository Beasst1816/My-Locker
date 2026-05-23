import 'package:flutter/material.dart';
import 'package:mylocker/Widgets/custom_textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final nameController = TextEditingController();
  final enrollmentController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    enrollmentController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final String name       = nameController.text.trim();
    final String email      = emailController.text.trim();
    final String password   = passwordController.text.trim();
    final String confirmPwd = confirmPasswordController.text.trim(); // <-- Added back
    final String enrollment = enrollmentController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPwd.isEmpty || enrollment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (password != confirmPwd) { // <-- Added back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ── Step 1: Registry check ────────────────────────────────
      final DocumentSnapshot registryDoc = await FirebaseFirestore.instance
          .collection('enrollment_registry')
          .doc(enrollment)
          .get();

      if (registryDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This Enrollment Number is already registered!'),
            ),
          );
        }
        return; // Hard stop — do not create any Auth account
      }

      // ── Step 2: Create Auth account ───────────────────────────
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ── Step 3: Dual write (Atomic Batch) ─────────────────────
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // Write 1: Full student profile
      final DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid);

      batch.set(userRef, {
        'full_name':         name,
        'email':             email,
        'enrollment_number': enrollment,
        'role':              'student',
        'created_at':        FieldValue.serverTimestamp(),
      });

      // Write 2: Claim the enrollment number
      final DocumentReference registryRef = FirebaseFirestore.instance
          .collection('enrollment_registry')
          .doc(enrollment);

      batch.set(registryRef, {
        'uid': userCredential.user!.uid,
      });

      await batch.commit();

      // ── Step 4: Send verification email then sign out ─────────
      await userCredential.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Check Your Email'),
          content: Text(
            'Account created for $email.\n\n'
                'A verification link has been sent to your inbox. '
                'Please verify your email before logging in.',
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Back to LoginScreen
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      final String message = switch (e.code) {
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password'        => 'Password must be at least 6 characters.',
        'invalid-email'        => 'The email address is badly formatted.',
        _                      => 'Registration failed. Please try again.',
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
                  'Welcome!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                CustomTextfield(
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  controller: nameController,
                ),
                const SizedBox(height: 8.0),
                CustomTextfield(
                  label: 'Enrollment',
                  icon: Icons.numbers_outlined,
                  controller: enrollmentController,
                ),
                const SizedBox(height: 8.0),
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
                const SizedBox(height: 8.0),
                CustomTextfield(
                  label: 'Confirm Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: confirmPasswordController,
                ),
                const SizedBox(height: 24.0),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  // Replaced the inline function with our new method
                  onPressed: _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  child: const Text('REGISTER'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}