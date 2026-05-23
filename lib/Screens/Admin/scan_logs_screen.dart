import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mylocker/Screens/Admin/shared_admin_components.dart';

class ScanLogsScreen extends StatefulWidget {
  const ScanLogsScreen({super.key});

  @override
  State<ScanLogsScreen> createState() => _ScanLogsScreenState();
}

class _ScanLogsScreenState extends State<ScanLogsScreen> {
  // Filter state
  String _statusFilter = 'all'; // 'all' | 'granted' | 'denied'

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan Logs',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Audit trail of all gate scan events.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),

              // Status filter chips
              _FilterChip(
                label: 'All',
                selected: _statusFilter == 'all',
                color: const Color(0xFF1A73E8),
                onTap: () => setState(() => _statusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Granted',
                selected: _statusFilter == 'granted',
                color: Colors.green.shade600,
                onTap: () => setState(() => _statusFilter = 'granted'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Denied',
                selected: _statusFilter == 'denied',
                color: Colors.red.shade600,
                onTap: () => setState(() => _statusFilter = 'denied'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── DataTable ─────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
                  );
                }

                if (snapshot.hasError) {
                  return AdminErrorBanner(
                    message: snapshot.error.toString(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return AdminEmptyState(
                    icon: Icons.history_rounded,
                    message: _statusFilter == 'all'
                        ? 'No scan events recorded yet.'
                        : 'No "$_statusFilter" events found.',
                    hint: _statusFilter != 'all'
                        ? 'Try switching the filter to "All" to see all records.'
                        : null,
                  );
                }

                // ── THE MISSING RETURN STATEMENT ─────────────────────────
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FF)),
                          headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
                          dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                          columnSpacing: 32,
                          columns: const [
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Enrollment No.')),
                            DataColumn(label: Text('Guard UID')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Scanned At')),
                          ],
                          rows: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String status = data['status'] as String? ?? 'unknown';
                            final bool granted = status == 'granted';
                            final Timestamp? ts = data['scanned_at'] as Timestamp?;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: granted ? Colors.green.shade50 : Colors.red.shade50,
                                        child: Text(
                                          ((data['student_name'] as String?) ?? '?').isNotEmpty
                                              ? (data['student_name'] as String)[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: granted ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(data['student_name'] as String? ?? '—'),
                                    ],
                                  ),
                                ),
                                DataCell(Text(data['enrollment_number'] as String? ?? '—')),
                                DataCell(
                                  Tooltip(
                                    message: data['guard_uid'] as String? ?? '—',
                                    child: Text(
                                      _truncate(data['guard_uid'] as String? ?? '—', 12),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: granted ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: granted ? Colors.green.shade200 : Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          size: 13,
                                          color: granted ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: granted ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                  ts != null ? _formatTimestamp(ts) : '—',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
                // ─────────────────────────────────────────────────────────────
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build the correct Firestore stream depending on the active filter
  Stream<QuerySnapshot> _buildStream() {
    Query query = FirebaseFirestore.instance
        .collection('scan_logs')
        .orderBy('scanned_at', descending: true)
        .limit(100);

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query.snapshots();
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}/${dt.year}  $hour:$min $period';
  }

  String _truncate(String str, int maxLen) =>
      str.length > maxLen ? '${str.substring(0, maxLen)}…' : str;
}

// ═══════════════════════════════════════════════
// Filter Chip
// ═══════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}