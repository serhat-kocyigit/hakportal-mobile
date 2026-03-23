import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_tab.dart';
import 'admin_lawyers_tab.dart';
import 'admin_users_tab.dart';
import 'admin_cases_tab.dart';
import 'admin_payments_tab.dart';
import 'admin_settings_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _currentIndex = 0;
  int _pendingLawyers = 0;
  String _adminName = '';

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _checkRole();
    _loadPendingLawyers();
  }

  Future<void> _loadPendingLawyers() async {
    try {
      final response = await ApiService.dio.get('/admin/istatistik');
      if (mounted) {
        setState(() {
          _pendingLawyers = response.data['bekleyenAvukat'] ?? 0;
        });
      }
    } catch (_) {}
  }

  void _checkRole() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return;
    }

    final user = auth.user;
    final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
    if (user != null && role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }
  }

  void _loadAdminInfo() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      if (mounted) setState(() => _adminName = '${user['ad'] ?? ''} ${user['soyad'] ?? ''}'.trim());
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (mounted) context.go('/');
  }

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', index: 0),
    _NavItem(icon: Icons.gavel_outlined, activeIcon: Icons.gavel, label: 'Avukatlar', index: 1),
    _NavItem(icon: Icons.people_outlined, activeIcon: Icons.people, label: 'Kullanıcılar', index: 2),
    _NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder, label: 'Davalar', index: 3),
    _NavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Ödemeler', index: 4),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Ayarlar', index: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              const Text('⚖️ ', style: TextStyle(fontSize: 20)),
              const Text('Hak', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Portal', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: const Text('Admin', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboardTab(onNavigate: (index) => setState(() => _currentIndex = index)),
          const AdminLawyersTab(),
          const AdminUsersTab(),
          const AdminCasesTab(),
          const AdminPaymentsTab(),
          const AdminSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.bgSurface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.danger, width: 2),
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _adminName.isNotEmpty ? _adminName : 'Admin',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Sistem Yöneticisi',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (ctx, i) {
                final item = _navItems[i];
                final isSelected = _currentIndex == item.index;
                return ListTile(
                  leading: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  onTap: () {
                    setState(() => _currentIndex = item.index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Çıkış Yap', style: TextStyle(color: AppColors.danger)),
            onTap: _logout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}
