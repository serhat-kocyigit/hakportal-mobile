import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../services/case_service.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

// Tab Imports
import 'calculator_tab.dart';
import 'profile_tab.dart';
import 'my_cases_tab.dart';
import 'messages_tab.dart';

class UserPanelScreen extends StatefulWidget {
  const UserPanelScreen({super.key});

  @override
  State<UserPanelScreen> createState() => _UserPanelScreenState();
}

class _UserPanelScreenState extends State<UserPanelScreen> {
  String _currentSection = 'davalarim';
  int _unreadNotifCount = 0;
  int _unreadMessageCount = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadNotifCount();
    await _loadMessageCount();
    _loadUserInfo();
  }

  Future<void> _loadNotifCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  Future<void> _loadMessageCount() async {
    try {
      final response = await ApiService.dio.get('/messages/unread-count');
      if (mounted) setState(() => _unreadMessageCount = response.data['count'] ?? 0);
    } catch (_) {}
  }

  void _loadUserInfo() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      setState(() => _userName = '${user['ad'] ?? ''} ${user['soyad'] ?? ''}'.trim());
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _NotificationModal(),
    ).then((_) => _loadNotifCount());
  }

  void _showSection(String section) {
    setState(() => _currentSection = section);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('⚖️ ', style: TextStyle(fontSize: 20)),
            const Text('Hak', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Portal', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
                onPressed: _showNotifications,
              ),
              if (_unreadNotifCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Text(
                      _unreadNotifCount > 9 ? '9+' : _unreadNotifCount.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildDrawer() {
    final isDavalarim = _currentSection == 'davalarim';
    final isYeniHesaplama = _currentSection == 'yeniHesaplama';
    final isMesajlar = _currentSection == 'mesajlarim';
    final isProfil = _currentSection == 'profil';

    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('👤', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName.isEmpty ? 'Kullanıcı' : _userName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Text('Kullanıcı Paneli', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('MENÜ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
              ),
            ),
            _buildDrawerItem('📋', 'Davalarım', isDavalarim, () => _showSection('davalarim')),
            _buildDrawerItem('🧮', 'Yeni Hesaplama', isYeniHesaplama, () => _showSection('yeniHesaplama')),
            _buildDrawerItem('💬', 'Mesajlarım', isMesajlar, () => _showSection('mesajlarim'), badge: _unreadMessageCount > 0 ? _unreadMessageCount : null),
            const Divider(height: 32, indent: 20, endIndent: 20, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('HESAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
              ),
            ),
            _buildDrawerItem('👤', 'Profilim', isProfil, () => _showSection('profil')),
            _buildDrawerItem('🏠', 'Ana Sayfa', false, () { Navigator.pop(context); context.push('/'); }),
            _buildDrawerItem('🚪', 'Çıkış Yap', false, _logout, isDanger: true),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('© 2024 HakPortal', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String icon, String title, bool isActive, VoidCallback onTap, {int? badge, bool isDanger = false}) {
    return ListTile(
      dense: true,
      leading: Text(icon, style: const TextStyle(fontSize: 18)),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isDanger ? AppColors.danger : (isActive ? AppColors.primaryLight : AppColors.textPrimary),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
              child: Text(badge > 9 ? '9+' : badge.toString(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      selected: isActive,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }

  Widget _buildBody() {
    switch (_currentSection) {
      case 'davalarim': return const MyCasesTab();
      case 'yeniHesaplama': return const CalculatorTab();
      case 'mesajlarim': return const MessagesTab();
      case 'profil': return const ProfileTab();
      default: return const MyCasesTab();
    }
  }
}

class _NotificationModal extends StatefulWidget {
  const _NotificationModal();

  @override
  State<_NotificationModal> createState() => _NotificationModalState();
}

class _NotificationModalState extends State<_NotificationModal> {
  List<dynamic> _notifs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifs = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🔔 Bildirimler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_notifs.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await NotificationService.markAllAsRead();
                          _loadData();
                        },
                        child: const Text('Tümünü Okundu İşaretle', style: TextStyle(color: AppColors.primaryLight, fontSize: 13)),
                      )
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _notifs.isEmpty
                  ? const Center(child: Text('Yeni bildiriminiz yok.', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final n = _notifs[idx];
                        final bool okunmadi = n['okundu'] == 0;
                        final dt = DateTime.tryParse(n['created_at']?.toString() ?? '');
                        final timeStr = dt != null ? DateFormat('dd.MM HH:mm').format(dt) : '';

                        return InkWell(
                          onTap: () async {
                            if (okunmadi) {
                              await NotificationService.markAsRead(n['id'].toString());
                              _loadData();
                            }
                            // İlgili linke yönlendirme logic'i (örn. panel/mesajlar vs)
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: okunmadi ? AppColors.accent.withValues(alpha: 0.05) : AppColors.bgSurface,
                              border: Border.all(color: okunmadi ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
                              borderRadius: BorderRadius.circular(12)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                     Text(n['baslik'] ?? 'Bildirim', style: TextStyle(fontWeight: okunmadi ? FontWeight.bold : FontWeight.w500)),
                                     Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(n['icerik'] ?? '', style: TextStyle(fontSize: 13, color: okunmadi ? AppColors.textPrimary : AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    )
              )
            ],
          )
    );
  }
}
