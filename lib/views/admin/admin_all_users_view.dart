import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/user_model.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminAllUsersView extends StatefulWidget {
  const AdminAllUsersView({super.key});

  @override
  State<AdminAllUsersView> createState() => _AdminAllUsersViewState();
}

class _AdminAllUsersViewState extends State<AdminAllUsersView> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    
    final filteredUsers = adminVM.allUsers.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                          user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'All' || user.role == _roleFilter;
      final matchesStatus = _statusFilter == 'All' || user.status?.toLowerCase() == _statusFilter.toLowerCase();
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilters(),
            const SizedBox(height: 24),
            Expanded(
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: adminVM.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                    ? const AdminEmptyState(icon: Icons.people_outline, message: 'No users found.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AdminColors.navy.withValues(alpha: 0.03)),
                            columns: [
                              DataColumn(label: Text('User', style: AdminTheme.sectionHeaderStyle())),
                              DataColumn(label: Text('Role', style: AdminTheme.sectionHeaderStyle())),
                              DataColumn(label: Text('Company ID', style: AdminTheme.sectionHeaderStyle())),
                              DataColumn(label: Text('Status', style: AdminTheme.sectionHeaderStyle())),
                              DataColumn(label: Text('Joined', style: AdminTheme.sectionHeaderStyle())),
                              DataColumn(label: Text('Actions', style: AdminTheme.sectionHeaderStyle())),
                            ],
                            rows: filteredUsers.map((user) => DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AdminColors.navy.withValues(alpha: 0.1),
                                        child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', 
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminColors.navy)),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(user.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                                          Text(user.email, style: AdminTheme.mutedStyle(size: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(user.role, style: AdminTheme.bodyStyle())),
                                DataCell(Text(user.companyId.isEmpty ? '-' : user.companyId, style: AdminTheme.bodyStyle())),
                                DataCell(StatusChip(status: user.status ?? 'active')),
                                DataCell(Text(DateFormat('MMM d, yyyy').format(user.createdAt), style: AdminTheme.bodyStyle())),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                    onPressed: () => _showUserDetails(user),
                                  ),
                                ),
                              ],
                            )).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textGrey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _roleFilter,
              decoration: AdminTheme.inputDecoration(labelText: 'Role'),
              items: ['All', 'CEO', 'field_user', 'Supplier', 'Admin']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _roleFilter = val!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: AdminTheme.inputDecoration(labelText: 'Status'),
              items: ['All', 'Active', 'Pending', 'Suspended', 'Rejected']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.name}\'s Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailItem('UID', user.uid),
            _detailItem('Email', user.email),
            _detailItem('Phone', user.phone),
            _detailItem('Role', user.role),
            _detailItem('Company ID', user.companyId),
            _detailItem('City', user.city),
            _detailItem('Account Status', user.status ?? 'Active'),
            _detailItem('Joined At', DateFormat('MMM d, yyyy HH:mm').format(user.createdAt)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: AdminTheme.bodyStyle(),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
