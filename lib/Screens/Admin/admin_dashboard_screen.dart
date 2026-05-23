import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mylocker/Screens/login_screen.dart';
import 'package:mylocker/Screens/Admin/overview_screen.dart';
import 'package:mylocker/Screens/Admin/manage_students_screen.dart';
import 'package:mylocker/Screens/Admin/scan_logs_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // Screens are instantiated once and kept alive as the rail
  // index changes — avoids re-fetching Firestore on every tab switch.
  static const List<Widget> _screens = [
    OverviewScreen(),
    ManageStudentsScreen(),
    ScanLogsScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Overview'),
    _NavItem(icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Students'),
    _NavItem(icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: 'Scan Logs'),
  ];

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isExtended = screenWidth >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.lock_person_rounded, size: 22),
            const SizedBox(width: 10),
            const Text(
              'MyLocker — Admin Panel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            // Current admin email for accountability
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white, size: 18),
            label: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ── NavigationRail ───────────────────────
          NavigationRail(
            extended: isExtended,
            backgroundColor: Colors.white,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            selectedIconTheme: const IconThemeData(
              color: Color(0xFF1A73E8),
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey.shade500,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF1A73E8),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
            indicatorColor: const Color(0xFFE8F0FE),
            leading: isExtended
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : null,
            destinations: _navItems
                .map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            ))
                .toList(),
          ),

          // Thin divider between rail and content
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.grey.shade200,
          ),

          // ── Main content area ────────────────────
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

// Simple data class for nav items
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}