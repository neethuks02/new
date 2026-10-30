import 'package:iconex_flutter/iconex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/mock/mock_data.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var filteredLeads = MockData.leads;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredLeads = filteredLeads.where((l) {
        return l.studentName.toLowerCase().contains(query) ||
            l.agencyName.toLowerCase().contains(query) ||
            l.institution.toLowerCase().contains(query) ||
            l.id.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Master Data Sheet'),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Iconex.light.plus),
            onPressed: () => context.push('/create-lead'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name, ID, Agency, Institution...',
                prefixIcon: Icon(Iconex.light.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Data Table
          Expanded(
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notif) => notif.depth == 1,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        AppColors.primary.withOpacity(0.1),
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 52,
                      headingRowHeight: 48,
                      columnSpacing: 24,
                      dividerThickness: 1,
                      border: TableBorder.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(
                          label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Agency', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Institution', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        DataColumn(
                          label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                      ],
                      rows: filteredLeads.map((lead) {
                        return DataRow(
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              context.push('/lead-details/${lead.id}');
                            }
                          },
                          color: MaterialStateProperty.resolveWith<Color?>((
                            Set<MaterialState> states,
                          ) {
                            if (states.contains(MaterialState.hovered)) {
                              return AppColors.primary.withOpacity(0.05);
                            }
                            if (filteredLeads.indexOf(lead) % 2 == 0) {
                              return Colors.white;
                            }
                            return Colors.grey.shade50;
                          }),
                          cells: [
                            DataCell(
                              Text(lead.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                            ),
                            DataCell(
                              Text(_formatDate(lead.createdAt), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ),
                            DataCell(
                              Text(lead.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ),
                            DataCell(
                              Text(lead.agencyName, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ),
                            DataCell(
                              Text('${lead.institution} (${lead.country})', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ),
                            DataCell(
                              Text('\$${lead.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            DataCell(
                              Text(lead.assignedExecutive?.name ?? 'Unassigned', style: TextStyle(fontSize: 14, color: lead.assignedExecutive == null ? AppColors.error : AppColors.textSecondary, fontWeight: lead.assignedExecutive == null ? FontWeight.bold : FontWeight.normal)),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: lead.status == 'New' ? AppColors.warningBackground : lead.status == 'Completed' ? AppColors.successBackground : AppColors.infoBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lead.status,
                                  style: TextStyle(
                                    color: lead.status == 'New' ? AppColors.warning : lead.status == 'Completed' ? AppColors.success : AppColors.info,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}
