import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/case_service.dart';
import '../services/lawyer_service.dart';
import '../widgets/case_report_widget.dart';

class MyCasesTab extends StatefulWidget {
  const MyCasesTab({super.key});

  @override
  State<MyCasesTab> createState() => _MyCasesTabState();
}

class _MyCasesTabState extends State<MyCasesTab> {
  late Future<List<dynamic>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _casesFuture = CaseService.getMyCases();
  }

  Future<void> _refresh() async {
    setState(() => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final df = DateFormat('dd.MM.yyyy');

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: FutureBuilder<List<dynamic>>(
        future: _casesFuture,
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
            itemBuilder: (ctx, i) => _buildUserDavaCard(ctx, cases[i], df, cf),
          );
        },
      ),
    );
  }

  Widget _buildUserDavaCard(BuildContext context, dynamic d, DateFormat df, NumberFormat cf) {
    final status = d['status'] ?? 'OPEN';
    final String davaId = d['id'].toString();
    final String davaTuru = d['davaTuru'] ?? 'Kıdem/İhbar Davası';
    final String sehir = d['sehir'] ?? '';
    final String dateStr = d['createdAt'] != null ? df.format(DateTime.parse(d['createdAt'])) : '';
    
    double tahminiAlacak = 0.0;
    if (d['tahminiAlacak'] is num) tahminiAlacak = d['tahminiAlacak'].toDouble();
    else if (d['tahminiAlacak'] is String) tahminiAlacak = double.tryParse(d['tahminiAlacak']) ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                      Text('$sehir • $dateStr', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tahmini Alacak', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    Text(cf.format(tahminiAlacak), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bekleyen Talepler', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    Text('${d['bekleyenTalepSayisi'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Analiz
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('📊 Dava Detaylarını Gör', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    children: [
                      CaseReportWidget(data: d['hesaplamaVerisi'], c: Map<String, dynamic>.from(d)),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Aksiyonlar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildDavaActions(d),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDavaActions(dynamic d) {
    final status = d['status'] ?? 'OPEN';
    final String davaId = d['id'].toString();
    List<Widget> actions = [];

    if (status == 'KAYITLI' || status == 'OPEN') {
      actions.add(ElevatedButton(
        onPressed: () => _showLawyerSearch(d['sehir']?.toString() ?? '', davaId),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
        child: const Text('🔍 Avukat Bul & İletişime Geç', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      actions.add(const SizedBox(height: 4));
      actions.add(TextButton(
        onPressed: () => _deleteCase(davaId),
        child: const Text('🗑️ Dosyayı Sil', style: TextStyle(color: AppColors.danger)),
      ));
    }
    else if (status == 'AVUKAT_ARANIYOR') {
      actions.add(_buildInfoBox('🧐 Yanıt Bekleniyor...', 'Avukata gönderdiğiniz iletişim talebi değerlendiriliyor.', const Color(0xFFFFC107)));
      actions.add(OutlinedButton(
        onPressed: () => _showLawyerSearch(d['sehir']?.toString() ?? '', davaId),
        child: const Text('Başka Avukat Ara'),
      ));
    }
    else if (status == 'PENDING_USER_AUTH') {
      actions.add(_buildInfoBox('📋 Avukat Vekalet İstiyor', 'Avukatınız evrakları yeterli buldu ve sizden resmi vekalet onayını bekliyor.', AppColors.accent));
      actions.add(ElevatedButton(
        onPressed: () => _approveAuth(davaId),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9A3), foregroundColor: Colors.black),
        child: const Text('✅ Vekaleti Onayla ve Yetkilendir', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(OutlinedButton(onPressed: () => context.push('/chat/$davaId'), child: const Text('💬 Mesajlaş')));
    }
    else if (status == 'DAVA_NO_BEKLIYOR') {
      final davaNo = d['davaNo'] ?? 'Belirtilmedi';
      actions.add(_buildInfoBox('🏛️ Mahkeme Dosya Numaranız: $davaNo', 'Avukatınız dava numarasını iletti. Kendi belgelerinizle örtüşüyor mu? Lütfen kontrol edip onaylayın.', const Color(0xFFFFB300)));
      actions.add(ElevatedButton(
        onPressed: () => _confirmDavaNo(davaId, davaNo),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
        child: const Text('✔️ Numara Doğru - Onayla', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(OutlinedButton(
        onPressed: () => _rejectDavaNo(davaId),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
        child: const Text('❌ Teyit Edilmiyor'),
      ));
    }
    else if (status == 'TAHSIL') {
      actions.add(ElevatedButton(
        onPressed: () => _confirmCollectionModal(davaId, d['tahsilAciklama'] ?? ''),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
        child: const Text('✔️ Tahsilatı Onayla ve Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(OutlinedButton(onPressed: () => context.push('/chat/$davaId'), child: const Text('💬 Mesajlaş')));
    }
    else if (['ACTIVE', 'PRE_CASE_REVIEW', 'AUTHORIZED', 'IN_PROGRESS', 'FILED_IN_COURT', 'DURUSMA'].contains(status)) {
      actions.add(OutlinedButton(onPressed: () => context.push('/chat/$davaId'), child: const Text('💬 Mesajlaş')));
    }
    else if (['CLOSED', 'CANCELED'].contains(status)) {
      actions.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Center(child: Text('🔒 Dava Dosyası Kapandı', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13))),
      ));
    }

    return actions;
  }

  Widget _buildInfoBox(String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    const labels = {
      'KAYITLI': '📁 Kayıtlı',
      'AVUKAT_ARANIYOR': '🧐 Yanıt Bekleniyor',
      'ACTIVE': '🟢 Aktif Müvekkil',
      'PRE_CASE_REVIEW': '🧐 Dosya İnceleniyor',
      'PENDING_USER_AUTH': '⏳ Vekalet İsteniyor',
      'AUTHORIZED': '✅ Vekalet Verildi',
      'DAVA_NO_BEKLIYOR': '🏗️ Dosya No Onayı',
      'FILED_IN_COURT': '🏛️ Dava Açıldı',
      'IN_PROGRESS': '💬 İşlemde',
      'DURUSMA': '🏛️ Duruşma Süreci',
      'TAHSIL': '💰 Tahsil Edildi',
      'CLOSED': '🛑 Kapatıldı',
      'CANCELED': '🚫 İptal'
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(labels[status] ?? status, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // --- ACTIONS ---
  void _showLawyerSearch(String city, String caseId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LawyerSearchModal(city: city, caseId: caseId),
    ).then((_) => _refresh());
  }

  Future<void> _cancelSearchAndRetry(String id, String city) async {
    final confirmed = await _showConfirm('Aramayı İptal Et', 'Mevcut iletişim talebini iptal edip yeni bir avukat aramak istediğinize emin misiniz?');
    if (confirmed) {
      try {
        await CaseService.updateStatus(caseId: id, status: 'KAYITLI', aciklama: 'Kullanıcı talebi iptal etti.');
        _refresh();
        _showLawyerSearch(city, id);
      } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _deleteCase(String id) async {
    final confirmed = await _showConfirm('Silme Onayı', 'Bu dava ilanını silmek istediğinize emin misiniz?');
    if (confirmed) {
      try { await CaseService.deleteCase(id); _refresh(); } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _approveAuth(String id) async {
    final confirmed = await _showConfirm('Vekalet Onayı', 'Avukatınıza resmi vekalet verdiğinizi onaylıyor musunuz?');
    if (confirmed) {
      try { await CaseService.updateStatus(caseId: id, status: 'AUTHORIZED', aciklama: 'Kullanıcı vekaleti onayladı.'); _refresh(); } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _confirmDavaNo(String id, String no) async {
    final confirmed = await _showConfirm('Dosya No Onayı', 'Mahkeme dosya numarası ($no) doğru mu?');
    if (confirmed) {
      try { await CaseService.updateStatus(caseId: id, status: 'FILED_IN_COURT', aciklama: 'Dosya no onaylandı: $no'); _refresh(); } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _rejectDavaNo(String id) async {
    final confirmed = await _showConfirm('Hata Bildirimi', 'Dosya numarasının yanlış olduğunu bildirmek istiyor musunuz?');
    if (confirmed) {
      try { await CaseService.updateStatus(caseId: id, status: 'AUTHORIZED', aciklama: 'Kullanıcı dosya nosunun yanlış olduğunu bildirdi.'); _refresh(); } catch (e) { _showError(e.toString()); }
    }
  }

  Future<void> _confirmCollectionModal(String id, String aciklama) async {
    final match = RegExp(r'(\d+)').firstMatch(aciklama);
    final miktar = match != null ? '${match.group(1)} TL' : 'Bilinmeyen Tutar';
    
    int rating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('💰', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Dava Kapanış Onayı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Avukatınız bu davanın başarıyla sonuçlandığını (veya anlaşıldığını) bildirdi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Tahsil Edilen Toplam Tutar:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(miktar, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                child: const Text(
                  '⚠️ Önemli Uyarı: Yukarıdaki tutar fiilen anlaştığınız tutar ile uyuşmuyorsa onaylamayınız. Herhangi bir kandırma işleminde sistemdeki kayıtlar delil sayılacaktır.',
                  style: TextStyle(fontSize: 11, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Avukatınızı Değerlendirin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setModalState(() => rating = index + 1),
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: index < rating ? Colors.amber : AppColors.textMuted,
                    size: 32,
                  ),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Avukatınız hakkındaki düşüncelerinizi paylaşın...',
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '* Dava dosyanızı tamamen sistem üzerinde Kapatmak istediğinize emin misiniz?',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await CaseService.updateStatus(
                            caseId: id,
                            status: 'CLOSED',
                            aciklama: 'Kullanıcı tahsilatı onayladı ve dosya kapandı.',
                            tahsilat: double.tryParse(match?.group(1) ?? '0'),
                            puan: rating,
                            yorum: commentController.text,
                          );
                          Navigator.pop(ctx);
                          _refresh();
                          _showSnackBar('Dava başarıyla kapatıldı! 🎉', AppColors.accent);
                        } catch (e) {
                          _showError(e.toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                      child: const Text('Onayla ve Kapat'),
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

  Future<bool> _showConfirm(String title, String msg) async {
    return await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard, 
        title: Text(title, style: const TextStyle(color: Colors.white)), 
        content: Text(msg, style: const TextStyle(color: AppColors.textSecondary)), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')), 
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent), 
            child: const Text('Evet', style: TextStyle(color: Colors.black))
          )
        ]
      )
    ) ?? false;
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showError(String err) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.danger)); }
  Widget _buildEmptyState() { return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_open, size: 64, color: AppColors.textMuted), SizedBox(height: 16), Text('Henüz dava dosyanız yok.', style: TextStyle(color: AppColors.textSecondary))])); }
  Widget _buildErrorState(String error) { return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: AppColors.danger), const SizedBox(height: 16), Text(error, textAlign: TextAlign.center), const SizedBox(height: 16), ElevatedButton(onPressed: _refresh, child: const Text('Tekrar Dene'))]))); }
}

// Avukat Arama Modalı
class _LawyerSearchModal extends StatefulWidget {
  final String city;
  final String caseId;
  const _LawyerSearchModal({required this.city, required this.caseId});

  @override
  State<_LawyerSearchModal> createState() => _LawyerSearchModalState();
}

class _LawyerSearchModalState extends State<_LawyerSearchModal> {
  late Future<List<dynamic>> _lawyersFuture;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _lawyersFuture = LawyerService.searchLawyers(widget.city, widget.caseId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚖️ Şehrinizdeki Avukatlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Hizmet bedeli ödeyerek süreci başlatabilirsiniz.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _lawyersFuture,
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  final lawyers = snapshot.data ?? [];
                  if (lawyers.isEmpty) return _buildEmptySearch();

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: lawyers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final l = lawyers[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _buildLawyerAvatar(l),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l['unvan'] ?? 'Av.'} ${l['ad']} ${l['soyad']}', 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l['sehir'] ?? '', 
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${l['ortalamaPuan'] ?? l['puan'] ?? '5.0'} (${l['yorumSayisi'] ?? 0} Yorum)', 
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)
                                      ),
                                    ],
                                  ),
                                  if (l['bio'] != null || l['uzmanlik'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      l['bio'] ?? 'İş hukuku ve işçi alacakları konusunda deneyimli avukat.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: (l['uzmanlik'] is List)
                                          ? (l['uzmanlik'] as List).map((u) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.bgSurface,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.border),
                                              ),
                                              child: Text(u.toString(), style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                            )).toList()
                                          : [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgSurface,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: Text(l['uzmanlik']?.toString() ?? 'İş Hukuku', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                              )
                                            ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            (() {
                              final bool talepGonderildi = l['talepGonderildi'] == true;
                              return ElevatedButton(
                                onPressed: (_isRequesting || talepGonderildi) ? null : () => _sendRequest(l),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: talepGonderildi ? AppColors.border : AppColors.primary,
                                  foregroundColor: talepGonderildi ? AppColors.textMuted : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: Text(talepGonderildi ? 'Gönderildi' : 'Talep Gönder', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              );
                            })(),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLawyerAvatar(dynamic l) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(l['ad']?[0] ?? 'A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primaryLight))),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              widget.city.isEmpty 
                ? 'Sistemde henüz kayıtlı avukat bulunamadı.'
                : '${widget.city} şehrinde henüz kayıtlı avukat bulunamadı.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (widget.city.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _lawyersFuture = LawyerService.searchLawyers('', widget.caseId);
                  });
                },
                child: const Text('Tüm Şehirlerdeki Avukatları Gör'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRequest(Map<String, dynamic> l) async {
    setState(() => _isRequesting = true);
    try {
      // 1) Talep gönder
      await LawyerService.sendContactRequest(avukatId: l['id'].toString(), caseId: widget.caseId);
      
      // 2) Web mantığı: Dosya durumunu AVUKAT_ARANIYOR yap
      await CaseService.updateStatus(
        caseId: widget.caseId, 
        status: 'AVUKAT_ARANIYOR', 
        aciklama: 'Kullanıcı iletişim talebi gönderdi.'
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talebiniz iletildi!'), backgroundColor: AppColors.accent));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isRequesting = false);
    }
  }
}
