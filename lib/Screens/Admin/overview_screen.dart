import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mylocker/Screens/Admin/shared_admin_components.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  // Reads are one-time futures, not streams — overview cards don't
  // need to update in real-time and futures are cheaper on quota.
  Future<int> _getStudentCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _getGuardCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'guard')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _getRecentScanCount() async {
    final Timestamp cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final snapshot = await FirebaseFirestore.instance
        .collection('scan_logs')
        .where('scanned_at', isGreaterThan: cutoff)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> _getGrantedScanCount() async {
    final Timestamp cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final snapshot = await FirebaseFirestore.instance
        .collection('scan_logs')
        .where('scanned_at', isGreaterThan: cutoff)
        .where('status', isEqualTo: 'granted')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ────────────────────────────
          const Text(
            'System Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live snapshot of the MyLocker system.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 32),

          // ── Stat cards ──────────────────────────────
          // LayoutBuilder lets us switch between 2-column and
          // 4-column grid depending on available width.
          LayoutBuilder(
            builder: (context, constraints) {
              final int crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                    title: 'Total Students',
                    icon: Icons.school_rounded,
                    color: const Color(0xFF1A73E8),
                    future: _getStudentCount(),
                  ),
                  _StatCard(
                    title: 'Total Guards',
                    icon: Icons.security_rounded,
                    color: Colors.green.shade600,
                    future: _getGuardCount(),
                  ),
                  _StatCard(
                    title: 'Scans (7 days)',
                    icon: Icons.qr_code_scanner_rounded,
                    color: Colors.purple.shade600,
                    future: _getRecentScanCount(),
                  ),
                  _StatCard(
                    title: 'Granted (7 days)',
                    icon: Icons.check_circle_rounded,
                    color: Colors.teal.shade600,
                    future: _getGrantedScanCount(),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 40),

          // ── Recent activity feed ────────────────────
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          _RecentActivityFeed(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Stat Card
// ═══════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Future<int> future;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            FutureBuilder<int>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text('—',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400));
                }
                return Text(
                  '${snapshot.data ?? 0}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Recent Activity Feed — last 5 scan_logs
// ═══════════════════════════════════════════════
class _RecentActivityFeed extends StatelessWidget {
  const _RecentActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scan_logs')
          .orderBy('scanned_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AdminErrorBanner( // ← Using your new shared component
            message: snapshot.error.toString(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const AdminEmptyState( // ← Using your new shared component
            icon: Icons.history_rounded,
            message: 'No scan activity yet.',
            hint: 'Scans will appear here once guards start using the app.',
          );
        }

        // Helper function inside the builder
        String formatTimestamp(Timestamp ts) {
          final dt = ts.toDate();
          final now = DateTime.now();
          final diff = now.difference(dt);
          if (diff.inMinutes < 1) return 'Just now';
          if (diff.inHours < 1) return '${diff.inMinutes}m ago';
          if (diff.inDays < 1) return '${diff.inHours}h ago';
          return '${dt.day}/${dt.month}/${dt.year}';
        }

        // ── THE MISSING RETURN STATEMENT ─────────────────────────────
        // We actually need to return the UI for the list!
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final bool granted = data['status'] == 'granted';
              final Timestamp? ts = data['scanned_at'] as Timestamp?;
              final String timeStr = ts != null ? formatTimestamp(ts) : '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: granted ? Colors.green.shade50 : Colors.red.shade50,
                  child: Icon(
                    granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: granted ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
                title: Text(
                  data['student_name'] as String? ?? 'Unknown Student',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  'Enrollment: ${data['enrollment_number'] ?? '—'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                trailing: Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
        );
        // ─────────────────────────────────────────────────────────────
      },
    );
  }
}