import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconex_flutter/iconex_flutter.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';
import 'package:agency_head/core/services/auth_service.dart';

class MainWrapper extends StatefulWidget {
  final Widget child;

  const MainWrapper({super.key, required this.child});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() {
        _user = user;
      });
    }
  }

  bool get _isManager {
    final groupId = int.tryParse(_user?['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1;
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/sheets') || location == '/') return 0;
    if (location.startsWith('/executives')) return _isManager ? 1 : 0;
    if (location.startsWith('/profile')) return _isManager ? 2 : 1;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    if (_isManager) {
      switch (index) {
        case 0:
          context.go('/sheets');
          break;
        case 1:
          context.go('/executives');
          break;
        case 2:
          context.go('/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/sheets');
          break;
        case 1:
          context.go('/profile');
          break;
      }
    }
  }

  String _getUserRoleName() {
    if (_user == null) return 'User';
    final groupName = _user!['group_name']?.toString() ?? '';
    if (groupName.isNotEmpty) return groupName;

    final groupId = int.tryParse(_user!['group_id']?.toString() ?? '0') ?? 0;
    if (groupId == 6 || groupId == 1) return 'Manager';
    if (groupId == 5) return 'Office Staff';
    if (groupId == 4) return 'Field Executive';
    if (groupId == 2) return 'Accounts Staff';
    return 'Staff';
  }

  Color _getRoleBadgeColor() {
    final groupId = int.tryParse(_user?['group_id']?.toString() ?? '0') ?? 0;
    if (groupId == 6 || groupId == 1) return AppColors.primary;
    if (groupId == 5) return AppColors.accent;
    if (groupId == 4) return const Color(0xFFF59E0B);
    if (groupId == 2) return AppColors.success;
    return AppColors.textSecondary;
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out from Agency Head?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isManager = _isManager;

    if (isDesktop) {
      // Desktop / Web App Adaptive Layout with Side Navigation Bar
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _buildDesktopSidebar(context, selectedIndex),
            Expanded(
              child: Container(
                color: AppColors.background,
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Adaptive Layout with Bottom Navigation Bar
    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedIndex != 0) {
          context.go('/sheets');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => _onItemTapped(index, context),
                  backgroundColor: AppColors.surfaceVariant,
                  elevation: 0,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  items: isManager
                      ? [
                          BottomNavigationBarItem(
                            icon: Icon(Iconex.light.home),
                            activeIcon: Icon(Iconex.filled.home),
                            label: 'Sheets',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Iconex.light.users),
                            activeIcon: Icon(Iconex.filled.users),
                            label: 'Executives',
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.person_outline),
                            activeIcon: const Icon(Icons.person),
                            label: 'Profile',
                          ),
                        ]
                      : [
                          BottomNavigationBarItem(
                            icon: Icon(Iconex.light.home),
                            activeIcon: Icon(Iconex.filled.home),
                            label: 'Sheets',
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.person_outline),
                            activeIcon: const Icon(Icons.person),
                            label: 'Profile',
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, int selectedIndex) {
    final roleName = _getUserRoleName();
    final roleColor = _getRoleBadgeColor();
    final userName = _user?['name']?.toString() ?? 'Agency User';
    final userEmail = _user?['email']?.toString() ?? 'staff@agency.com';
    final isManager = _isManager;

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.table_chart_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agency Head',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'STUDENT AGENCY',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Role Chip Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: roleColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 16,
                    color: roleColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Role: $roleName',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // 3. Navigation Links
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'MAIN NAVIGATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _buildSidebarItem(
                  index: 0,
                  selectedIndex: selectedIndex,
                  title: isManager ? 'My Sheets & Leads' : 'Assigned Sheets',
                  icon: Iconex.light.home,
                  activeIcon: Iconex.filled.home,
                  onTap: () => _onItemTapped(0, context),
                ),
                if (isManager) ...[
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    index: 1,
                    selectedIndex: selectedIndex,
                    title: 'Executives & Staff',
                    icon: Iconex.light.users,
                    activeIcon: Iconex.filled.users,
                    onTap: () => _onItemTapped(1, context),
                  ),
                ],
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: isManager ? 2 : 1,
                  selectedIndex: selectedIndex,
                  title: 'Profile & Account',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  onTap: () => _onItemTapped(isManager ? 2 : 1, context),
                ),
              ],
            ),
          ),

          const Spacer(),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 4. User Footer with Logout
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: _confirmLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required int selectedIndex,
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required VoidCallback onTap,
  }) {
    final isSelected = index == selectedIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primary.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
