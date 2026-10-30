import 'package:iconex_flutter/iconex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/mock/mock_data.dart';

/*
// --- OLD UI COMMENTED OUT ---

class LeadsScreen extends StatefulWidget {
  final String initialStatus;
  const LeadsScreen({super.key, this.initialStatus = 'All'});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  late String _selectedStatus;
  String _selectedCountry = 'All';
  Executive? _selectedExecutive;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void didUpdateWidget(LeadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      _selectedStatus = widget.initialStatus;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<String> _statusFilters = [
    'All',
    'New',
    'In Progress',
    'Completed',
  ];
  final List<String> _countryFilters = [
    'All',
    'United Kingdom',
    'Canada',
    'USA',
    'Australia',
  ];

  @override
  Widget build(BuildContext context) {
    var filteredLeads = MockData.leads;
    if (_selectedStatus != 'All') {
      filteredLeads = filteredLeads
          .where((l) => l.status == _selectedStatus)
          .toList();
    }
    if (_selectedCountry != 'All') {
      filteredLeads = filteredLeads
          .where((l) => l.country == _selectedCountry)
          .toList();
    }
    if (_selectedExecutive != null) {
      filteredLeads = filteredLeads
          .where((l) => l.assignedExecutive?.id == _selectedExecutive!.id)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredLeads = filteredLeads.where((l) {
        return l.studentName.toLowerCase().contains(query) ||
            l.program.toLowerCase().contains(query) ||
            l.country.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads Management'),
        actions: [
          IconButton(
            icon: Icon(Iconex.light.filter),
            onPressed: _showAdvancedFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads...',
                prefixIcon: Icon(
                  Iconex.light.search,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredLeads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final lead = filteredLeads[index];
                return _LeadCard(lead: lead);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-lead'),
        icon: Icon(Iconex.light.plus),
        label: const Text('New Lead'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _statusFilters[index];
          final isSelected = filter == _selectedStatus;
          return FilterChip(
            selected: isSelected,
            label: Text(filter),
            onSelected: (selected) {
              setState(() {
                _selectedStatus = filter;
              });
            },
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
          );
        },
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Country',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _countryFilters
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedCountry = val!);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Assigned Executive',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Executive?>(
                    value: _selectedExecutive,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<Executive?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...MockData.executives.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedExecutive = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Update main screen
                        context.pop();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;

  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.push('/lead-details/${lead.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.studentName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead.country,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Exec: ${lead.assignedExecutive?.name ?? 'Unassigned'}',
                        style: TextStyle(
                          color: lead.assignedExecutive == null
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg, text;
    if (lead.status == 'New') {
      bg = AppColors.warningBackground;
      text = AppColors.warning;
    } else if (lead.status == 'Completed') {
      bg = AppColors.successBackground;
      text = AppColors.success;
    } else {
      bg = AppColors.infoBackground;
      text = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        lead.status,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

*/

// --- NEW EXCEL-LIKE UI ---
class LeadsScreen extends StatefulWidget {
  final String initialStatus;
  const LeadsScreen({super.key, this.initialStatus = 'All'});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late String _selectedStatus;
  
  List<Lead> _localLeads = List.from(MockData.leads);

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Inline Add New Row state
  bool _isAddingNewRow = false;
  final TextEditingController _newNameCtrl = TextEditingController();
  final TextEditingController _newProgramCtrl = TextEditingController();
  final TextEditingController _newCountryCtrl = TextEditingController();
  String _newStatus = 'New';

