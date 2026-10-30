import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/models/api_spreadsheet_model.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';

class LeadDetailsScreen extends StatefulWidget {
  final String leadId;
  final String sheetId;
  final ApiRow? initialRow;
  final ApiSpreadsheet? sheet;
  final String? userRole;
  final bool initialEditMode;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
    this.sheetId = '',
    this.initialRow,
    this.sheet,
    this.userRole,
    this.initialEditMode = false,
  });

  @override
  State<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  ApiSpreadsheet? _sheet;
  ApiRow? _row;
  bool _isLoading = false;
  String? _error;
  bool _isEditing = false;
  bool _isSaving = false;
  String _userRole = 'Manager';
  int _currentUserId = 3;
  String _rowStatus = 'new';
  final Map<String, TextEditingController> _controllers = {};

  List<Map<String, dynamic>> _staffList = [];
  bool _isStaffLoading = false;

  bool get _isManager {
    final r = _userRole.toLowerCase();
    return r.contains('manager') || r.contains('admin');
  }

  bool get _isAccounts {
    final r = _userRole.toLowerCase();
    return r.contains('account');
  }

  bool get _isExecutive {
    final r = _userRole.toLowerCase();
    return r.contains('field') ||
        r.contains('exec') ||
        r.contains('backend') ||
        r.contains('office');
  }

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialEditMode;
    _initData();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    // 1. Fetch current user
    final user = await AuthService.getUser();
    if (user != null) {
      _currentUserId = int.tryParse(user['id']?.toString() ?? '3') ?? 3;
      _userRole =
          widget.userRole ?? user['group_name']?.toString() ?? 'Manager';
    } else {
      _userRole = widget.userRole ?? 'Manager';
    }

    // 2. Fetch staff list for potential reassignment
    _fetchStaffList();

    // 3. Initialize from passed parameters if available
    if (widget.sheet != null && widget.initialRow != null) {
      _sheet = widget.sheet;
      _row = widget.initialRow;
      _rowStatus = _row!.status.isNotEmpty ? _row!.status : 'new';
      _populateControllers();
      if (widget.initialEditMode) {
        _isEditing = true;
      }
      setState(() {});
      return;
    }

    // 4. Otherwise fetch from API
    await _fetchDetailsFromApi();
  }

  void _populateControllers() {
    if (_sheet == null || _row == null) return;
    for (var col in _sheet!.columns) {
      final existingText = _row!.getValue(col);
      if (_controllers.containsKey(col.columnName)) {
        _controllers[col.columnName]!.text = existingText;
      } else {
        _controllers[col.columnName] = TextEditingController(
          text: existingText,
        );
      }
    }
  }

  Future<void> _fetchStaffList() async {
    setState(() => _isStaffLoading = true);
    try {
      final res = await ApiService.getStaff();
      if (res['status'] == true && res['data'] != null) {
        _staffList = List<Map<String, dynamic>>.from(res['data']).where((s) {
          final gId = int.tryParse(s['group_id']?.toString() ?? '0') ?? 0;
          return gId == 4 || gId == 5;
        }).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isStaffLoading = false);
  }

  Future<void> _fetchDetailsFromApi() async {
    final sheetIdInt = int.tryParse(widget.sheetId);
    if (sheetIdInt == null || sheetIdInt <= 0) {
      setState(() {
        _error = 'Invalid sheet ID provided.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getSheetDetails(
        sheetId: sheetIdInt,
        userId: _currentUserId,
        role: _userRole,
      );

      if (!mounted) return;
      if (response['status'] == true && response['data'] != null) {
        final parsedSheet = ApiSpreadsheet.fromJson(response['data']);
        final targetRow = parsedSheet.rows.firstWhere(
          (r) => r.id.toString() == widget.leadId,
          orElse: () => parsedSheet.rows.isNotEmpty
              ? parsedSheet.rows.first
              : throw 'Lead not found in this sheet',
        );

        setState(() {
          _sheet = parsedSheet;
          _row = targetRow;
          _rowStatus = _row!.status.isNotEmpty ? _row!.status : 'new';
          _populateControllers();
          if (widget.initialEditMode) {
            _isEditing = true;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load lead details';
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

  Future<void> _handleSaveUpdates() async {
    if (_row == null || _sheet == null) return;
    setState(() => _isSaving = true);

    final updatedMap = <String, dynamic>{};
    for (var col in _sheet!.columns) {
      final ctrl = _controllers[col.columnName];
      if (ctrl != null) {
        final val = ctrl.text.trim();
        updatedMap[col.columnName] = val;
        if (col.columnKey.isNotEmpty) {
          updatedMap[col.columnKey] = val;
        }
      }
    }

    try {
      final response = await ApiService.updateRow(
        rowId: _row!.id,
        userId: _currentUserId,
        data: updatedMap,
        status: _rowStatus,
        role: _userRole,
      );

      if (!mounted) return;

      if (response['status'] == true) {
        final mergedData = Map<String, dynamic>.from(_row!.data)
          ..addAll(updatedMap);
        setState(() {
          _row = ApiRow(
            id: _row!.id,
            sheetId: _row!.sheetId,
            rowIndex: _row!.rowIndex,
            status: _rowStatus,
            createdBy: _row!.createdBy,
            assignedTo: _row!.assignedTo,
            assignedToName: _row!.assignedToName,
            createdByName: _row!.createdByName,
            data: mergedData,
            createdAt: _row!.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          );
          _populateControllers();
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lead details saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to update lead details',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating lead: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleQuickStatusChange(String newStatus) async {
    if (_row == null || _rowStatus == newStatus) return;
    final oldStatus = _rowStatus;
    setState(() => _rowStatus = newStatus);

    try {
      final res = await ApiService.updateRowStatus(
        rowId: _row!.id,
        status: newStatus,
      );
      if (!mounted) return;
      if (res['status'] == true) {
        setState(() {
          _row = ApiRow(
            id: _row!.id,
            sheetId: _row!.sheetId,
            rowIndex: _row!.rowIndex,
            status: newStatus,
            createdBy: _row!.createdBy,
            assignedTo: _row!.assignedTo,
            assignedToName: _row!.assignedToName,
            createdByName: _row!.createdByName,
            data: _row!.data,
            createdAt: _row!.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status changed to ${newStatus.toUpperCase()}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _rowStatus = oldStatus);
      }
    } catch (_) {
      if (mounted) setState(() => _rowStatus = oldStatus);
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('new')) return const Color(0xFF3B82F6);
    if (s.contains('progress')) return const Color(0xFFF59E0B);
    if (s.contains('contacted')) return const Color(0xFF8B5CF6);
    if (s.contains('closed') || s.contains('won') || s.contains('paid'))
      return AppColors.success;
    return const Color(0xFF64748B);
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showRowHistoryDialog() async {
    if (_row == null) return;
    final rowId = _row!.id;
    List<ApiEditHistory> historyItems = [];
    bool isLoading = true;

    // Check existing sheet history
    if (_sheet != null && _sheet!.editHistory.isNotEmpty) {
      historyItems = _sheet!.editHistory.where((h) => h.rowId == rowId).toList();
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void loadHistory() async {
              try {
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
              } catch (_) {}
              if (dialogCtx.mounted) {
                setDialogState(() => isLoading = false);
              }
            }

            if (isLoading) {
              loadHistory();
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lead Edit History',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          _row!.leadName,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 380,
                child: isLoading && historyItems.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : historyItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off_rounded, size: 44, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text(
                                  'No edit history recorded yet',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Any changes to this lead will be logged here.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: historyItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = historyItems[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.userName.isNotEmpty ? item.userName : 'User #${item.userId}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.userRole.isNotEmpty ? item.userRole : 'Staff',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          item.createdAt,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          '${item.columnName}: ',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                        ),
                                        if (item.oldValue.isNotEmpty) ...[
                                          Text(
                                            item.oldValue,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFEF4444),
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const Text(' -> ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                        ],
                                        Text(
                                          item.newValue.isNotEmpty ? item.newValue : '(empty)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(true),
          ),
          title: const Text(
            'Lead Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading lead details...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _row == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(false),
          ),
          title: const Text(
            'Lead Details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Lead not found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchDetailsFromApi,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = _row!;
    final sheet = _sheet!;
    final commonCols = sheet.columns.where((c) => c.isCommon).toList();
    final executiveCols = sheet.columns.where((c) => c.isExecutive).toList();
    final accountsCols = sheet.columns.where((c) => c.isAccounts).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Navigation Bar
              _buildTopBar(isDesktop),

              // 2. Main Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 36.0 : 16.0,
                    vertical: 20.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A. Hero Lead Header Card
                          _buildHeroHeader(row, isDesktop),
                          const SizedBox(height: 20),

                          // B. General Lead Information (Common)
                          if (commonCols.isNotEmpty) ...[
                            _buildSectionCard(
                              title: 'General Lead Information',
                              icon: Icons.person_outline_rounded,
                              accentColor: const Color(0xFF3B82F6),
                              columns: commonCols,
                              isDesktop: isDesktop,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // C. Executive Details (Manager + Executive)
                          if (executiveCols.isNotEmpty &&
                              (_isManager || _isExecutive)) ...[
                            _buildSectionCard(
                              title: 'Executive Details',
                              icon: Icons.work_outline_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              columns: executiveCols,
                              isDesktop: isDesktop,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // D. Accounts & Financials (Manager + Accounts)
                          if (accountsCols.isNotEmpty &&
                              (_isManager || _isAccounts)) ...[
                            _buildSectionCard(
                              title: 'Accounts & Financials',
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: const Color(0xFF10B981),
                              columns: accountsCols,
                              isDesktop: isDesktop,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // E. Lead Metadata & Assignment
                          _buildMetadataCard(row, sheet, isDesktop),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Bottom Sticky Bar when in Edit Mode
              if (_isEditing) _buildEditingBottomBar(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TOP BAR
  // =========================================================================
  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Back to Sheet',
            onPressed: () => context.pop(true),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(true),
                      child: Text(
                        _sheet?.title.isNotEmpty == true
                            ? _sheet!.title
                            : 'Sheet',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    Text(
                      _row?.leadName.isNotEmpty == true
                          ? _row!.leadName
                          : 'Lead Details',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  _row?.leadName.isNotEmpty == true
                      ? _row!.leadName
                      : 'Lead Information',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action Buttons (History only visible to Manager)
          if (!_isEditing && _isManager) ...[
            OutlinedButton.icon(
              onPressed: _showRowHistoryDialog,
              icon: const Icon(Icons.history_rounded, size: 17),
              label: const Text('Edit History'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                _populateControllers();
                setState(() => _isEditing = true);
              },
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Lead Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      _populateControllers();
                      setState(() => _isEditing = false);
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleSaveUpdates,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(_isSaving ? 'Saving...' : 'Save Updates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // HERO HEADER CARD
  // =========================================================================
  Widget _buildHeroHeader(ApiRow row, bool isDesktop) {
    final statusColor = _getStatusColor(_rowStatus);
    final phone = row.phoneNumber;
    final country = row.country;
    final workingAmt =
        row.data['Working Amount'] ?? row.data['working_amount'] ?? '';
    final agencyName = row.data['Agency Name'] ?? row.data['agency_name'] ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: isDesktop ? 34 : 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  row.leadName.isNotEmpty
                      ? row.leadName.substring(0, 1).toUpperCase()
                      : 'L',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: isDesktop ? 26 : 20,
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Title and Sub-details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          row.leadName,
                          style: TextStyle(
                            fontSize: isDesktop ? 24 : 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            _rowStatus.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lead #${row.id} • Row ${row.rowIndex}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick metadata chips
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (phone.isNotEmpty)
                          InkWell(
                            onTap: () =>
                                _copyToClipboard(phone, 'Phone number'),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (country.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                country,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        if (workingAmt.toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Working: ₹$workingAmt',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (agencyName.toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Agency: $agencyName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Dropdown selector
              if (isDesktop)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          [
                            'new',
                            'in_progress',
                            'contacted',
                            'closed',
                          ].contains(_rowStatus)
                          ? _rowStatus
                          : 'new',
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'new',
                          child: Text('Status: New'),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('Status: In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'contacted',
                          child: Text('Status: Contacted'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Status: Closed'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _handleQuickStatusChange(val);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION CARD (General, Executive, Accounts)
  // =========================================================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<ApiColumn> columns,
    required bool isDesktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${columns.length} fields',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Fields Grid
          Padding(
            padding: const EdgeInsets.all(22),
            child: _isEditing
                ? _buildEditFieldsGrid(columns, isDesktop)
                : _buildViewFieldsGrid(columns, isDesktop),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // VIEW MODE GRID
  // =========================================================================
  Widget _buildViewFieldsGrid(List<ApiColumn> columns, bool isDesktop) {
    final row = _row!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
        return Wrap(
          spacing: 20,
          runSpacing: 16,
          children: columns.map((col) {
            final val = row.getValue(col);
            final itemWidth = crossAxisCount == 2
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;

            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col.columnName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            val.isNotEmpty ? val : '—',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: val.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: val.isNotEmpty
                                  ? AppColors.textPrimary
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (val.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                        tooltip: 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyToClipboard(val, col.columnName),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================================
  // EDIT MODE GRID
  // =========================================================================
  Widget _buildEditFieldsGrid(List<ApiColumn> columns, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
        return Wrap(
          spacing: 20,
          runSpacing: 16,
          children: columns.map((col) {
            final itemWidth = crossAxisCount == 2
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;

            final ctrl = _controllers[col.columnName] ??=
                TextEditingController();
            final isBasicLeadCol =
                col.columnName.toLowerCase() == 'name' ||
                col.columnName.toLowerCase() == 'number' ||
                col.columnName.toLowerCase() == 'country';
            final canEdit = _isManager || !isBasicLeadCol;

            return SizedBox(
              width: itemWidth,
              child: col.options != null && col.options!.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      initialValue: col.options!.contains(ctrl.text)
                          ? ctrl.text
                          : (col.options!.isNotEmpty
                                ? col.options!.first
                                : null),
                      decoration: InputDecoration(
                        labelText: canEdit
                            ? col.columnName
                            : '${col.columnName} (Manager Only)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: canEdit
                            ? Colors.white
                            : const Color(0xFFF1F5F9),
                        suffixIcon: !canEdit
                            ? const Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              )
                            : null,
                      ),
                      items: col.options!
                          .map(
                            (opt) =>
                                DropdownMenuItem(value: opt, child: Text(opt)),
                          )
                          .toList(),
                      onChanged: canEdit
                          ? (val) {
                              if (val != null) ctrl.text = val;
                            }
                          : null,
                    )
                  : TextFormField(
                      controller: ctrl,
                      readOnly: !canEdit,
                      decoration: InputDecoration(
                        labelText: canEdit
                            ? col.columnName
                            : '${col.columnName} (Manager Only)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: canEdit
                            ? Colors.white
                            : const Color(0xFFF1F5F9),
                        suffixIcon: !canEdit
                            ? const Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              )
                            : null,
                      ),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================================
  // METADATA & ASSIGNMENT CARD
  // =========================================================================
  Widget _buildMetadataCard(ApiRow row, ApiSpreadsheet sheet, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 10),
              Text(
                'Sheet & Lead Management Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildMetaTile(
                'Sheet Title',
                sheet.title,
                Icons.table_chart_outlined,
              ),
              _buildMetaTile(
                'Created By',
                row.createdByName ?? sheet.creatorName,
                Icons.person_outline_rounded,
              ),
              _buildMetaTile(
                'Created At',
                (row.createdAt?.isNotEmpty == true
                    ? row.createdAt!
                    : sheet.createdAt),
                Icons.calendar_today_outlined,
              ),
              _buildMetaTile(
                'Last Updated',
                (row.updatedAt?.isNotEmpty == true
                    ? row.updatedAt!
                    : sheet.updatedAt),
                Icons.update_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTile(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // STICKY BOTTOM BAR IN EDIT MODE
  // =========================================================================
  Widget _buildEditingBottomBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36 : 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Editing lead details...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _populateControllers();
                            setState(() => _isEditing = false);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSaveUpdates,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save Updates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
