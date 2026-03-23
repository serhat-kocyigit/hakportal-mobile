import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminDashboardTab extends StatefulWidget {
  final Function(int) onNavigate;

  const AdminDashboardTab({super.key, required this.onNavigate});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _cityStats = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await ApiService.dio.get('/admin/istatistik');
      if (mounted) {
        setState(() {
          _stats = response.data;
          _isLoading = false;
        });
      }
      _loadCityStats();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCityStats() async {
    try {
      final response = await ApiService.dio.get('/admin/davalar');
      final davalar = response.data as List<dynamic>? ?? [];
      final counts = <String, int>{};
      for (final d in davalar) {
        final sehir = d['sehir'] ?? 'Bilinmiyor';
        counts[sehir] = (counts[sehir] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (mounted) {
        setState(() {
          _cityStats = sorted.take(8).map((e) => {'sehir': e.key, 'count': e.value}).toList();
        });
      }
    } catch (_) {}
  }

  String _formatNumber(dynamic n) {
    if (n == null) return '0';
    if (n is num) return NumberFormat.decimalPattern('tr-TR').format(n.toInt());
    return n.toString();
  }

  String _formatTL(dynamic n) {
    if (n == null) return '₺0';
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    return currency.format(n is num ? n : 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Onay Bekleyen Avukat Uyarısı
            if ((_stats['bekleyenAvukat'] ?? 0) > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '⚠️ ${_stats['bekleyenAvukat']} avukat profil onayı bekliyor.',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigate(1),
                      child: const Text('İncele →', style: TextStyle(color: AppColors.warning)),
                    ),
                  ],
                ),
              ),

            // İstatistik Kartları
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  icon: Icons.people,
                  iconColor: const Color(0xFF3A86FF),
                  value: _formatNumber(_stats['kullaniciSayisi']),
                  label: 'Kullanıcı',
                ),
                _buildStatCard(
                  icon: Icons.gavel,
                  iconColor: const Color(0xFF9D4EDD),
                  value: _formatNumber(_stats['avukatSayisi']),
                  label: 'Avukat',
                  subLabel: 'Onay bekleyen: ${_stats['bekleyenAvukat'] ?? 0}',
                  subColor: AppColors.warning,
                ),
                _buildStatCard(
                  icon: Icons.folder,
                  iconColor: const Color(0xFFFFB703),
                  value: _formatNumber(_stats['toplamDava']),
                  label: 'Toplam Dava',
                ),
                _buildStatCard(
                  icon: Icons.pending_actions,
                  iconColor: const Color(0xFFE63946),
                  value: _formatNumber(_stats['acikDava']),
                  label: 'Açık Dava',
                ),
                _buildStatCard(
                  icon: Icons.play_circle,
                  iconColor: const Color(0xFF00D9A3),
                  value: _formatNumber(_stats['aktifDava']),
                  label: 'Aktif Süreç',
                ),
                _buildStatCard(
                  icon: Icons.calculate,
                  iconColor: const Color(0xFF3A86FF),
                  value: _formatNumber(_stats['toplamHesaplama'] ?? 0),
                  label: 'Hesaplama',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Gelir Kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9A3), Color(0xFF00B386)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payments, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Toplam Platform Geliri',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatTL(_stats['toplamOdeme']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Hızlı Erişim
            const Text(
              '⚡ Hızlı Erişim',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _quickAction(Icons.gavel, 'Avukat Yönetimi', Colors.green, 1),
                  _quickAction(Icons.people, 'Kullanıcılar', Colors.blue, 2),
                  _quickAction(Icons.folder, 'Dava Listesi', Colors.orange, 3),
                  _quickAction(Icons.payments, 'Ödeme Geçmişi', Colors.purple, 4),
                  _quickAction(Icons.settings, 'Sistem Ayarları', Colors.grey, 5),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // En Çok Dava Açılan Şehirler
            if (_cityStats.isNotEmpty) ...[
              const Text(
                '📊 En Çok Dava Açılan Şehirler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: _cityStats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stat = entry.value;
                    final max = _cityStats.first['count'] as int;
                    final count = stat['count'] as int;
                    final percentage = max > 0 ? (count / max * 100) : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              stat['sehir'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: percentage / 100,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            count.toString(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onNavigate(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Icon(Icons.arrow_forward_ios, size: 12, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? subLabel,
    Color? subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (subLabel != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subLabel,
                style: TextStyle(fontSize: 11, color: subColor ?? AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
