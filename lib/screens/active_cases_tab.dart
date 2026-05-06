import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/case_report_widget.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/case_service.dart';
import '../services/api_service.dart';

class ActiveCasesTab extends StatefulWidget {
  const ActiveCasesTab({super.key});

  @override
  State<ActiveCasesTab> createState() => _ActiveCasesTabState();
}

class _ActiveCasesTabState extends State<ActiveCasesTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _future = _fetchActiveFiles();
  }

  Future<List<dynamic>> _fetchActiveFiles() async {
    final files = await LawyerService.getAllClientFiles();
    return files.where((f) => !['CLOSED', 'KAPANDI', 'CANCELED', 'REDDEDILDI'].contains(f['status'])).toList();
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
    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

          final cases = snapshot.data ?? [];
          if (cases.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) => _buildDavaCard(ctx, cases[i], dateFormat, currencyFormat),
          );
        },
      ),
    );
  }

  Widget _buildDavaCard(BuildContext context, dynamic t, DateFormat df, NumberFormat cf) {
    final status = t['status'] ?? 'ACTIVE';
    final String davaId = (t['id'] ?? t['caseId'] ?? '').toString();
    final String davaTuru = t['davaTuru'] ?? 'Hukuki Dava';
    final String sehir = t['sehir'] ?? '';
    final String dateStr = t['createdAt'] != null ? df.format(DateTime.parse(t['createdAt'])) : '';
    
    double tahminiAlacak = 0.0;
    if (t['tahminiAlacak'] is num) tahminiAlacak = t['tahminiAlacak'].toDouble();
    else if (t['tahminiAlacak'] is String) tahminiAlacak = double.tryParse(t['tahminiAlacak']) ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Web'deki gibi)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(davaTuru, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text('$sehir · $dateStr', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Müvekkil Bilgisi (Web'deki gibi premium kutu)
                if (t['kullanici'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        _buildAvatar(t['kullanici']?['avatar'], t['kullanici']?['ad']?[0] ?? 'M'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MÜVEKKİL', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                              Text('${t['kullanici']['ad']} ${t['kullanici']['soyad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (t['kullanici']['email'] != null) ...[
                                Text('📧 ${t['kullanici']['email']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                Text('📞 ${t['kullanici']['telefon'] ?? '—'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ] else
                                const Text('🔒 İletişim bilgileri henüz gizli', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Dava Detayları Açılır Bölüm
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('📊 Dava Analizi ve Detaylar', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    children: [
                      CaseReportWidget(data: t['hesaplamaVerisi'], c: Map<String, dynamic>.from(t), isLawyer: true),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Aksiyonlar (Web'deki buton renkleri ve mantığıyla)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (['ACTIVE', 'PRE_CASE_REVIEW'].contains(status))
                  _buildActionButton(
                    '✅ Evraklar Yeterli (Vekalet İste)', 
                    const Color(0xFF00D9A3), 
                    () => _requestUserAuth(davaId)
                  ),
                if (status == 'AUTHORIZED')
                  _buildActionButton(
                    '🏛️ Dava Açıldı (Dosya No Gir)', 
                    const Color(0xFFFFB300), 
                    () => _fileInCourt(davaId)
                  ),
                if (status == 'DAVA_NO_BEKLIYOR')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
                    ),
                    child: const Text('⏳ Dosya numarası müvekkile bildirildi. Müvekkil doğrulaması bekleniyor...', 
                      style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
                  ),
                if (['FILED_IN_COURT', 'IN_PROGRESS', 'DURUSMA'].contains(status))
                  _buildActionButton(
                    '💰 Tahsilat Bildir (Dava Bitti)', 
                    const Color(0xFF4CAF50), 
                    () => _reportCollectionModal(davaId),
                    textColor: Colors.white
                  ),
                
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push('/chat/$davaId'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('💬 Müvekkilimle Mesajlaş', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label = status;
    switch (status) {
      case 'PRE_CASE_REVIEW': label = '🧐 Ön İnceleme'; break;
      case 'PENDING_USER_AUTH': label = '⏳ Vekalet İsteğinde'; break;
      case 'AUTHORIZED': label = '✅ Vekalet Onaylı'; break;
      case 'FILED_IN_COURT': label = '🏛️ Dava Açıldı'; break;
      case 'ACTIVE': label = '🟢 Aktif'; break;
      case 'DAVA_NO_BEKLIYOR': label = '🏛️ Dosya No Bekleniyor'; break;
      case 'IN_PROGRESS': label = '💬 İşlemde'; break;
      case 'DURUSMA': label = '⚖️ Duruşma'; break;
      case 'TAHSIL': label = '💰 Tahsilat'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed, {Color textColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildAvatar(String? path, String initial) {
    final resolved = _resolveAvatarUrl(path);
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
      child: ClipOval(
        child: resolved.isNotEmpty 
          ? Image.network(resolved, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialAvatar(initial))
          : _buildInitialAvatar(initial),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)));
  }

  // --- ACTIONS ---
  Future<void> _requestUserAuth(String caseId) async {
    final confirmed = await _showConfirmDialog('Vekalet İste', 'Müvekkilinizden resmi vekaletname talep ediyorsunuz. Onaylıyor musunuz?');
    if (confirmed) {
      try {
        await CaseService.updateStatus(caseId: caseId, status: 'PENDING_USER_AUTH', aciklama: 'Avukat vekaletname onaylamanızı bekliyor.');
        _refresh();
      } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _fileInCourt(String caseId) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('🏛️ Dava Açıldı', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Dosya Numarası (Örn: 2024/123 Esas)'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla')),
        ],
      ),
    );
    if (confirmed == true && controller.text.isNotEmpty) {
      try {
        await CaseService.updateStatus(caseId: caseId, status: 'DAVA_NO_BEKLIYOR', aciklama: 'Dava açıldı. Dosya No: ${controller.text}', extra: {'davaNo': controller.text});
        _refresh();
      } catch (e) { _showError(e.toString()); }
    }
  }

  void _reportCollectionModal(String caseId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('💰 Tahsilat Bildir', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tahsil Edilen Toplam Tutar (TL)'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                await CaseService.updateStatus(caseId: caseId, status: 'TAHSIL', aciklama: 'Dava sonuçlandı. ${controller.text} TL tahsilat yapıldı.');
                Navigator.pop(ctx);
                _refresh();
              } catch (e) { _showError(e.toString()); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Bildir'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent), child: const Text('Evet', style: TextStyle(color: Colors.black))),
        ],
      )
    ) ?? false;
  }

  void _showError(String err) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger));
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.gavel, size: 64, color: AppColors.textMuted), SizedBox(height: 16), Text('Aktif davanız bulunmuyor.', style: TextStyle(color: AppColors.textSecondary))]));
  }

  Widget _buildErrorState(String error) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: AppColors.danger), const SizedBox(height: 16), Text(error, textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _refresh, child: const Text('Tekrar Dene'))])));
  }
}
