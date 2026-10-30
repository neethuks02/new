import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/models/api_spreadsheet_model.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';

class SpreadsheetScreen extends StatefulWidget {
  final String sheetId;

  const SpreadsheetScreen({super.key, required this.sheetId});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  ApiSpreadsheet? _sheet;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _currentUser;
  bool _isTableView = false; // Manager defaults to Cards view; staff defaults to Table view
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Inline Spreadsheet Row Adding & Editing State (No Modal Dialogs!)
  bool _isAddingInlineRow = false;
  int? _editingRowId;
  bool _isSavingInline = false;
  final Map<String, TextEditingController> _newRowControllers = {};
  String _newRowStatus = 'new';
  final Map<String, TextEditingController> _editRowControllers = {};
  String _editRowStatus = 'new';

  // Real-time Cell Auto-Save State
  Timer? _autoSaveTimer;
  Timer? _autoSaveNewLeadTimer;
  bool _isAutoSaving = false;
  String? _lastAutoSavedField;

  int get _sheetTotalCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => r.id > 0 || !r.leadName.startsWith('Lead #')).length;
  }

  int get _sheetNewCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && r.status.toLowerCase().contains('new')).length;
  }

  int get _sheetInProgressCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && (r.status.toLowerCase().contains('progress') || r.status.toLowerCase().contains('contacted'))).length;
  }

  int get _sheetClosedCount {
    if (_sheet == null) return 0;
    return _sheet!.rows.where((r) => (r.id > 0 || !r.leadName.startsWith('Lead #')) && (r.status.toLowerCase().contains('closed') || r.status.toLowerCase().contains('paid') || r.status.toLowerCase().contains('won'))).length;
  }

  int get _sheetTotalPipelineAmount {
    if (_sheet == null) return 0;
    int total = 0;
    for (var r in _sheet!.rows) {
      if (r.id <= 0 && r.leadName.startsWith('Lead #')) continue;
      final amt = r.data['Working Amount'] ?? r.data['working_amount'] ?? '';
      total += int.tryParse(amt.toString().replaceAll(',', '').replaceAll(' ', '').replaceAll('₹', '')) ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    final groupId = int.tryParse(user?['group_id']?.toString() ?? '0') ?? 0;
    final isStaffOrAccounts = (groupId == 4 || groupId == 5 || groupId == 2);

    final isDesktop = ResponsiveLayout.isDesktop(context);
    setState(() {
      _currentUser = user;
      // Default view: Table on Desktop or for Staff & Accounts
      _isTableView = isDesktop || isStaffOrAccounts;
    });

    _fetchSheetData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveNewLeadTimer?.cancel();
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    for (var ctrl in _newRowControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in _editRowControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  bool get _isManager {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 6 || groupId == 1 || groupName.contains('manager') || groupName.contains('admin');
  }

  bool get _isExecutive {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 4 || groupId == 5 || groupName.contains('executive') || groupName.contains('staff') || groupName.contains('feild') || groupName.contains('field');
  }

  bool get _isAccounts {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    return groupId == 2 || groupName.contains('account');
  }

  int get _currentUserId {
    return int.tryParse(_currentUser?['id']?.toString() ?? '3') ?? 3;
  }

  String _getUserRoleString() {
    final groupId = int.tryParse(_currentUser?['group_id']?.toString() ?? '0') ?? 0;
    final groupName = (_currentUser?['group_name'] ?? '').toString().toLowerCase();
    if (groupId == 6 || groupId == 1 || groupName.contains('manager') || groupName.contains('admin')) {
      return 'Manager';
    }
    if (groupId == 4 || groupName.contains('feild') || groupName.contains('field')) {
      return 'Feild Executive';
    }
    if (groupId == 5 || groupName.contains('backend') || groupName.contains('office')) {
      return 'BackEnd Staff';
    }
    if (groupId == 2 || groupName.contains('account')) {
      return 'Accounts';
    }
    final rawName = (_currentUser?['group_name'] ?? '').toString();
    if (rawName.isNotEmpty) return rawName;
    return 'Manager';
  }

  Future<void> _fetchSheetData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final id = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.getSheetDetails(
        sheetId: id,
        userId: _currentUserId,
        role: _getUserRoleString(),
      );

      if (!mounted) return;
      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _sheet = ApiSpreadsheet.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load sheet details';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ApiRow> get _filteredRows {
    if (_sheet == null) return [];
    return _sheet!.rows.where((row) {
      if (row.id <= 0 && row.leadName.startsWith('Lead #')) {
        // Skip padding dummy rows
        return false;
      }
      if (_selectedStatusFilter != 'all') {
        if (row.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = row.leadName.toLowerCase().contains(q);
        final phoneMatches = row.phoneNumber.toLowerCase().contains(q);
        final countryMatches = row.country.toLowerCase().contains(q);
        final dataMatches = row.data.values.any((v) => v.toString().toLowerCase().contains(q));
        return nameMatches || phoneMatches || countryMatches || dataMatches;
      }
      return true;
    }).toList();
  }

  // =========================================================================
  // INLINE SPREADSHEET ROW ADDING & EDITING (No Modal Dialogs!)
  // =========================================================================

  /// Activates the inline "New Lead" row right at the top of the spreadsheet grid.
  void _startInlineAddLead() {
    final cols = (_sheet != null && _sheet!.columns.isNotEmpty)
        ? _sheet!.columns
        : <ApiColumn>[];

    // Initialize or clear controllers for all columns
    for (var col in cols) {
      final colLower = col.columnName.trim().toLowerCase();
      final isStatus = colLower == 'status' || colLower.contains('status') || col.columnKey.toLowerCase().contains('status');
      final isDrop = _isDropdownColumn(col);
      String defaultText = '';
      if (isStatus) {
        defaultText = 'New';
      } else if (isDrop && col.options.isNotEmpty) {
        defaultText = col.options.first;
      }

      if (_newRowControllers.containsKey(col.columnKey)) {
        _newRowControllers[col.columnKey]!.text = defaultText;
      } else {
        _newRowControllers[col.columnKey] = TextEditingController(text: defaultText);
      }
      if (_newRowControllers.containsKey(col.columnName)) {
        _newRowControllers[col.columnName]!.text = defaultText;
      } else {
        _newRowControllers[col.columnName] = _newRowControllers[col.columnKey]!;
      }
    }
    _newRowStatus = 'new';

    setState(() {
      _isTableView = true; // Switch to table view so boxes are visible
      _isAddingInlineRow = true;
      _editingRowId = null; // Exit any existing row edit
    });

    if (_verticalController.hasClients) {
      _verticalController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _cancelInlineAddLead() {
    setState(() {
      _isAddingInlineRow = false;
    });
  }

  Future<void> _saveInlineAddLead() async {
    if (_sheet == null) return;

    final Map<String, dynamic> rowData = {};
    for (var col in _sheet!.columns) {
      final text = _newRowControllers[col.columnKey]?.text.trim() ??
                   _newRowControllers[col.columnName]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        rowData[col.columnName] = text;
        rowData[col.columnKey] = text;
      }
    }

    if (rowData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least Name or Number in the row boxes before saving.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Read status directly from text field or default to 'new'
    final rawStatus = (rowData['Status'] ?? rowData['status'] ?? _newRowStatus).toString();
    final statusVal = rawStatus.toLowerCase().replaceAll(' ', '_');
    rowData['Status'] = _formatStatusLabel(rawStatus);
    rowData['status'] = statusVal;

    setState(() => _isSavingInline = true);

    try {
      final sheetId = int.tryParse(widget.sheetId) ?? _sheet!.id;
      final response = await ApiService.addRow(
        sheetId: sheetId,
        createdBy: _currentUserId,
        status: statusVal,
        data: rowData,
      );

      if (!mounted) return;

      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead added successfully to spreadsheet!'),
            backgroundColor: AppColors.success,
          ),
        );
        _cancelInlineAddLead();
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to add lead.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding lead: '), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingInline = false);
      }
    }
  }

  /// Activates inline row editing directly in the grid boxes (No Dialog Box!)
  void _startInlineRowEdit(ApiRow row, {String? focusColumn}) {
    final cols = (_sheet != null && _sheet!.columns.isNotEmpty)
        ? _sheet!.columns
        : <ApiColumn>[];

    for (var col in cols) {
      String val = row.getValue(col);
      final colLower = col.columnName.trim().toLowerCase();
      final isStatus = colLower == 'status' || colLower.contains('status') || col.columnKey.toLowerCase().contains('status');
      if (isStatus && (val.isEmpty || val.toLowerCase() == 'new') && row.status.isNotEmpty) {
        val = _formatStatusLabel(row.status);
      } else if (isStatus && val.isNotEmpty) {
        val = _formatStatusLabel(val);
      }

      if (_editRowControllers.containsKey(col.columnKey)) {
        _editRowControllers[col.columnKey]!.text = val;
      } else {
        _editRowControllers[col.columnKey] = TextEditingController(text: val);
      }
      if (_editRowControllers.containsKey(col.columnName)) {
        _editRowControllers[col.columnName]!.text = val;
      } else {
        _editRowControllers[col.columnName] = _editRowControllers[col.columnKey]!;
      }
    }
    _editRowStatus = row.status.isNotEmpty ? row.status.toLowerCase() : 'new';

    setState(() {
      _isTableView = true;
      _editingRowId = row.id;
      _isAddingInlineRow = false;
    });
  }

  void _cancelInlineRowEdit() {
    setState(() {
      _editingRowId = null;
    });
  }

  Future<void> _saveInlineRowEdit(ApiRow row) async {
    if (_sheet == null) return;

    final Map<String, dynamic> updatedData = Map.from(row.data);
    for (var col in _sheet!.columns) {
      final text = _editRowControllers[col.columnKey]?.text.trim() ??
                   _editRowControllers[col.columnName]?.text.trim() ?? '';
      updatedData[col.columnName] = text;
      updatedData[col.columnKey] = text;
    }

    // Read status directly from text field or fallback to existing row status
    final rawStatus = (updatedData['Status'] ?? updatedData['status'] ?? _editRowStatus ?? row.status).toString();
    final statusVal = rawStatus.toLowerCase().replaceAll(' ', '_');
    updatedData['Status'] = _formatStatusLabel(rawStatus);
    updatedData['status'] = statusVal;

    setState(() => _isSavingInline = true);

    try {
      final response = await ApiService.updateRow(
        rowId: row.id,
        userId: _currentUserId,
        data: updatedData,
        status: statusVal,
        role: _getUserRoleString(),
      );

      if (!mounted) return;

      if (response['status'] == true) {
        row.data.addAll(updatedData);
        row.status = statusVal;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead updated successfully in spreadsheet!'),
            backgroundColor: AppColors.success,
          ),
        );
        _cancelInlineRowEdit();
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to update lead.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating lead: '), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingInline = false);
      }
    }
  }

  // =========================================================================
  // REAL-TIME AUTO-SAVE FOR EVERY CELL BOX (Requirement 3)
  // Auto-saves immediately upon typing (debounced) or pressing Enter/blur
  // =========================================================================
  void _triggerAutoSave(ApiRow row, ApiColumn col, String newValue) {
    _autoSaveTimer?.cancel();
    setState(() {
      _isAutoSaving = true;
    });

    _autoSaveTimer = Timer(const Duration(milliseconds: 700), () async {
      await _commitAutoSave(row, col, newValue, showToast: false);
    });
  }

  Future<void> _commitAutoSave(ApiRow row, ApiColumn col, String newValue, {bool showToast = true}) async {
    _autoSaveTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isAutoSaving = true;
    });

    final colLower = col.columnName.trim().toLowerCase();
    final keyLower = col.columnKey.trim().toLowerCase();
    final isStatus = colLower == 'status' || keyLower == 'status' || colLower.contains('status') || keyLower.contains('status');

    row.setValue(col, newValue);
    if (isStatus) {
      final statusVal = newValue.toLowerCase().replaceAll(' ', '_');
      row.status = statusVal;
      row.data['status'] = statusVal;
      row.data['Status'] = _formatStatusLabel(newValue);
    }

    try {
      if (isStatus) {
        await ApiService.updateRow(
          rowId: row.id,
          userId: _currentUserId,
          role: _getUserRoleString(),
          status: row.status,
          data: {
            col.columnKey: newValue,
            col.columnName: newValue,
            'Status': _formatStatusLabel(newValue),
            'status': row.status,
          },
        );
      } else {
        final res = await ApiService.updateCell(
          rowId: row.id,
          columnKey: col.columnKey,
          value: newValue,
          userId: _currentUserId,
        );
        if (res['status'] != true) {
          await ApiService.updateRow(
            rowId: row.id,
            userId: _currentUserId,
            role: _getUserRoleString(),
            data: {
              col.columnKey: newValue,
              col.columnName: newValue,
            },
          );
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isAutoSaving = false;
        _lastAutoSavedField = col.columnName;
      });

      if (showToast) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('${col.columnName} auto-saved', style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // =========================================================================
  // REAL-TIME AUTO-SAVE FOR NEW LEADS (No "Save Lead" button needed!)
  // Automatically creates the new lead in backend as the user types
  // =========================================================================
  void _triggerAutoSaveNewLead() {
    _autoSaveNewLeadTimer?.cancel();
    setState(() {
      _isAutoSaving = true;
    });

    _autoSaveNewLeadTimer = Timer(const Duration(milliseconds: 900), () async {
      await _commitAutoSaveNewLead();
    });
  }

  Future<void> _commitAutoSaveNewLead({bool showToast = false}) async {
    _autoSaveNewLeadTimer?.cancel();
    if (_sheet == null || !_isAddingInlineRow) return;

    final Map<String, dynamic> rowData = {};
    for (var col in _sheet!.columns) {
      final text = _newRowControllers[col.columnKey]?.text.trim() ??
                   _newRowControllers[col.columnName]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        rowData[col.columnName] = text;
        rowData[col.columnKey] = text;
      }
    }

    if (rowData.isEmpty) {
      if (mounted) setState(() => _isAutoSaving = false);
      return;
    }

    final rawStatus = (rowData['Status'] ?? rowData['status'] ?? _newRowStatus).toString();
    final statusVal = rawStatus.toLowerCase().replaceAll(' ', '_');
    rowData['Status'] = _formatStatusLabel(rawStatus);
    rowData['status'] = statusVal;

    if (!mounted) return;
    setState(() {
      _isAutoSaving = true;
      _isSavingInline = true;
    });

    try {
      final sheetId = int.tryParse(widget.sheetId) ?? _sheet!.id;
      final response = await ApiService.addRow(
        sheetId: sheetId,
        createdBy: _currentUserId,
        status: statusVal,
        data: rowData,
      );

      if (!mounted) return;

      if (response['status'] == true) {
        _isAddingInlineRow = false;
        await _fetchSheetData();
        if (mounted) {
          setState(() {
            _isAutoSaving = false;
            _isSavingInline = false;
            _lastAutoSavedField = 'New Lead';
          });
          if (showToast) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('New lead auto-saved successfully!'),
                  ],
                ),
                backgroundColor: Color(0xFF16A34A),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
              ),
            );
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
          _isSavingInline = false;
        });
      }
    }
  }

  /// Kept for backwards compatibility - redirects directly to inline add row!
  Future<void> _showAddLeadDialog() async {
    _startInlineAddLead();
  }

  // =========================================================================
  // ADD NEW COLUMN TO SHEET (Manager Action - Section 1.3)
  // Endpoint: POST api/add_column
  // =========================================================================
  Future<void> _showAddColumnDialog() async {
    final colNameController = TextEditingController();
    String colType = 'text';
    final optionsController = TextEditingController();
    bool isSubmitting = false;
    String? formError;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.view_column_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Add Custom Column', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a new custom column to this sheet beyond the 18 master fields.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (formError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(formError!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: colNameController,
                        decoration: InputDecoration(
                          labelText: 'Column Name *',
                          hintText: 'e.g. Passport Status, Remarks',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: colType,
                        decoration: InputDecoration(
                          labelText: 'Column Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'text', child: Text('Text')),
                          DropdownMenuItem(value: 'number', child: Text('Number')),
                          DropdownMenuItem(value: 'dropdown', child: Text('Dropdown')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => colType = val);
                        },
                      ),
                      if (colType == 'dropdown') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: optionsController,
                          decoration: InputDecoration(
                            labelText: 'Dropdown Options (comma-separated)',
                            hintText: 'e.g. Yes, No, Pending',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = colNameController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() => formError = 'Column Name is required.');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            formError = null;
                          });

                          try {
                            final sheetId = int.tryParse(widget.sheetId) ?? 1;
                            List<String>? opts;
                            if (colType == 'dropdown' && optionsController.text.trim().isNotEmpty) {
                              opts = optionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                            }

                            final res = await ApiService.addColumn(
                              sheetId: sheetId,
                              columnName: name,
                              columnType: colType,
                              options: opts,
                            );

                            if (!dialogContext.mounted) return;
                            if (res['status'] == true) {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Column added successfully!'), backgroundColor: AppColors.success),
                              );
                              _fetchSheetData();
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                formError = res['message'] ?? 'Failed to add column.';
                              });
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSubmitting = false;
                              formError = e.toString();
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Column'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ASSIGN SHEET TO FIELD/OFFICE EXECUTIVE (Manager Action)
  // Endpoint: POST api/assign_sheet
  // =========================================================================
  Future<void> _showAssignToStaffDialog() async {
    List<Map<String, dynamic>> staffList = [];
    bool isStaffLoading = true;
    String? staffError;
    int? selectedUserId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (staffList.isEmpty && isStaffLoading && staffError == null) {
              ApiService.getStaff().then((res) {
                if (dialogContext.mounted) {
                  if (res['status'] == true && res['data'] != null) {
                    final allStaff = List<Map<String, dynamic>>.from(res['data']);
                    // Filter for Field Executives (group 4) and Office Staff (group 5)
                    final execs = allStaff.where((s) {
                      final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                      return gId == 4 || gId == 5;
                    }).toList();

                    setDialogState(() {
                      staffList = execs.isNotEmpty ? execs : allStaff;
                      isStaffLoading = false;
                      if (staffList.isNotEmpty) {
                        selectedUserId = int.tryParse(staffList.first['id'].toString());
                      }
                    });
                  } else {
                    setDialogState(() {
                      staffError = res['message'] ?? 'Unable to load staff';
                      isStaffLoading = false;
                    });
                  }
                }
              }).catchError((err) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    staffError = err.toString();
                    isStaffLoading = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Assign Sheet to Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: isStaffLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : staffError != null
                        ? Text(staffError!, style: const TextStyle(color: AppColors.error))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select a Field Executive or Office Executive to take ownership of all leads in "${_sheet?.title}".',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                initialValue: selectedUserId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Executive',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: staffList.map((staff) {
                                  final name = staff['name'] ?? 'Staff';
                                  final group = staff['group_name'] ?? 'Executive';
                                  final id = int.tryParse(staff['id'].toString()) ?? 0;
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text('$name ($group)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedUserId = val);
                                },
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedUserId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          _assignStaff(selectedUserId!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Assign Sheet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignStaff(int staffUserId) async {
    try {
      final sheetId = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.assignSheetToStaff(
        sheetId: sheetId,
        userId: staffUserId,
        assignedBy: _currentUserId,
      );

      if (!mounted) return;
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Sheet successfully assigned to staff.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Assignment failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // =========================================================================
  // ASSIGN SHEET TO ACCOUNTS (Accounts Staff: group_id = 2)
  // Endpoint: GET api/get_staff?group_id=2 (or ?group_id=2&status=1)
  // Endpoint: POST api/assign_to_accounts
  // =========================================================================
  ApiAssignedUser? get _assignedAccountsUser {
    if (_sheet == null) return null;
    try {
      return _sheet!.assignedUsers.firstWhere(
        (u) => u.groupId == 2 || u.groupName.toLowerCase().contains('account'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAssignToAccountsDialog() async {
    List<Map<String, dynamic>> accountsList = [];
    bool isLoadingStaff = true;
    String? accountsError;
    int? selectedAccountsId;

    final currentAssignedAccount = _assignedAccountsUser;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (accountsList.isEmpty && isLoadingStaff && accountsError == null) {
              // Group ID 2 is strictly for Accounts Staff as per API documentation:
              // Endpoint: GET api/get_staff?group_id=2&status=1
              ApiService.getStaff(groupId: 2, status: 1).then((res) {
                if (dialogContext.mounted) {
                  List<Map<String, dynamic>> rawList = [];
                  if (res['status'] == true && res['data'] != null && (res['data'] as List).isNotEmpty) {
                    rawList = List<Map<String, dynamic>>.from(res['data']);
                  }

                  // Strictly filter: ONLY users where group_id == 2 (Accounts Staff)
                  final accountsOnly = rawList.where((s) {
                    final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                    return gId == 2;
                  }).toList();

                  if (accountsOnly.isNotEmpty) {
                    setDialogState(() {
                      accountsList = accountsOnly;
                      isLoadingStaff = false;
                      if (currentAssignedAccount != null &&
                          accountsList.any((a) => a['id'].toString() == currentAssignedAccount.userId.toString())) {
                        selectedAccountsId = currentAssignedAccount.userId;
                      } else {
                        selectedAccountsId = int.tryParse(accountsList.first['id'].toString());
                      }
                    });
                  } else {
                    // Fallback to fetch all group_id=2 (unfiltered status in case inactive or status != 1)
                    ApiService.getStaff(groupId: 2).then((fallbackRes) {
                      if (dialogContext.mounted) {
                        List<Map<String, dynamic>> fallbackRaw = [];
                        if (fallbackRes['status'] == true &&
                            fallbackRes['data'] != null &&
                            (fallbackRes['data'] as List).isNotEmpty) {
                          fallbackRaw = List<Map<String, dynamic>>.from(fallbackRes['data']);
                        }

                        // Strictly filter: ONLY users where group_id == 2
                        final fallbackAccountsOnly = fallbackRaw.where((s) {
                          final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
                          return gId == 2;
                        }).toList();

                        if (fallbackAccountsOnly.isNotEmpty) {
                          setDialogState(() {
                            accountsList = fallbackAccountsOnly;
                            isLoadingStaff = false;
                            if (currentAssignedAccount != null &&
                                accountsList.any((a) => a['id'].toString() == currentAssignedAccount.userId.toString())) {
                              selectedAccountsId = currentAssignedAccount.userId;
                            } else {
                              selectedAccountsId = int.tryParse(accountsList.first['id'].toString());
                            }
                          });
                        } else {
                          setDialogState(() {
                            accountsError = 'No Accounts staff found in system (group_id=2).';
                            isLoadingStaff = false;
                          });
                        }
                      }
                    }).catchError((err) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          accountsError = err.toString();
                          isLoadingStaff = false;
                        });
                      }
                    });
                  }
                }
              }).catchError((err) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    accountsError = err.toString();
                    isLoadingStaff = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: AppColors.success),
                  SizedBox(width: 10),
                  Text('Assign to Accounts Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: isLoadingStaff
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : accountsError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.error),
                                const SizedBox(width: 10),
                                Expanded(child: Text(accountsError!, style: const TextStyle(color: AppColors.error))),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assign "${_sheet?.title}" to an Accounts staff member (Group 2) for verification, payment tracking, and ledger entries.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              if (currentAssignedAccount != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Currently Assigned: ${currentAssignedAccount.name} (${currentAssignedAccount.email.isNotEmpty ? currentAssignedAccount.email : 'Accounts'})',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                initialValue: selectedAccountsId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Accounts Staff (Group 2)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                                items: accountsList.map((acc) {
                                  final name = acc['name'] ?? 'Accounts User';
                                  final email = acc['email'] ?? '';
                                  final id = int.tryParse(acc['id'].toString()) ?? 0;
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            email.isNotEmpty ? '$name ($email)' : name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedAccountsId = val);
                                },
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedAccountsId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          _assignAccounts(selectedAccountsId!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(currentAssignedAccount != null ? 'Update Accounts' : 'Assign to Accounts'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignAccounts(int accountsUserId) async {
    try {
      final sheetId = int.tryParse(widget.sheetId) ?? 1;
      final response = await ApiService.assignSheetToAccounts(
        sheetId: sheetId,
        accountsUserId: accountsUserId,
        assignedBy: _currentUserId,
      );

      if (!mounted) return;
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Sheet successfully assigned to Accounts staff.'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Accounts assignment failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // =========================================================================
  // VIEW EDIT HISTORY & AUDIT LOG (Task 3.3)
  // Options A & B: Sheet Details edit_history, api/sheet_history, api/row_history
  // =========================================================================
  Future<void> _showEditHistoryDialog({int? rowId, String? leadName}) async {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    List<ApiEditHistory> historyItems = [];
    bool isLoading = true;
    String searchFilter = '';
    final searchCtrl = TextEditingController();

    // Populate initial items from sheet if available (Option A)
    if (_sheet != null && _sheet!.editHistory.isNotEmpty) {
      if (rowId != null) {
        historyItems = _sheet!.editHistory.where((h) => h.rowId == rowId).toList();
      } else {
        historyItems = List.from(_sheet!.editHistory);
      }
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void loadHistory() async {
              try {
                if (rowId != null) {
                  // Dedicated Row History endpoint (Option B)
                  final res = await ApiService.getRowHistory(rowId: rowId);
                  if (dialogCtx.mounted && res['status'] == true && res['data'] != null) {
                    final list = (res['data'] as List)
                        .map((e) => ApiEditHistory.fromJson(e))
                        .toList();
                    setDialogState(() {
                      historyItems = list;
                      isLoading = false;
                    });
                    return;
                  }
                } else {
                  final sheetIdInt = int.tryParse(widget.sheetId) ?? (_sheet?.id ?? 0);
                  if (sheetIdInt > 0) {
                    // Dedicated Sheet History endpoint (Option B)
                    final res = await ApiService.getSheetHistory(sheetId: sheetIdInt);
                    if (dialogCtx.mounted && res['status'] == true && res['data'] != null) {
                      final list = (res['data'] as List)
                          .map((e) => ApiEditHistory.fromJson(e))
                          .toList();
                      setDialogState(() {
                        historyItems = list;
                        isLoading = false;
                      });
                      return;
                    }
                  }
                }
              } catch (_) {
                // Keep local sheet editHistory if dedicated call fails
              }
              if (dialogCtx.mounted) {
                setDialogState(() {
                  isLoading = false;
                });
              }
            }

            if (isLoading) {
              loadHistory();
            }

            final filteredList = historyItems.where((item) {
              if (searchFilter.trim().isEmpty) return true;
              final q = searchFilter.toLowerCase();
              return item.columnName.toLowerCase().contains(q) ||
                  item.userName.toLowerCase().contains(q) ||
                  item.userRole.toLowerCase().contains(q) ||
                  item.oldValue.toLowerCase().contains(q) ||
                  item.newValue.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 700 : double.infinity,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      rowId != null ? 'Lead Edit History' : 'Sheet Audit Log',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${historyItems.length} edits',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rowId != null
                                      ? (leadName != null ? 'Lead: $leadName (#$rowId)' : 'Lead #$rowId')
                                      : (_sheet?.title ?? 'All changes'),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search filter bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search by field, editor name, or value...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: searchFilter.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setDialogState(() => searchFilter = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          onChanged: (val) {
                            setDialogState(() => searchFilter = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Content List
                      Expanded(
                        child: isLoading && historyItems.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              )
                            : filteredList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 12),
                                        Text(
                                          searchFilter.isNotEmpty
                                              ? 'No matching changes found'
                                              : 'No edit history recorded yet',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Changes to Name, Number, Country, etc., will be tracked here.',
                                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredList.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final item = filteredList[index];
                                      return _buildHistoryItemCard(item);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryItemCard(ApiEditHistory item) {
    Color roleBadgeColor = const Color(0xFF64748B);
    final roleLower = item.userRole.toLowerCase();
    if (roleLower.contains('manager') || roleLower.contains('admin')) {
      roleBadgeColor = const Color(0xFF2563EB); // Blue
    } else if (roleLower.contains('feild') || roleLower.contains('field')) {
      roleBadgeColor = const Color(0xFFD97706); // Amber
    } else if (roleLower.contains('backend') || roleLower.contains('staff')) {
      roleBadgeColor = const Color(0xFF7C3AED); // Purple
    } else if (roleLower.contains('account')) {
      roleBadgeColor = const Color(0xFF059669); // Emerald
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Editor info + Time
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: roleBadgeColor.withValues(alpha: 0.15),
                child: Text(
                  item.userName.isNotEmpty ? item.userName[0].toUpperCase() : 'U',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: roleBadgeColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.userName.isNotEmpty ? item.userName : 'User #${item.userId}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.userRole.isNotEmpty ? item.userRole : 'Staff',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleBadgeColor),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.createdAt.isNotEmpty)
                Text(
                  item.createdAt,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Field Name + Row index tags
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      item.columnName.isNotEmpty ? item.columnName : 'Field',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              if (item.rowIndex > 0 || item.rowId > 0) ...[
                const SizedBox(width: 8),
                Text(
                  item.rowIndex > 0 ? 'Row #${item.rowIndex}' : 'Lead #${item.rowId}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Old vs New value diff
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OLD VALUE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.oldValue.isNotEmpty ? item.oldValue : '(empty)',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.oldValue.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                          decoration: item.oldValue.isNotEmpty ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW VALUE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.newValue.isNotEmpty ? item.newValue : '(empty)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.newValue.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SINGLE CELL BOX UPDATE (Inline Editing - Task 3.2)
  // Endpoint: POST api/update_cell
  // =========================================================================
  Future<void> _showQuickEditCellDialog(ApiRow row, ApiColumn col) async {
    final currentVal = row.getValue(col);
    final controller = TextEditingController(text: currentVal);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit ${col.columnName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lead: ${row.leadName} (Row #${row.rowIndex})',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: col.columnName,
                      hintText: 'Enter ${col.columnName}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newVal = controller.text.trim();
                          setDState(() => isSaving = true);
                          try {
                            final res = await ApiService.updateCell(
                              rowId: row.id,
                              columnKey: col.columnKey,
                              value: newVal,
                              userId: _currentUserId,
                            );
                            if (res['status'] == true) {
                              setState(() {
                                row.setValue(col, newVal);
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${col.columnName} updated successfully.'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                _fetchSheetData();
                              }
                            } else {
                              // Fallback to updateRow
                              await ApiService.updateRow(
                                rowId: row.id,
                                userId: _currentUserId,
                                role: _getUserRoleString(),
                                data: {
                                  col.columnKey: newVal,
                                  col.columnName: newVal,
                                },
                              );
                              setState(() {
                                row.setValue(col, newVal);
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _fetchSheetData();
                            }
                          } catch (e) {
                            setDState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // NAVIGATE TO FULL LEAD DETAILS PAGE
  // =========================================================================
  Future<void> _openLeadDetailsPage(ApiRow row, {bool editMode = false}) async {
    final result = await context.push(
      '/sheet/${widget.sheetId}/lead/${row.id}',
      extra: {
        'row': row,
        'sheet': _sheet,
        'sheetId': widget.sheetId,
        'userRole': _getUserRoleString(),
        'editMode': editMode,
      },
    );
    if (result == true || mounted) {
      _fetchSheetData();
    }
  }

  // =========================================================================
  // EDIT LEAD DETAILS (Redirects to Full Lead Details Page in Edit Mode)
  // Ensures NO dialog modal opens; full dedicated page is used!
  // =========================================================================
  Future<void> _showLeadDetailsDialog(ApiRow row) async {
    await _openLeadDetailsPage(row, editMode: true);
  }
  // =========================================================================
  // MAIN BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sheet?.title ?? 'Sheet #${widget.sheetId}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_sheet != null && _sheet!.description.isNotEmpty)
              Text(
                _sheet!.description,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: isDesktop
            ? [
                // DESKTOP WIDESCREEN ACTIONS (100% UNCHANGED)
                // Toggle View Button (Cards vs Table)
                IconButton(
                  tooltip: _isTableView ? 'Switch to Cards View' : 'Switch to Table View',
                  icon: Icon(
                    _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                  onPressed: _fetchSheetData,
                ),
                if (_isManager)
                  IconButton(
                    tooltip: 'Audit / Edit History',
                    icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
                    onPressed: () => _showEditHistoryDialog(),
                  ),
                if (_isAddingInlineRow || _editingRowId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _isSavingInline
                          ? null
                          : () {
                              if (_isAddingInlineRow) {
                                _saveInlineAddLead();
                              } else if (_editingRowId != null) {
                                final rows = _filteredRows;
                                final editingRow = rows.firstWhere(
                                  (r) => r.id == _editingRowId,
                                  orElse: () => _sheet!.rows.firstWhere((r) => r.id == _editingRowId, orElse: () => _sheet!.rows.first),
                                );
                                _saveInlineRowEdit(editingRow);
                              }
                            },
                      icon: _isSavingInline
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(
                        _isSavingInline
                            ? 'Saving...'
                            : 'Done (Auto-saved)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: OutlinedButton(
                      onPressed: _isSavingInline
                          ? null
                          : () {
                              if (_isAddingInlineRow) _cancelInlineAddLead();
                              if (_editingRowId != null) _cancelInlineRowEdit();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ] else ...[
                  if (_isManager) ...[
                    // Manager: Add Lead to Sheet (POST api/add_row)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: _showAddLeadDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Add Lead', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    // Manager: Assign to Staff
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: OutlinedButton.icon(
                        onPressed: _showAssignToStaffDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Assign Staff', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],

                // Real-time Auto-Save Cloud Status Indicator (Auto-saves all cell edits)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAutoSaving ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isAutoSaving ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAutoSaving ? Icons.sync_rounded : Icons.cloud_done_rounded,
                          size: 15,
                          color: _isAutoSaving ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isAutoSaving
                              ? 'Auto-saving...'
                              : (_lastAutoSavedField != null ? '$_lastAutoSavedField saved' : 'Auto-save on'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isAutoSaving ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            : [
                // MOBILE ADAPTIVE CLEAN ACTIONS (ZERO OVERFLOW)
                if (_isAddingInlineRow || _editingRowId != null) ...[
                  IconButton(
                    tooltip: 'Save',
                    icon: _isSavingInline
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
                        : const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                    onPressed: _isSavingInline
                        ? null
                        : () {
                            if (_isAddingInlineRow) {
                              _saveInlineAddLead();
                            } else if (_editingRowId != null) {
                              final rows = _filteredRows;
                              final editingRow = rows.firstWhere(
                                (r) => r.id == _editingRowId,
                                orElse: () => _sheet!.rows.firstWhere((r) => r.id == _editingRowId, orElse: () => _sheet!.rows.first),
                              );
                              _saveInlineRowEdit(editingRow);
                            }
                          },
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: _isSavingInline
                        ? null
                        : () {
                            if (_isAddingInlineRow) _cancelInlineAddLead();
                            if (_editingRowId != null) _cancelInlineRowEdit();
                          },
                  ),
                ],
                IconButton(
                  tooltip: _isTableView ? 'Switch to Cards' : 'Switch to Table',
                  icon: Icon(
                    _isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 22),
                  onPressed: _fetchSheetData,
                ),
                if (_isManager)
                  IconButton(
                    tooltip: 'Edit History',
                    icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary, size: 22),
                    onPressed: () => _showEditHistoryDialog(),
                  ),
                if (_isManager || _isExecutive)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'history') _showEditHistoryDialog();
                      if (val == 'add_lead') _showAddLeadDialog();
                      if (val == 'assign_staff') _showAssignToStaffDialog();
                    },
                    itemBuilder: (ctx) => [
                      if (_isManager)
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Audit / History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      if (_isManager) ...[
                        const PopupMenuItem(
                          value: 'add_lead',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Add Lead', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'assign_staff',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_alt_1_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Assign Staff', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSheetData,
                          child: const Text('Retry Loading'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (isDesktop) ...[
                      // Top Sheet KPI Dashboard Overview (Counts & Metrics on Desktop)
                      _buildSheetStatsOverview(isDesktop),

                      // Desktop Search & Filter Bar (Side-by-side)
                      _buildDesktopSearchFilterBar(),
                    ] else ...[
                      // Mobile Adaptive Search & Filter Section (Full-width search + counts chips)
                      _buildMobileTopSection(),
                    ],

                    // Main View (Cards View or Excel Table View)
                    Expanded(
                      child: _isTableView
                          ? _buildExcelTableView()
                          : _buildManagerCardsView(isDesktop),
                    ),
                  ],
                ),
      floatingActionButton: (_isManager || _isExecutive)
          ? FloatingActionButton.extended(
              onPressed: _showAddLeadDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Lead'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // =========================================================================
  // DESKTOP SEARCH & FILTER BAR (Widescreen Side-by-side, 100% UNCHANGED)
  // =========================================================================
  Widget _buildDesktopSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads in this sheet...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(width: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All', 'all'),
                const SizedBox(width: 6),
                _buildStatusChip('New', 'new'),
                const SizedBox(width: 6),
                _buildStatusChip('In Progress', 'in_progress'),
                const SizedBox(width: 6),
                _buildStatusChip('Closed', 'closed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE TOP SECTION (Full-Width Search + Scrollable Status Count Chips)
  // Clean, zero squishing, zero overflow, native mobile app presentation!
  // =========================================================================
  Widget _buildMobileTopSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads in this sheet...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),

          // Horizontal Filter Chips with Status Counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _buildMobileStatusChip(
                  label: 'All',
                  value: 'all',
                  count: _sheetTotalCount,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'New',
                  value: 'new',
                  count: _sheetNewCount,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'In Progress',
                  value: 'in_progress',
                  count: _sheetInProgressCount,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                _buildMobileStatusChip(
                  label: 'Closed',
                  value: 'closed',
                  count: _sheetClosedCount,
                  color: const Color(0xFF10B981),
                ),
                if (_sheetTotalPipelineAmount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF0369A1)),
                        const SizedBox(width: 2),
                        Text(
                          '₹$_sheetTotalPipelineAmount Pipeline',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatusChip({
    required String label,
    required String value,
    required int count,
    required Color color,
  }) {
    final isSelected = _selectedStatusFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedStatusFilter = value);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
      checkmarkColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatusFilter = value);
        }
      },
    );
  }

  // =========================================================================
  // TOP SHEET KPI DASHBOARD OVERVIEW (Counts & Metrics on Desktop)
  // =========================================================================
  Widget _buildSheetStatsOverview(bool isDesktop) {
    if (_sheet == null) return const SizedBox();

    final statItems = [
      _buildSheetStatCard(
        label: 'Total Leads',
        count: _sheetTotalCount.toString(),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        filterKey: 'all',
      ),
      _buildSheetStatCard(
        label: 'New Leads',
        count: _sheetNewCount.toString(),
        icon: Icons.fiber_new_rounded,
        color: const Color(0xFFF59E0B),
        filterKey: 'new',
      ),
      _buildSheetStatCard(
        label: 'In Progress',
        count: _sheetInProgressCount.toString(),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6),
        filterKey: 'in_progress',
      ),
      _buildSheetStatCard(
        label: 'Closed / Paid',
        count: _sheetClosedCount.toString(),
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        filterKey: 'closed',
      ),
      if (_sheetTotalPipelineAmount > 0)
        _buildSheetStatCard(
          label: 'Total Pipeline',
          count: '₹$_sheetTotalPipelineAmount',
          icon: Icons.currency_rupee_rounded,
          color: const Color(0xFF0EA5E9),
          filterKey: null,
        ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 12,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: isDesktop
          ? Row(
              children: statItems.map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: c,
                ),
              )).toList(),
            )
          : SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(width: 150, child: statItems[i]),
              ),
            ),
    );
  }

  Widget _buildSheetStatCard({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
    String? filterKey,
  }) {
    final isSelected = filterKey != null && _selectedStatusFilter == filterKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: filterKey != null
            ? () {
                setState(() => _selectedStatusFilter = filterKey);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW A: MANAGER BOX / CARDS VIEW (Clean, Modern, Box-Style Lead Cards)
  // =========================================================================
  Widget _buildManagerCardsView(bool isDesktop) {
    final rows = _filteredRows;

    if (rows.isEmpty) {
      final hasActiveFilter = _searchQuery.trim().isNotEmpty || _selectedStatusFilter != 'all';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasActiveFilter ? Icons.search_off_rounded : Icons.inbox_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                hasActiveFilter
                    ? (_searchQuery.trim().isNotEmpty
                        ? 'No leads matching "$_searchQuery"'
                        : 'No leads with status "$_selectedStatusFilter"')
                    : 'No leads matching criteria',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                hasActiveFilter ? 'Try clearing filters or search query.' : 'Try clearing search filters or add new leads.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedStatusFilter = 'all';
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Clear All Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              if (_isManager) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddLeadDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Candidate Lead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: 1200,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 16,
      ),
      child: isDesktop
          ? GridView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.getGridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 180,
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                return _buildLeadCard(rows[index]);
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildLeadCard(rows[index]);
              },
            ),
    );
  }

  Widget _buildLeadCard(ApiRow row) {
    final leadName = row.leadName;
    final phone = row.phoneNumber;
    final country = row.country;
    final status = row.status;

    // Optional executive & accounts fields preview
    final workingAmount = row.data['Working Amount'] ?? row.data['working_amount'] ?? '';
    final agencyName = row.data['Agency Name'] ?? row.data['agency_name'] ?? '';

    Color statusColor;
    if (status.toLowerCase().contains('new')) {
      statusColor = const Color(0xFF3B82F6);
    } else if (status.toLowerCase().contains('progress')) {
      statusColor = const Color(0xFFF59E0B);
    } else if (status.toLowerCase().contains('closed') || status.toLowerCase().contains('won')) {
      statusColor = AppColors.success;
    } else {
      statusColor = const Color(0xFF64748B);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openLeadDetailsPage(row),
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppColors.primary.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Initials avatar + Name + Status Pill
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      leadName.isNotEmpty ? leadName.substring(0, 1).toUpperCase() : 'L',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leadName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Country + Working Amount tags
              Row(
                children: [
                  if (country.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(country, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (workingAmount.toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹$workingAmount',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (agencyName.toString().isNotEmpty)
                    Expanded(
                      child: Text(
                        agencyName.toString(),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 3: Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lead #${row.id} • Row ${row.rowIndex}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _startInlineRowEdit(row),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                      if (_isManager) ...[
                        InkWell(
                          onTap: () => _showEditHistoryDialog(rowId: row.id, leadName: row.leadName),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 13, color: Color(0xFF64748B)),
                                SizedBox(width: 4),
                                Text('History', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openLeadDetailsPage(row, editMode: false),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Full Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW B: TRUE FULL-PAGE GOOGLE SHEETS GRID
  // Full rows & columns (data rows + empty rows filling the page)
  // Clean spreadsheet cells: TextField or Dropdown Selector directly in the box
  // =========================================================================

  bool _isDropdownColumn(ApiColumn col) {
    final colLower = col.columnName.trim().toLowerCase();
    final keyLower = col.columnKey.trim().toLowerCase();
    if (colLower == 'status' || keyLower == 'status' || colLower.contains('status') || keyLower.contains('status')) {
      return true;
    }
    return col.columnType.trim().toLowerCase() == 'dropdown' || col.options.isNotEmpty;
  }

  List<String> _getDropdownOptions(ApiColumn col, [String? currentVal]) {
    final colLower = col.columnName.trim().toLowerCase();
    final keyLower = col.columnKey.trim().toLowerCase();
    final isStatus = colLower == 'status' || keyLower == 'status' || colLower.contains('status') || keyLower.contains('status');

    List<String> result = [];
    if (isStatus) {
      result = ['New', 'In Progress', 'Closed', 'Won', 'Lost'];
      if (col.options.isNotEmpty) {
        for (final o in col.options) {
          if (!result.any((r) => r.toLowerCase() == o.toLowerCase())) {
            result.add(o);
          }
        }
      }
    } else if (col.options.isNotEmpty) {
      result = List<String>.from(col.options);
    } else {
      result = ['Yes', 'No', 'Pending'];
    }

    if (currentVal != null && currentVal.trim().isNotEmpty) {
      final formatted = isStatus ? _formatStatusLabel(currentVal) : currentVal.trim();
      if (!result.any((r) => r.toLowerCase() == formatted.toLowerCase())) {
        result.add(formatted);
      }
    }

    return result;
  }

  String _formatStatusLabel(String raw) {
    final lower = raw.trim().toLowerCase().replaceAll('_', ' ');
    if (lower == 'new') return 'New';
    if (lower == 'in progress' || lower == 'progress') return 'In Progress';
    if (lower == 'closed') return 'Closed';
    if (lower == 'won') return 'Won';
    if (lower == 'lost') return 'Lost';
    if (raw.isEmpty) return 'New';
    return raw
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('new')) return const Color(0xFF1D4ED8); // Blue
    if (lower.contains('progress')) return const Color(0xFFD97706); // Amber
    if (lower.contains('closed') || lower.contains('won')) return const Color(0xFF16A34A); // Green
    if (lower.contains('lost') || lower.contains('reject')) return const Color(0xFFDC2626); // Red
    return const Color(0xFF475569); // Slate
  }

  Color _getStatusBgColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('new')) return const Color(0xFFEFF6FF); // Light blue
    if (lower.contains('progress')) return const Color(0xFFFEF3C7); // Light amber
    if (lower.contains('closed') || lower.contains('won')) return const Color(0xFFDCFCE7); // Light green
    if (lower.contains('lost') || lower.contains('reject')) return const Color(0xFFFEE2E2); // Light red
    return const Color(0xFFF1F5F9); // Light slate
  }

  Future<void> _quickUpdateRowDropdown(ApiRow row, ApiColumn col, String newValue) async {
    final colLower = col.columnName.trim().toLowerCase();
    final keyLower = col.columnKey.trim().toLowerCase();
    final isStatus = colLower == 'status' || keyLower == 'status' || colLower.contains('status') || keyLower.contains('status');

    final Map<String, dynamic> updatedData = Map.from(row.data);
    updatedData[col.columnName] = newValue;
    updatedData[col.columnKey] = newValue;

    String newStatus = row.status;
    if (isStatus) {
      newStatus = newValue.toLowerCase().replaceAll(' ', '_');
      updatedData['Status'] = _formatStatusLabel(newValue);
      updatedData['status'] = newStatus;
    }

    setState(() {
      row.data[col.columnName] = newValue;
      row.data[col.columnKey] = newValue;
      if (isStatus) {
        row.data['Status'] = _formatStatusLabel(newValue);
        row.data['status'] = newStatus;
        row.status = newStatus;
      }
    });

    try {
      final response = await ApiService.updateRow(
        rowId: row.id,
        userId: _currentUserId,
        data: updatedData,
        status: newStatus,
        role: _getUserRoleString(),
      );

      if (!mounted) return;

      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${col.columnName} updated to "$newValue"'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchSheetData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to update ${col.columnName}.'),
            backgroundColor: AppColors.error,
          ),
        );
        _fetchSheetData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      _fetchSheetData();
    }
  }

  Widget _buildDropdownCell({
    required double width,
    required ApiColumn col,
    required String currentValue,
    required ValueChanged<String> onSelected,
    bool isStatus = false,
    bool isEditingRow = false,
  }) {
    final options = _getDropdownOptions(col, currentValue);
    final displayVal = isStatus
        ? _formatStatusLabel(currentValue.isNotEmpty ? currentValue : 'New')
        : (currentValue.isNotEmpty ? currentValue : (options.isNotEmpty ? options.first : ''));

    final isSelected = (String opt) {
      if (isStatus) {
        return opt.toLowerCase() == displayVal.toLowerCase() ||
               opt.toLowerCase().replaceAll(' ', '_') == currentValue.toLowerCase();
      }
      return opt.toLowerCase() == currentValue.toLowerCase();
    };

    return Container(
      width: width,
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Select ${col.columnName}',
        offset: const Offset(0, 36),
        padding: EdgeInsets.zero,
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        onSelected: onSelected,
        itemBuilder: (ctx) => options.map((opt) {
          final active = isSelected(opt);
          return PopupMenuItem<String>(
            value: opt,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (isStatus) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(opt),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active ? (isStatus ? _getStatusColor(opt) : AppColors.primary) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (active) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: isStatus ? _getStatusColor(opt) : AppColors.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: isStatus
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(displayVal),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayVal,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(displayVal),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    : Text(
                        displayVal.isNotEmpty ? displayVal : 'Select...',
                        style: TextStyle(
                          fontSize: 12,
                          color: displayVal.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getColumnWidth(ApiColumn col) {
    final name = col.columnName.trim();
    final nameLower = name.toLowerCase();

    // Requirement 2: Generous width based on text length so column names are 100% fully visible
    double width = (name.length * 11.5) + 85.0;

    if (nameLower.contains('candidate') || nameLower.contains('student')) {
      width = math.max(width, 210.0);
    }
    if (nameLower.contains('payment') || nameLower.contains('collected') || nameLower.contains('company')) {
      width = math.max(width, 205.0);
    }
    if (nameLower.contains('agency') || nameLower.contains('description')) {
      width = math.max(width, 195.0);
    }
    if (nameLower.contains('working amount') || nameLower.contains('advance')) {
      width = math.max(width, 185.0);
    }
    if (nameLower.contains('number') || nameLower.contains('phone')) {
      width = math.max(width, 175.0);
    }
    if (nameLower.contains('country')) {
      width = math.max(width, 160.0);
    }
    if (nameLower.contains('status')) {
      width = math.max(width, 165.0);
    }
    if (_isDropdownColumn(col)) {
      width = math.max(width, 175.0);
    }

    return width.clamp(160.0, 380.0);
  }

  Widget _buildExcelTableView() {
    if (_sheet == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final rows = _filteredRows;
    final cols = _sheet!.columns;

    // Google Sheets style: Displays data rows PLUS empty rows filling the full page (at least 35 rows)
    final totalRowCount = math.max(rows.length + (_isAddingInlineRow ? 22 : 20), 35);

    return Column(
      children: [
        // Google Sheets Clean Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_isAddingInlineRow) ...[
                        ElevatedButton.icon(
                          onPressed: _isSavingInline ? null : _saveInlineAddLead,
                          icon: _isSavingInline
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text(_isSavingInline ? 'Saving...' : 'Done (Auto-saved)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            elevation: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isSavingInline ? null : _cancelInlineAddLead,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Close', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          '⚡ Auto-Save Active — Type into any cell box below and it saves automatically!',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                        ),
                      ] else if (_editingRowId != null) ...[
                        Builder(builder: (ctx) {
                          final editingRow = rows.firstWhere(
                            (r) => r.id == _editingRowId,
                            orElse: () => _sheet!.rows.firstWhere((r) => r.id == _editingRowId, orElse: () => rows.first),
                          );
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isSavingInline ? null : () => _saveInlineRowEdit(editingRow),
                                icon: _isSavingInline
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_rounded, size: 16),
                                label: Text(_isSavingInline ? 'Saving...' : 'Done (Auto-saved)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  elevation: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _isSavingInline ? null : _cancelInlineRowEdit,
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Close', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                '⚡ Auto-Save Active — Row #$_editingRowId cell changes are saving automatically!',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                              ),
                            ],
                          );
                        }),
                      ] else ...[
                        if (_isManager) ...[
                          ElevatedButton.icon(
                            onPressed: _startInlineAddLead,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Row', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        const Text(
                          'Google Sheets Grid — Click any cell box to edit or click Add Row to insert a new lead',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '${rows.length} leads • ${cols.length} columns',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // Full Page Google Sheets Grid (Vertical & Horizontal Scrollbars)
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
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column Headers Row (Row 0)
                        _buildGridHeaderRow(cols),

                        // All Rows: Data rows + Active Add row + Empty Google Sheets rows filling the page
                        for (int i = 0; i < totalRowCount; i++)
                          _buildGridRow(
                            displayIndex: i,
                            rows: rows,
                            cols: cols,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Column Headers Row (A, B, C... / Column Names)
  Widget _buildGridHeaderRow(List<ApiColumn> cols) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row Index Header Box (#)
          Container(
            width: 50,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.5),
              ),
            ),
            child: const Text('#', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569))),
          ),

          // Each Column Header Box
          ...cols.map((col) {
            final width = _getColumnWidth(col);
            Color tagColor;
            if (col.isAccounts) {
              tagColor = const Color(0xFF10B981);
            } else if (col.isExecutive) {
              tagColor = const Color(0xFFF59E0B);
            } else {
              tagColor = const Color(0xFF3B82F6);
            }

            return Container(
              width: width,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: col.columnName,
                      preferBelow: false,
                      child: Text(
                        col.columnName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      col.userType.toUpperCase(),
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: tagColor),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Actions Column Header Box
          Container(
            width: 100,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.5),
              ),
            ),
            child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  // Unified Google Sheets Row Builder: Data Rows, Active Add Row, & Empty Rows
  Widget _buildGridRow({
    required int displayIndex,
    required List<ApiRow> rows,
    required List<ApiColumn> cols,
  }) {
    final bool hasData = displayIndex < rows.length;
    final ApiRow? rowData = hasData ? rows[displayIndex] : null;

    // Check if this row is the active inline add row (placed immediately after the existing data rows)
    final bool isInlineAddRow = _isAddingInlineRow && (displayIndex == rows.length);
    final bool isEditing = hasData && (_editingRowId == rowData!.id);

    final rowNumber = displayIndex + 1;

    return Container(
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row Index Box (#1, #2, #3... all the way down)
          Container(
            width: 50,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isInlineAddRow ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              border: const Border(
                right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
            ),
            child: isInlineAddRow
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                  )
                : Text(
                    '$rowNumber',
                    style: TextStyle(
                      fontWeight: isEditing ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11.5,
                      color: isEditing ? AppColors.primary : const Color(0xFF64748B),
                    ),
                  ),
          ),

          // Every Column Box: Direct Text Field or Dropdown Selector
          ...cols.map((col) {
            final width = _getColumnWidth(col);
            final colLower = col.columnName.trim().toLowerCase();
            final keyLower = col.columnKey.trim().toLowerCase();
            final isStatusCol = colLower == 'status' || colLower.contains('status') || keyLower.contains('status');
            final isDropdown = _isDropdownColumn(col);
            final isNumber = col.columnType == 'number' ||
                colLower.contains('amount') ||
                colLower.contains('charge') ||
                colLower.contains('profit') ||
                colLower.contains('credit') ||
                colLower.contains('cash') ||
                colLower == 'number';

            // Case A: Row is being edited
            if (isEditing) {
              final ctrl = _editRowControllers[col.columnKey] ?? _editRowControllers[col.columnName];
              if (isDropdown) {
                final currentVal = (ctrl?.text.isNotEmpty == true)
                    ? ctrl!.text
                    : (isStatusCol ? (rowData?.status ?? 'New') : (rowData?.getValue(col) ?? ''));
                return _buildDropdownCell(
                  width: width,
                  col: col,
                  currentValue: currentVal,
                  isStatus: isStatusCol,
                  isEditingRow: true,
                  onSelected: (selectedVal) {
                    setState(() {
                      if (ctrl != null) ctrl.text = selectedVal;
                      if (_editRowControllers.containsKey(col.columnKey)) _editRowControllers[col.columnKey]!.text = selectedVal;
                      if (_editRowControllers.containsKey(col.columnName)) _editRowControllers[col.columnName]!.text = selectedVal;
                      if (isStatusCol) _editRowStatus = selectedVal.toLowerCase().replaceAll(' ', '_');
                    });
                    if (rowData != null) {
                      _commitAutoSave(rowData, col, selectedVal, showToast: false);
                    }
                  },
                );
              }

              return Container(
                width: width,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w400),
                  cursorColor: const Color(0xFF1A73E8),
                  textInputAction: TextInputAction.done,
                  onChanged: (newVal) {
                    if (rowData != null) {
                      _triggerAutoSave(rowData, col, newVal);
                    }
                  },
                  onSubmitted: (newVal) {
                    if (rowData != null) {
                      _commitAutoSave(rowData, col, newVal, showToast: true);
                    }
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              );
            }

            // Case B: Row is the active inline add row
            if (isInlineAddRow) {
              final ctrl = _newRowControllers[col.columnKey] ?? _newRowControllers[col.columnName];
              if (isDropdown) {
                final currentVal = (ctrl?.text.isNotEmpty == true)
                    ? ctrl!.text
                    : (isStatusCol ? 'New' : (_getDropdownOptions(col).isNotEmpty ? _getDropdownOptions(col).first : ''));
                return _buildDropdownCell(
                  width: width,
                  col: col,
                  currentValue: currentVal,
                  isStatus: isStatusCol,
                  isEditingRow: true,
                  onSelected: (selectedVal) {
                    setState(() {
                      if (ctrl != null) ctrl.text = selectedVal;
                      if (_newRowControllers.containsKey(col.columnKey)) _newRowControllers[col.columnKey]!.text = selectedVal;
                      if (_newRowControllers.containsKey(col.columnName)) _newRowControllers[col.columnName]!.text = selectedVal;
                      if (isStatusCol) _newRowStatus = selectedVal.toLowerCase().replaceAll(' ', '_');
                    });
                    _triggerAutoSaveNewLead();
                  },
                );
              }

              return Container(
                width: width,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w400),
                  cursorColor: const Color(0xFF1A73E8),
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    _triggerAutoSaveNewLead();
                  },
                  onSubmitted: (_) {
                    _commitAutoSaveNewLead(showToast: true);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: isStatusCol ? 'new' : '',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              );
            }

            // Case C: Data Row not in edit mode
            if (hasData) {
              if (isDropdown) {
                final currentVal = isStatusCol
                    ? (rowData!.status.isNotEmpty ? rowData.status : rowData.getValue(col))
                    : rowData!.getValue(col);
                return _buildDropdownCell(
                  width: width,
                  col: col,
                  currentValue: currentVal,
                  isStatus: isStatusCol,
                  isEditingRow: false,
                  onSelected: (selectedVal) {
                    _quickUpdateRowDropdown(rowData, col, selectedVal);
                  },
                );
              }

              final val = rowData!.getValue(col);
              return InkWell(
                onTap: () {
                  _startInlineRowEdit(rowData, focusColumn: col.columnKey);
                },
                onLongPress: () {
                  _showQuickEditCellDialog(rowData, col);
                },
                child: Container(
                  width: width,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                      bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    ),
                  ),
                  child: Text(
                    val.isNotEmpty ? val : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: val.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      fontWeight: (colLower == 'name' || colLower == 'number') ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }

            // Case D: Empty Google Sheets Row (Clicking any box activates inline adding)
            return InkWell(
              onTap: () {
                _startInlineAddLead();
              },
              child: Container(
                width: width,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                ),
              ),
            );
          }),

          // Actions Box: Same height & border as cells
          Container(
            width: 100,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
            ),
            child: (isEditing || isInlineAddRow)
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isInlineAddRow ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isInlineAddRow ? 'New Lead' : 'Editing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isInlineAddRow ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  )
                : (hasData
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isManager) ...[
                            IconButton(
                              icon: const Icon(Icons.history_rounded, size: 15, color: Color(0xFF64748B)),
                              onPressed: () => _showEditHistoryDialog(rowId: rowData!.id, leadName: rowData.leadName),
                              tooltip: 'History',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            ),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF64748B)),
                            onPressed: () => _openLeadDetailsPage(rowData!, editMode: false),
                            tooltip: 'Details',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          ),
                        ],
                      )
                    : const SizedBox()),
          ),
        ],
      ),
    );
  }
}
