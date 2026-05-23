import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mylocker/Screens/Admin/shared_admin_components.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  // Search filter applied client-side on the streamed list
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Atomic delete: users doc + enrollment_registry doc
  // ─────────────────────────────────────────────
  Future<void> _deleteStudent({
    required String uid,
    required String enrollmentNumber,
    required String studentName,
  }) async {
    // Confirm before any destructive action
    final bool confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Student?'),
        content: Text(
          'This will permanently delete "$studentName" '
              '(Enrollment: $enrollmentNumber).\n\n'
              'Their profile and enrollment registry entry will both '
              'be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      // WriteBatch ensures both deletes happen atomically.
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
      batch.delete(FirebaseFirestore.instance.collection('enrollment_registry').doc(enrollmentNumber));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName deleted successfully.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

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
                    'Manage Students',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All registered student accounts.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              // Search field
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or enrollment…',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── DataTable inside StreamBuilder ────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
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

                final allDocs = snapshot.data?.docs ?? [];

                final filteredDocs = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['full_name'] as String? ?? '').toLowerCase();
                  final enrollment = (data['enrollment_number'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) || enrollment.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return AdminEmptyState(
                    icon: Icons.people_outline_rounded,
                    message: _searchQuery.isEmpty
                        ? 'No students registered yet.'
                        : 'No students match "$_searchQuery".',
                    hint: _searchQuery.isEmpty
                        ? 'Students will appear here once they register in the app.'
                        : 'Try a different name or enrollment number.',
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
                          columnSpacing: 40,
                          columns: const [
                            DataColumn(label: Text('Full Name')),
                            DataColumn(label: Text('Enrollment No.')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Joined')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String uid = doc.id;
                            final String name = data['full_name'] ?? 'Unknown';
                            final String enrollment = data['enrollment_number'] ?? '—';
                            final String email = data['email'] ?? '—';
                            final Timestamp? ts = data['created_at'] as Timestamp?;

                            return DataRow(
                              cells: [
                                DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(enrollment)),
                                DataCell(Text(email, style: TextStyle(color: Colors.grey.shade600))),
                                DataCell(Text(ts != null ? _formatDate(ts) : '—')),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                    tooltip: 'Delete Student',
                                    onPressed: () => _deleteStudent(
                                      uid: uid,
                                      enrollmentNumber: enrollment,
                                      studentName: name,
                                    ),
                                  ),
                                ),
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

  String _formatDate(Timestamp ts) {
    final dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}