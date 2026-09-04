import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mylocker/Screens/login_screen.dart';
import 'package:mylocker/Screens/scanner_view_screen.dart';
import 'package:vibration/vibration.dart';

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({super.key});

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();

  // ═══════════════════════════════════════════════════════════════
  // STATIC METHODS — on the Widget class so ScannerViewScreen
  // can call GuardDashboardScreen.runScanFlow(...) without importing
  // the State class.
  // ═══════════════════════════════════════════════════════════════

  /// Queries Firestore for a student matching [enrollmentNumber].
  /// Returns the document data Map (with 'student_uid' injected
  /// from the document ID), or null if no match found.
  static Future<Map<String, dynamic>?> lookupEnrollment(
    String enrollmentNumber,
  ) async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('users')
        .where('enrollment_number', isEqualTo: enrollmentNumber)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final DocumentSnapshot doc = result.docs.first;
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      // Inject the Firestore document ID so callers have the UID
      // without a second round-trip to the database.
      data['student_uid'] = doc.id;
      return data;
    }
    return null;
  }

  /// Writes one document to the `scan_logs` collection.
  /// Called after every successful lookup — both QR and manual.
  ///
  /// Uses FieldValue.serverTimestamp() so the timestamp is always
  /// authoritative (no clock-skew from the device).
  static Future<void> _writeScanLog({
    required String studentUid,
    required String enrollmentNumber,
    required String studentName,
  }) async {
    final String? guardUid = FirebaseAuth.instance.currentUser?.uid;

    // Refuse to write a log with no guard identity attached.
    if (guardUid == null) return;

    await FirebaseFirestore.instance.collection('scan_logs').add({
      'student_uid': studentUid,
      'enrollment_number': enrollmentNumber,
      'student_name': studentName,
      'guard_uid': guardUid,
      'scanned_at': FieldValue.serverTimestamp(),
    });
  }

  /// Full scan cycle: lookup → log write → show dialog.
  /// Called by ScannerViewScreen after a QR code is detected.
  static Future<void> runScanFlow({
    required BuildContext context,
    required String scannedCode,
    required VoidCallback onScanNext,
    required VoidCallback onClose,
    VoidCallback?
    onLookupComplete, // ← NEW: nullable, safe to ignore from manual entry
  }) async {
    try {
      final Map<String, dynamic>? data = await lookupEnrollment(scannedCode);

      // ── Firestore round-trip is done ─────────────
      // Dismiss the spinner BEFORE showDialog so the
      // background UI is clean when the dialog appears.
      onLookupComplete?.call();

      if (!context.mounted) return;

      if (data != null) {
        Vibration.vibrate(duration: 200, amplitude: 255);

        final String studentUid = data['student_uid'] as String? ?? '';
        final String fullName = data['full_name'] as String? ?? 'Unknown';
        final String enrollment =
            data['enrollment_number'] as String? ?? scannedCode;

        bool logFailed = false;
        try {
          await _writeScanLog(
            studentUid: studentUid,
            enrollmentNumber: enrollment,
            studentName: fullName,
          );
        } catch (_) {
          logFailed = true;
        }

        if (!context.mounted) return;

        if (context.mounted && logFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verified, but the audit log failed to save.'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        _showResultDialog(
          context: context,
          isSuccess: true,
          fullName: fullName,
          enrollmentNumber: enrollment,
          onScanNext: onScanNext,
          onClose: onClose,
          isOnScannerScreen: true,
        );
      } else {
        Vibration.vibrate(duration: 200, amplitude: 255);

        _showResultDialog(
          context: context,
          isSuccess: false,
          onScanNext: onScanNext,
          onClose: onClose,
          isOnScannerScreen: true,
        );
      }
    } on FirebaseException catch (e) {
      Vibration.vibrate(duration: 200, amplitude: 255);
      onLookupComplete?.call(); // ← Also clear spinner on error paths
      if (context.mounted) {
        _showResultDialog(
          context: context,
          isSuccess: false,
          errorMessage:
              'Network error: ${e.message ?? 'Could not reach the database.'}',
          onScanNext: onScanNext,
          onClose: onClose,
          isOnScannerScreen: true,
        );
      }
    } catch (e) {
      Vibration.vibrate(duration: 200, amplitude: 255);
      onLookupComplete?.call(); // ← And on unexpected errors
      if (context.mounted) {
        _showResultDialog(
          context: context,
          isSuccess: false,
          errorMessage: 'Unexpected error. Please try again.',
          onScanNext: onScanNext,
          onClose: onClose,
          isOnScannerScreen: true,
        );
      }
    }
  }

  /// Builds and shows the result Dialog.
  /// Private so only this file controls when it appears.
  static void _showResultDialog({
    required BuildContext context,
    required bool isSuccess,
    required VoidCallback onScanNext,
    required VoidCallback onClose,
    required bool isOnScannerScreen,
    String? fullName,
    String? enrollmentNumber,
    String? errorMessage,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: isSuccess
              ? _SuccessDialogContent(
                  fullName: fullName!,
                  enrollmentNumber: enrollmentNumber!,
                  onScanNext: onScanNext,
                  onClose: onClose,
                  isOnScannerScreen: isOnScannerScreen,
                )
              : _FailureDialogContent(
                  message:
                      errorMessage ?? 'Invalid QR Code or Student Not Found.',
                  onScanNext: onScanNext,
                  onClose: onClose,
                  isOnScannerScreen: isOnScannerScreen,
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Timestamp formatting helpers
  // Static so they can be used by the StreamBuilder
  // inside build() without a State reference.
  // ─────────────────────────────────────────────

  /// Returns "Today at 2:45 PM", "Yesterday at…", or "12/06/2025 at…"
  static String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final DateTime dt = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime todayMidnight = DateTime(now.year, now.month, now.day);
    final DateTime yesterdayMidnight = todayMidnight.subtract(
      const Duration(days: 1),
    );
    final DateTime dtMidnight = DateTime(dt.year, dt.month, dt.day);
    final String timeStr = _formatTime(dt);

    if (dtMidnight == todayMidnight) return 'Today at $timeStr';
    if (dtMidnight == yesterdayMidnight) return 'Yesterday at $timeStr';
    return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
  }

  static String _formatTime(DateTime dt) {
    final int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $period';
  }
}

// ═══════════════════════════════════════════════
// State class
// ═══════════════════════════════════════════════
class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  final TextEditingController _manualController = TextEditingController();
  bool _isQuerying = false;
  bool _isDeleting = false; // Spinner for maintenance action

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  // Manual entry submit
  // ─────────────────────────────────────────────
  Future<void> _handleManualSubmit() async {
    final String input = _manualController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an enrollment number.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isQuerying = true);

    try {
      final Map<String, dynamic>? data =
          await GuardDashboardScreen.lookupEnrollment(input);

      if (!mounted) return;

      if (data != null) {
        final String studentUid = data['student_uid'] as String? ?? '';
        final String fullName = data['full_name'] as String? ?? 'Unknown';
        final String enrollment = data['enrollment_number'] as String? ?? input;

        // Log manual entry verifications too — same audit trail
        GuardDashboardScreen._writeScanLog(
          studentUid: studentUid,
          enrollmentNumber: enrollment,
          studentName: fullName,
        );

        GuardDashboardScreen._showResultDialog(
          context: context,
          isSuccess: true,
          fullName: fullName,
          enrollmentNumber: enrollment,
          onScanNext: () {
            Navigator.pop(context);
            _manualController.clear();
          },
          onClose: () {
            Navigator.pop(context);
            _manualController.clear();
          },
          isOnScannerScreen: false,
        );
      } else {
        GuardDashboardScreen._showResultDialog(
          context: context,
          isSuccess: false,
          onScanNext: () => Navigator.pop(context),
          onClose: () {
            Navigator.pop(context);
            _manualController.clear();
          },
          isOnScannerScreen: false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuerying = false);
    }
  }

  // ─────────────────────────────────────────────
  // 30-Day rolling log cleanup
  // ─────────────────────────────────────────────
  Future<void> _deleteOldLogs() async {
    setState(() => _isDeleting = true);

    try {
      final Timestamp cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      // Fetch all documents older than 30 days in one read
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('scan_logs')
          .where('scanned_at', isLessThan: cutoff)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ No old logs found. Database is clean.'),
          ),
        );
        return;
      }

      // Firestore WriteBatch has a hard limit of 500 operations.
      // Loop in chunks so this works even if logs have accumulated
      // for a long time before the first maintenance run.
      const int chunkSize = 500;
      int totalDeleted = 0;

      for (int i = 0; i < snapshot.docs.length; i += chunkSize) {
        final WriteBatch batch = FirebaseFirestore.instance.batch();

        final int end = (i + chunkSize < snapshot.docs.length)
            ? i + chunkSize
            : snapshot.docs.length;

        for (int j = i; j < end; j++) {
          batch.delete(snapshot.docs[j].reference);
          totalDeleted++;
        }

        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🗑️ Deleted $totalDeleted log(s) older than 30 days.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maintenance failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ─────────────────────────────────────────────
  // Confirmation dialog before deleting
  // ─────────────────────────────────────────────
  void _confirmMaintenance() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Run System Maintenance?'),
        content: const Text(
          'This will permanently delete all scan logs older than '
          '30 days. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOldLogs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete Old Logs'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Realtime stream of recent scan logs
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> get _scanLogsStream => FirebaseFirestore.instance
      .collection('scan_logs')
      .orderBy('scanned_at', descending: true)
      .limit(50)
      .snapshots();

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text(
          'Guard Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Maintenance button — subtle wrench icon
          _isDeleting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.build_circle_outlined),
                  tooltip: 'Run System Maintenance',
                  onPressed: _confirmMaintenance,
                ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Role badge (centred) ─────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Guard Access  •  Camera Standby',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Column(
                children: [
                  const Text(
                    'Gate Control Panel',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Camera stays off until you need it,\nsaving battery between scans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── QR Scanner card ──────────────────────
            Card(
              elevation: 6,
              shadowColor: Colors.blue.withOpacity(0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(44),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 48,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'QR Code Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Opens camera for continuous scanning.\nScan multiple students without reopening.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerViewScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text(
                        'Open QR Scanner',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Manual entry card ────────────────────
            Card(
              elevation: 3,
              shadowColor: Colors.grey.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Manual Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Use when a student's screen is cracked or unreadable.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _manualController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. EN2024001',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: Colors.orange.shade600,
                        ),
                        filled: true,
                        fillColor: Colors.orange.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.orange.shade400,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.orange.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _isQuerying
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1A73E8),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _handleManualSubmit,
                            icon: const Icon(Icons.search_rounded),
                            label: const Text(
                              'Verify Student',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Recent Scans header ──────────────────
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF1A73E8),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Last 50',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── StreamBuilder — live scan log list ───
            StreamBuilder<QuerySnapshot>(
              stream: _scanLogsStream,
              builder: (context, snapshot) {
                // State 1: Waiting for first data packet
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  );
                }

                // State 2: Stream returned an error
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Could not load scan history.',
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // State 3: No logs yet
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No scans recorded yet.',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // State 4: Render the log list
                // Using shrinkWrap + NeverScrollableScrollPhysics
                // so the ListView sits inside the outer
                // SingleChildScrollView cleanly.
                return Card(
                  elevation: 2,
                  shadowColor: Colors.grey.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 72,
                      color: Colors.grey.shade100,
                    ),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      final String studentName =
                          data['student_name'] as String? ?? 'Unknown';
                      final String enrollmentNumber =
                          data['enrollment_number'] as String? ?? '—';

                      // scanned_at can briefly be null on the
                      // client before the server timestamp resolves
                      final Timestamp? ts = data['scanned_at'] as Timestamp?;
                      final String timeLabel =
                          GuardDashboardScreen.formatTimestamp(ts);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8F0FE),
                          child: Text(
                            // First letter of student name as avatar
                            studentName.isNotEmpty
                                ? studentName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF1A73E8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        subtitle: Text(
                          enrollmentNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        trailing: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Dialog content widgets — unchanged from before
// ═══════════════════════════════════════════════

class _SuccessDialogContent extends StatelessWidget {
  final String fullName;
  final String enrollmentNumber;
  final VoidCallback onScanNext;
  final VoidCallback onClose;
  final bool isOnScannerScreen;

  const _SuccessDialogContent({
    required this.fullName,
    required this.enrollmentNumber,
    required this.onScanNext,
    required this.onClose,
    required this.isOnScannerScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade600,
            size: 44,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Access Granted',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Student verified successfully',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.person_rounded,
                label: 'Full Name',
                value: fullName,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Enrollment No.',
                value: enrollmentNumber,
                color: Colors.green.shade700,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isOnScannerScreen) ...[
          ElevatedButton.icon(
            onPressed: onScanNext,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(
              'Scan Next Student',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onClose,
          icon: Icon(
            isOnScannerScreen ? Icons.close_rounded : Icons.check_rounded,
          ),
          label: Text(
            isOnScannerScreen ? 'Close Scanner' : 'Done',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }
}

class _FailureDialogContent extends StatelessWidget {
  final String message;
  final VoidCallback onScanNext;
  final VoidCallback onClose;
  final bool isOnScannerScreen;

  const _FailureDialogContent({
    required this.message,
    required this.onScanNext,
    required this.onClose,
    required this.isOnScannerScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cancel_rounded,
            color: Colors.red.shade600,
            size: 44,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Access Denied',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.red.shade400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ask the student to open MyLocker and show their QR code.',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isOnScannerScreen) ...[
          ElevatedButton.icon(
            onPressed: onScanNext,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Scan Next Student',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onClose,
          icon: Icon(
            isOnScannerScreen ? Icons.close_rounded : Icons.check_rounded,
          ),
          label: Text(
            isOnScannerScreen ? 'Close Scanner' : 'Dismiss',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
