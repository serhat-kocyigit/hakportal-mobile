import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/case_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late Future<List<dynamic>> _future;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    final isLawyer = auth.user?['role'] == 'avukat';
    if (isLawyer) {
      _future = LawyerService.getAllClientFiles();
    } else {
      _future = CaseService.getMyCases();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loadData());
  }

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null) return '';
    final a = avatar.toString().trim();
    if (a.isEmpty) return '';
    if (a.startsWith('http')) return a;
    final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (a.startsWith('/')) return '$serverRoot$a';
    return '$serverRoot/$a';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Column(
          children: [
            // Arama Çubuğu (Görseldeki gibi)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Avukat veya dava ara...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Tab Bar (Görseldeki gibi)
            TabBar(
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Aktif Sohbetler'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Geçmiş Sohbetler'),
                    ],
                  ),
                ),
              ],
            ),

            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

                  final allCases = snapshot.data ?? [];
                  
                  // Arama Filtresi
                  final filtered = allCases.where((c) {
                    final name = (c['kullanici']?['ad'] ?? c['avukat']?['ad'] ?? '').toString().toLowerCase();
                    final type = (c['davaTuru'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase()) || type.contains(_searchQuery.toLowerCase());
                  }).toList();

                  return TabBarView(
                    children: [
                      _buildCasesList(filtered, isActive: true),
                      _buildCasesList(filtered, isActive: false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCasesList(List<dynamic> cases, {required bool isActive}) {
    final list = cases.where((c) {
      final status = (c['status'] ?? '').toString().toUpperCase();
      final isClosed = ['CLOSED', 'KAPANDI', 'REJECTED'].contains(status);
      return isActive ? !isClosed : isClosed;
    }).toList();

    if (list.isEmpty) {
      return Center(child: Text(isActive ? 'Aktif sohbet bulunamadı.' : 'Geçmiş sohbet bulunamadı.', style: const TextStyle(color: AppColors.textMuted)));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildWebStyleCard(list[i], isActive),
      ),
    );
  }

  Widget _buildWebStyleCard(dynamic c, bool isActive) {
    final auth = context.read<AuthProvider>();
    final isLawyer = auth.user?['role'] == 'avukat';
    
    final String caseId = (c['id'] ?? c['caseId'] ?? '').toString();
    final String davaTuru = c['davaTuru'] ?? 'Hukuki Dosya';
    final String status = (c['status'] ?? '').toString().toUpperCase();
    final String sehir = c['sehir'] ?? 'Ankara';
    
    double tahminiAlacak = 0.0;
    var rawAlacak = c['tahminiAlacak'];
    if (rawAlacak is num) tahminiAlacak = rawAlacak.toDouble();
    else if (rawAlacak is String) tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;

    String name = 'Müvekkil';
    String? avatar;
    if (isLawyer) {
      name = '${c['kullanici']?['ad'] ?? ''} ${c['kullanici']?['soyad'] ?? ''}'.trim();
      avatar = c['kullanici']?['avatar'];
    } else {
      name = '${c['avukat']?['ad'] ?? ''} ${c['avukat']?['soyad'] ?? ''}'.trim();
      avatar = c['avukat']?['avatar'];
    }
    if (name.isEmpty) name = isLawyer ? 'Müvekkil' : 'Avukat';

    final String lastMsg = c['sonMesaj'] ?? 'Henüz mesaj yok - Sohbeti başlatın';
    final String gonderen = c['sonMesajGonderen'] == auth.user?['id']?.toString() ? 'Siz' : (isLawyer ? 'Müvekkil' : 'Avukat');
    final String time = c['sonMesajTarih'] != null 
        ? _formatTime(c['sonMesajTarih'])
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: Avatar ve İsim
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(avatar, name[0]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                        if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    Text(davaTuru, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? Colors.grey : Colors.grey, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(isActive ? 'ACTIVE' : '🔒 Kapandı', style: TextStyle(color: isActive ? AppColors.textSecondary : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Orta Kısım: Son Mesaj Kutusu (Görseldeki gibi)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              lastMsg == 'Henüz mesaj yok - Sohbeti başlatın' ? lastMsg : '$gonderen: $lastMsg',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: lastMsg.contains('Henüz') ? AppColors.textMuted : AppColors.textSecondary, fontSize: 13.5),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Alt Kısım: Şehir, Tutar ve Buton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(sehir, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0).format(tahminiAlacak),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/chat/$caseId'),
                icon: Icon(isActive ? Icons.chat_bubble : Icons.menu_book, size: 16),
                label: Text(isActive ? 'Sohbeti Aç' : 'Geçmişi Gör'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Web'deki mor/mavi ton
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} sa önce';
      return DateFormat('dd MMM').format(date);
    } catch (_) {
      return '';
    }
  }

  Widget _buildAvatar(String? path, String initial) {
    final resolved = _resolveAvatarUrl(path);
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: ClipOval(
        child: resolved.isNotEmpty
          ? Image.network(resolved, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialAvatar(initial))
          : _buildInitialAvatar(initial),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      alignment: Alignment.center,
      child: Text(initial.toLowerCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 24)),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Text(error, style: const TextStyle(color: AppColors.danger)));
  }
}
