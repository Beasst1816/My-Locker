// dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mylocker/Screens/login_screen.dart';

class DashboardScreenStudent extends StatefulWidget {
  final String studentID;

  const DashboardScreenStudent({super.key, required this.studentID});

  @override
  State<DashboardScreenStudent> createState() => _DashboardScreenStudentState();
}

class _DashboardScreenStudentState extends State<DashboardScreenStudent> {
  // --- State Variables ---
  String? _fullName;       // Null until fetched from Firestore
  bool _isLoading = true;  // Controls the loading spinner
  String? _errorMessage;   // Holds any fetch error to show the user

  // ─────────────────────────────────────────────
  // Lifecycle: fetch user data as soon as screen mounts
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // ─────────────────────────────────────────────
  // Firestore fetch: reads full_name from /users/{uid}
  // ─────────────────────────────────────────────
  Future<void> _fetchUserData() async {
    try {
      // Step 1: Get the currently signed-in user's UID from Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // Edge case: Auth session expired between screens
        if (mounted) {
          setState(() {
            _errorMessage = 'Session expired. Please log in again.';
            _isLoading = false;
          });
        }
        return;
      }

      // Step 2: Use that UID to find their document in the 'users' collection
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Step 3: Always check mounted before calling setState
      // (user might have navigated away while the Future was in-flight)
      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          // Cast to Map to safely read the field
          final data = doc.data() as Map<String, dynamic>;
          _fullName = data['full_name'] as String? ?? 'Student';
          _isLoading = false;
        });
      } else {
        // Document missing — fall back gracefully instead of crashing
        setState(() {
          _fullName = 'Student';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Network error, permission denied, etc.
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load profile. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // Logout helper — clears prefs and pops to Login
  // ─────────────────────────────────────────────
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut(); // Sign out from Firebase Auth too
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF), // Soft blue-grey background
      appBar: AppBar(
        title: const Text('My Locker'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A73E8), // Google-blue accent
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // ─────────────────────────────────────────────
  // Body switcher — loading / error / content
  // ─────────────────────────────────────────────
  Widget _buildBody() {
    // State 1: Still fetching from Firestore
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A73E8),
        ),
      );
    }

    // State 2: Something went wrong
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Allow user to retry the fetch
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _fetchUserData();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State 3: Data loaded — show the polished dashboard
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Welcome Header ──────────────────────────
          Text(
            'Welcome back,',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fullName ?? 'Student',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E), // Deep navy for contrast
            ),
          ),

          const SizedBox(height: 32),

          // ── QR Code Card ────────────────────────────
          Card(
            elevation: 6,
            shadowColor: Colors.blue.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
              child: Column(
                children: [
                  // Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF1A73E8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scan at the Gate',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // QR Code
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1A73E8).withOpacity(0.2),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: widget.studentID, // widget. prefix since we're in State
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1A1A2E),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Divider(color: Colors.grey[200]),

                  const SizedBox(height: 16),

                  // Enrollment number chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE), // Light blue tint
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: Color(0xFF1A73E8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${widget.studentID}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A73E8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Tip Banner ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Keep this QR code ready when approaching the gate or your locker.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}