  final List<String> _statusFilters = [
    'All',
    'New',
    'In Progress',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void didUpdateWidget(LeadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      _selectedStatus = widget.initialStatus;
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _searchController.dispose();
    _newNameCtrl.dispose();
    _newProgramCtrl.dispose();
    _newCountryCtrl.dispose();
    super.dispose();
  }
  
  void _saveNewLead() {
    if (_newNameCtrl.text.trim().isEmpty) {
      setState(() => _isAddingNewRow = false);
      return;
    }
    
    final nameParts = _newNameCtrl.text.trim().split(' ');
    final fName = nameParts.first;
    final lName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
    
    final newLead = Lead(
      id: 'L${1000 + _localLeads.length + 1}',
      firstName: fName,
      lastName: lName,
      phone: '',
      email: '',
      address: '',
      agencyName: '',
      branchLocation: '',
      counselorName: '',
      program: _newProgramCtrl.text.trim(),
      country: _newCountryCtrl.text.trim(),
      institution: '',
      intake: '',
      totalAmount: 0,
      advanceAmount: 0,
      agencyCommission: 0,
      documents: [],
      status: _newStatus,
      createdAt: DateTime.now(),
      timeline: [],
    );
    
    setState(() {
      _localLeads.insert(0, newLead);
      _isAddingNewRow = false;
    });
  }

  DataRow _buildNewLeadRow() {
    Widget buildInlineField(
        TextEditingController controller, String hint, {bool isFocused = false}) {
      return Container(
        height: 32,
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller,
          autofocus: isFocused,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onSubmitted: (_) => _saveNewLead(),
        ),
      );
    }

    return DataRow(
      color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
      cells: [
        const DataCell(
          Text('Auto', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ),
        DataCell(buildInlineField(_newNameCtrl, 'Enter Name', isFocused: true)),
        DataCell(buildInlineField(_newProgramCtrl, 'Enter Program')),
        DataCell(buildInlineField(_newCountryCtrl, 'Enter Country')),
        DataCell(
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _newStatus,
                isDense: true,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                ),
                items: ['New', 'In Progress', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _newStatus = v);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredLeads = _localLeads;
    if (_selectedStatus != 'All') {
      filteredLeads = filteredLeads
          .where((l) => l.status == _selectedStatus)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredLeads = filteredLeads.where((l) {
        return l.studentName.toLowerCase().contains(query) ||
            l.program.toLowerCase().contains(query) ||
            l.country.toLowerCase().contains(query) ||
            l.id.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Leads Sheet'),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black,
        elevation: 1,
        toolbarHeight: 48,
        actions: [
          if (_isAddingNewRow) ...[
            TextButton.icon(
              onPressed: _saveNewLead,
              icon: Icon(Iconex.light.check, color: AppColors.success, size: 18),
              label: const Text('Save', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Iconex.light.close, color: AppColors.error),
              onPressed: () => setState(() => _isAddingNewRow = false),
            ),
          ] else ...[
            IconButton(
              icon: Icon(Iconex.light.plus),
              onPressed: () {
                setState(() {
                  _isAddingNewRow = true;
                  _newNameCtrl.clear();
                  _newProgramCtrl.clear();
                  _newCountryCtrl.clear();
                  _newStatus = 'New';
                });
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // Header (Search + Tabs with Counts)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Search Field Row
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search leads...',
                      prefixIcon: Icon(Iconex.light.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(height: 8),
                // Tabs Row with Counts
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _statusFilters[index];
                      final isSelected = filter == _selectedStatus;
                      
                      // Calculate the count for this tab
                      int count = 0;
                      if (filter == 'All') {
                        count = _localLeads.length;
                      } else {
                        count = _localLeads.where((l) => l.status == filter).length;
                      }

                      return ChoiceChip(
                        label: Text(
                          '$filter ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedStatus = filter);
                        },
                      );
                    },
                  ),
                ),
              ],
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
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 40,
                      headingRowHeight: 40,
                      columnSpacing: 20,
                      dividerThickness: 1,
                      border: TableBorder.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Student Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Program',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Country',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        if (_isAddingNewRow) _buildNewLeadRow(),
                        ...filteredLeads.map((lead) {
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
                                Text(
                                  lead.id,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  lead.studentName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  lead.program,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  lead.country,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lead.status == 'New'
                                        ? AppColors.warningBackground
                                        : lead.status == 'Completed'
                                        ? AppColors.successBackground
                                        : AppColors.infoBackground,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    lead.status,
                                    style: TextStyle(
                                      color: lead.status == 'New'
                                          ? AppColors.warning
                                          : lead.status == 'Completed'
                                          ? AppColors.success
                                          : AppColors.info,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
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
