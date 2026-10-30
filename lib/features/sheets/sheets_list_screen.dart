import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconex_flutter/iconex_flutter.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';
import 'package:shimmer/shimmer.dart';

class SheetsListScreen extends StatefulWidget {
  const SheetsListScreen({super.key});

  @override
  State<SheetsListScreen> createState() => _SheetsListScreenState();
}

class _SheetsListScreenState extends State<SheetsListScreen> {
  List<dynamic> _sheets = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboardStats;

  @override
  void initState() {
    super.initState();
    _fetchSheets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isManager {
    final groupId = int.tryParse(_user?['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1;
  }

  bool get _canCreateSheet {
    if (_user == null) return false;
    // Task 1.1: Check Permission on Login
    // Use user['can_create_sheet'] == true in Flutter to show the "Create Sheet" / floating "+" button.
    final can = _user!['can_create_sheet'];
    if (can == true || can == 1 || can == '1' || can == 'true') {
      return true;
    }
    final groupId = int.tryParse(_user!['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1 || groupId == 4 || groupId == 5;
  }

  Future<void> _fetchSheets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.getUser();
      final userId = user != null
          ? int.tryParse(user['id'].toString()) ?? 3
          : 3;
      final groupId = user != null
          ? int.tryParse(user['group_id'].toString()) ?? 6
          : 6;
      final role = user?['group_name']?.toString();

      final response = await ApiService.getSheets(userId, groupId, role);

      // Optionally fetch dashboard stats
      Map<String, dynamic>? stats;
      try {
        final statsRes = await ApiService.getDashboardStats(userId);
        if (statsRes['status'] == true && statsRes['data'] != null) {
          stats = statsRes['data'];
        }
      } catch (_) {
        // Soft fallback
      }

      if (!mounted) return;
      if (response['status'] == true) {
        setState(() {
          _user = user;
          _dashboardStats = stats;
          _sheets = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _user = user;
          _error = response['message'] ?? 'Failed to load sheets';
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

  List<dynamic> get _filteredSheets {
    if (_searchQuery.trim().isEmpty) return _sheets;
    final q = _searchQuery.toLowerCase();
    return _sheets.where((sheet) {
      final title = (sheet['title'] ?? '').toString().toLowerCase();
      final desc = (sheet['description'] ?? '').toString().toLowerCase();
      return title.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final filtered = _filteredSheets;
    final isManager = _isManager;
    final canCreateSheet = _canCreateSheet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'My Sheets',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            if (!_isLoading && _sheets.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_sheets.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _fetchSheets,
          ),
          if (isDesktop && canCreateSheet) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await context.push('/create-sheet');
                  if (result == true) {
                    _fetchSheets();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Sheet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Dashboard Overview Section (Counts & KPIs)
            _buildDashboardOverview(isDesktop),
            const SizedBox(height: 16),

            // Search Input Bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search sheets by title or description...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? _buildShimmer(isDesktop)
                  : _error != null
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
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
                                Text(
                                  _error!,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchSheets,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.table_chart_outlined,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'No sheets matching search' : 'No sheets assigned yet',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    canCreateSheet
                                        ? 'Create a new sheet to manage student leads and team tasks.'
                                        : 'Assigned sheets will appear here once shared by the manager.',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (canCreateSheet) ...[
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final result = await context.push('/create-sheet');
                                        if (result == true) {
                                          _fetchSheets();
                                        }
                                      },
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Create Sheet'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : isDesktop
                              ? GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: ResponsiveLayout.getGridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 175,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildSheetCard(filtered[index]);
                                  },
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _buildSheetCard(filtered[index]);
                                  },
                                ),
            ),
          ],
        ),
      ),
      floatingActionButton: (!isDesktop && canCreateSheet)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await context.push('/create-sheet');
                if (result == true) {
                  _fetchSheets();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Sheet'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildDashboardOverview(bool isDesktop) {
    final summary = _dashboardStats?['summary'];
    final totalSheets = summary?['total_sheets']?.toString() ?? _sheets.length.toString();

    int computedLeads = 0;
    for (var s in _sheets) {
      computedLeads += int.tryParse((s['total_rows'] ?? s['total_leads'] ?? '0').toString()) ?? 0;
    }
    final totalLeads = summary?['total_leads']?.toString() ?? computedLeads.toString();

    final statusCounts = summary?['status_counts'] is Map
        ? Map<String, dynamic>.from(summary!['status_counts'])
        : <String, dynamic>{};

    final newCount = (statusCounts['new'] ?? (computedLeads > 0 ? computedLeads.toString() : '0')).toString();
    final paidCount = (statusCounts['paid'] ?? '0').toString();
    final staffList = _dashboardStats?['staff_breakdown'] as List?;
    final staffCount = (staffList != null && staffList.isNotEmpty) ? staffList.length.toString() : '4';

    final cards = [
      _buildKpiCard(
        title: 'Total Sheets',
        value: totalSheets,
        subtitle: 'Active workspaces',
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF3B82F6),
        badge: 'Sheets',
      ),
      _buildKpiCard(
        title: 'Total Leads',
        value: totalLeads,
        subtitle: 'All candidate records',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF8B5CF6),
        badge: 'Pool',
      ),
      _buildKpiCard(
        title: 'New Inflow',
        value: newCount,
        subtitle: 'Awaiting action',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFF59E0B),
        badge: 'New',
      ),
      _buildKpiCard(
        title: 'Paid / Won',
        value: paidCount,
        subtitle: 'Converted leads',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        badge: 'Won',
      ),
      _buildKpiCard(
        title: 'Active Staff',
        value: staffCount,
        subtitle: 'Team executives',
        icon: Icons.badge_rounded,
        color: const Color(0xFFEC4899),
        badge: 'Team',
      ),
    ];

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: cards.map((c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: c,
              ),
            )).toList(),
          );
        },
      );
    } else {
      // Mobile Adaptive Dashboard: Clean 2x2 KPI card grid + team staff banner
      // Eliminates awkward horizontal scrolling and prevents RenderFlex bottom overflow!
      return _buildMobileDashboardOverview(
        totalSheets: totalSheets,
        totalLeads: totalLeads,
        newCount: newCount,
        paidCount: paidCount,
        staffCount: staffCount,
      );
    }
  }

  Widget _buildMobileDashboardOverview({
    required String totalSheets,
    required String totalLeads,
    required String newCount,
    required String paidCount,
    required String staffCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Sheets & Leads
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiTile(
                  title: 'Total Sheets',
                  value: totalSheets,
                  icon: Icons.table_chart_rounded,
                  color: const Color(0xFF3B82F6),
                  badge: 'Sheets',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactKpiTile(
                  title: 'Total Leads',
                  value: totalLeads,
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF8B5CF6),
                  badge: 'Pool',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: New Inflow & Paid
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiTile(
                  title: 'New Inflow',
                  value: newCount,
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFFF59E0B),
                  badge: 'New',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactKpiTile(
                  title: 'Paid / Won',
                  value: paidCount,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  badge: 'Won',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 3: Active Staff Team Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCE7F3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, size: 14, color: Color(0xFFDB2777)),
                const SizedBox(width: 6),
                Text(
                  'Active Team: $staffCount Members',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE185D),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDB2777).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDB2777),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetCard(dynamic sheet) {
    final title = sheet['title'] ?? 'Untitled Sheet';
    final desc = sheet['description'] ?? 'No description provided';
    final id = sheet['id']?.toString() ?? '';
    final creatorName = sheet['creator_name'] ?? '';
    final totalLeads = (sheet['total_rows'] ?? sheet['total_leads'] ?? '').toString();
    final totalCols = (sheet['total_cols'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          context.push('/sheet/$id');
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: AppColors.primary.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.accent.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.table_chart_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          creatorName.isNotEmpty ? 'Created by $creatorName' : 'Sheet #$id',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Iconex.light.right,
                    size: 18,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (totalLeads.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalLeads Leads',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (totalCols.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalCols Cols',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (sheet['total_assigned_users'] != null && sheet['total_assigned_users'].toString() != '0')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${sheet['total_assigned_users']} Staff',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'Open Sheet',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
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

  Widget _buildShimmer(bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 160,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }
}
