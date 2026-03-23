import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/case_service.dart';
import '../services/offer_service.dart';
import '../screens/teklifler_screen.dart';

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
    _casesFuture = CaseService.getMyCases();
  }

  Future<void> _refresh() async {
    setState(() {
      _casesFuture = CaseService.getMyCases();
    });
  }

  String _getStatusLabel(String status) {
    const statusMap = {
      'OPEN': '⏱️ Teklif Bekleniyor',
      'MATCHING': '🧐 Avukat İnceliyor',
      'WAITING_USER_DEPOSIT': '✅ 99 TL Güven Bedeli Bekleniyor',
      'WAITING_PAYMENT': '💳 Avukat Ödemesi Bekleniyor',
      'WAITING_LAWYER_PAYMENT': '💳 Avukat Ödemesi Bekleniyor',
      'PRE_CASE_REVIEW': '🧐 Ön İnceleme',
      'PENDING_USER_AUTH': '⏳ Vekalet İsteği',
      'AUTHORIZED': '✅ Vekalet Onaylı',
      'FILED_IN_COURT': '🏛️ Dava Açıldı',
      'LAWYER_ASSIGNED': '✅ Avukat Atandı',
      'IN_PROGRESS': '💬 İşlemde',
      'ACTIVE': '🟢 Aktif',
      'KAPANDI': '🛑 Kapatıldı',
      'ILK_GORUSME': '🤝 İlk Görüşme',
      'DAVA_ACILDI': '⚖️ Dava Açıldı',
      'DURUSMA': '🏛️ Duruşma',
      'TAHSIL': '💰 Tahsil Edildi',
      'CLOSED': '🛑 Kapatıldı',
    };
    return statusMap[status] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFF6C63FF);
      case 'MATCHING':
        return const Color(0xFFFFB703);
      case 'WAITING_USER_DEPOSIT':
        return const Color(0xFF00D9A3);
      case 'WAITING_PAYMENT':
      case 'WAITING_LAWYER_PAYMENT':
        return const Color(0xFF60A5FA);
      case 'ACTIVE':
      case 'AUTHORIZED':
      case 'PRE_CASE_REVIEW':
        return const Color(0xFF00D9A3);
      case 'CLOSED':
      case 'KAPANDI':
        return const Color(0xFF6B7280);
      case 'TAHSIL':
        return const Color(0xFFE91E63);
      default:
        return AppColors.primaryLight;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFF6C63FF).withAlpha(40);
      case 'MATCHING':
        return const Color(0xFFFFB703).withAlpha(40);
      case 'WAITING_USER_DEPOSIT':
        return const Color(0xFF00D9A3).withAlpha(40);
      case 'WAITING_PAYMENT':
      case 'WAITING_LAWYER_PAYMENT':
        return const Color(0xFF60A5FA).withAlpha(40);
      case 'ACTIVE':
      case 'AUTHORIZED':
      case 'PRE_CASE_REVIEW':
        return const Color(0xFF00D9A3).withAlpha(40);
      case 'CLOSED':
      case 'KAPANDI':
        return const Color(0xFF6B7280).withAlpha(40);
      case 'TAHSIL':
        return const Color(0xFFE91E63).withAlpha(40);
      default:
        return AppColors.primaryLight.withAlpha(40);
    }
  }

  Widget _renderDetayliDavaRaporu(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final kidem = data['kidem'] as Map<String, dynamic>?;
    final ihbar = data['ihbar'] as Map<String, dynamic>?;
    final diger = data['diger'] as Map<String, dynamic>?;
    final legal = data['legal'] as Map<String, dynamic>?;
    final toplamNet = (data['toplamNet'] ?? 0).toDouble();

    final ekstraHaklar = [
      {'name': 'Boşta Geçen Süre', 'val': (diger?['bostaGecenSureBrut'] ?? 0).toDouble(), 'color': const Color(0xFF52B788)},
      {'name': 'İşe Başlatmama', 'val': (diger?['iseBaslatmamaBrut'] ?? 0).toDouble(), 'color': const Color(0xFFFFB703)},
      {'name': 'Kötü Niyet', 'val': (diger?['kotuNiyetNet'] ?? 0).toDouble(), 'color': const Color(0xFFE63946)},
      {'name': 'Sendikal', 'val': (diger?['sendikalNet'] ?? 0).toDouble(), 'color': const Color(0xFF9D4EDD)},
      {'name': 'Ödenmemiş Maaş', 'val': (diger?['odenmemisMaasBrut'] ?? 0).toDouble(), 'color': const Color(0xFF4CC9F0)},
      {'name': 'Fazla Mesai', 'val': (diger?['mesaiBrut'] ?? 0).toDouble(), 'color': const Color(0xFFF72585)},
      {'name': 'Yıllık İzin', 'val': (diger?['izinBrut'] ?? 0).toDouble(), 'color': const Color(0xFFF8961E)},
      {'name': 'Bakiye Süre', 'val': (diger?['bakiyeSureTazminatBrut'] ?? 0).toDouble(), 'color': const Color(0xFF43AA8B)},
    ];

    final aktifEkstra = ekstraHaklar.where((h) => (h['val'] as double) > 0).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hukuki Nitelendirme
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9A3).withAlpha(13),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚖️ Hukuki Nitelendirme',
                      style: TextStyle(
                        color: Color(0xFF00D9A3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Tahmini Toplam',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                        Text(
                          currencyFormat.format(toplamNet),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  legal?['gerekce'] ?? 'Sistem tarafından dava konusu derlendi.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Hesaplama Detayları
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Kıdem ve İhbar
                if ((kidem?['net'] ?? 0) > 0 || (ihbar?['net'] ?? 0) > 0)
                  Row(
                    children: [
                      if ((kidem?['net'] ?? 0) > 0)
                        Expanded(
                          child: _buildCalcBox(
                            'Kıdem Tazminatı',
                            currencyFormat.format((kidem?['net'] ?? 0).toDouble()),
                            const Color(0xFF00D9A3),
                          ),
                        ),
                      if ((kidem?['net'] ?? 0) > 0 && (ihbar?['net'] ?? 0) > 0)
                        const SizedBox(width: 8),
                      if ((ihbar?['net'] ?? 0) > 0)
                        Expanded(
                          child: _buildCalcBox(
                            'İhbar Tazminatı',
                            currencyFormat.format((ihbar?['net'] ?? 0).toDouble()),
                            const Color(0xFFA2B9FF),
                          ),
                        ),
                    ],
                  ),

                // Ekstra Haklar
                if (aktifEkstra.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: aktifEkstra.map((h) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (h['color'] as Color).withAlpha(102)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚖️ ${h['name']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: h['color'] as Color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(h['val'] as double),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderBelgeler(dynamic belgeler) {
    if (belgeler == null || !(belgeler is List) || belgeler.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📄', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Text(
                'İspat Belgeleri',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...belgeler.map((b) {
            final name = b['name']?.toString() ?? 'Belge';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                   const Icon(Icons.attach_file, size: 14, color: AppColors.textMuted),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       name,
                       style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDavaActions(Map<String, dynamic> d) {
    final status = d['status'] ?? 'OPEN';
    final teklifSayisi = d['teklifSayisi'] ?? 0;
    final bekleyenTeklif = d['bekleyenTeklif'] ?? teklifSayisi;
    final engagementStatus = d['engagementStatus'];
    final tahsilAciklama = d['tahsilAciklama'] ?? '';

    List<Widget> actions = [];

    // OPEN - Teklifler varsa gör, yoksa bekle
    if (status == 'OPEN') {
      if (teklifSayisi > 0) {
        actions.add(
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTeklifler(d),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text('Teklifleri Gör ($bekleyenTeklif)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      } else {
        actions.add(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Text(
              '⏳ Avukat teklifi bekleniyor...',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      // Sil butonu
      actions.add(
        TextButton.icon(
          onPressed: () => _showDeleteConfirmation(d['id']),
          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF4D4F)),
          label: const Text('İlanı Sil', style: TextStyle(color: Color(0xFFFF4D4F))),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      );
    }

    // MATCHING - Avukat inceleme durumu
    else if (status == 'MATCHING') {
      if (engagementStatus == 'WAITING_USER_DEPOSIT') {
        actions.add(
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9A3).withAlpha(20),
              border: Border.all(color: const Color(0xFF00D9A3).withAlpha(77)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '✅ Avukatınız belgeleri inceleyip dosyayı kabul etti! 99 TL güven bedelini ödeyerek süreci başlatın.',
              style: TextStyle(fontSize: 12, color: Color(0xFF00D9A3), height: 1.4),
            ),
          ),
        );
        actions.add(
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showOdemeModal(d['id']),
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('✅ 99 TL Güven Bedeli Öde'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9A3),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      } else {
        actions.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB703).withAlpha(20),
              border: Border.all(color: const Color(0xFFFFB703).withAlpha(77)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🧐 Seçtiğiniz avukat belgelerinizi inceliyor... Kabul ederse bildirim alacaksınız.',
              style: TextStyle(fontSize: 12, color: Color(0xFFFFB703), height: 1.4),
            ),
          ),
        );
      }
    }

    // Ödeme bekleyen durumlar
    else if (status == 'WAITING_PAYMENT' || status == 'WAITING_LAWYER_PAYMENT') {
      actions.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Text(
            '⏳ Avukat platform bedelini ödüyor...',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Vekalet isteği
    else if (status == 'PENDING_USER_AUTH') {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _approveUserAuth(d['id']),
            icon: const Icon(Icons.gavel_outlined, size: 16),
            label: const Text('⚠️ Avukata Vekalet Ver (Onayla)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9A3),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
      actions.add(const SizedBox(height: 8));
      actions.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _loadMesaj(d['id'], status),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('💬 Mesajlaş'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
    }

    // Tahsilat onayı
    else if (status == 'TAHSIL') {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showCollectionModal(d['id'], tahsilAciklama),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('✔️ Tahsilatı Onayla ve Dosyayı Kapat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
      actions.add(const SizedBox(height: 8));
      actions.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _loadMesaj(d['id'], status),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('💬 Mesajlaş'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
    }

    // Kapanan davalar - Mesajlaşma kapalı
    else if (['CLOSED', 'KAPANDI', 'CANCELED'].contains(status)) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null, // Disabled
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('🔒 Dava Dosyası Kapandı'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              disabledForegroundColor: AppColors.textMuted,
            ),
          ),
        ),
      );
    }
    // Aktif davalar - sadece mesajlaş
    else if ([
      'PRE_CASE_REVIEW', 'AUTHORIZED', 'ACTIVE', 'LAWYER_ASSIGNED',
      'FILED_IN_COURT', 'IN_PROGRESS', 'ILK_GORUSME', 'DAVA_ACILDI',
      'DURUSMA'
    ].contains(status)) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _loadMesaj(d['id'], status),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('💬 Mesajlaş'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }

  void _showTeklifler(Map<String, dynamic> caseItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TekliflerScreen(caseItem: caseItem),
      ),
    ).then((result) {
      if (result == true) _refresh(); // Teklif seçildiyse yenile
    });
  }

  Future<void> _showDeleteConfirmation(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Dava İlanını Sil'),
        content: const Text(
          'Bu dava ilanını kalıcı olarak silmek istediğinize emin misiniz?\n\n(Bu işlem geri alınamaz)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CaseService.deleteCase(caseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dava ilanı başarıyla silindi.'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _approveUserAuth(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Vekalet Onayı'),
        content: const Text(
          'Avukatınıza resmi vekaleti verdiğinizi ve davayı üstlenmesi için yetkilendirdiğinizi onaylıyor musunuz?\n\n* Onayladığınızda avukat yetkilenip mahkemede davanızı açacaktır.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CaseService.updateStatus(
          caseId: caseId,
          status: 'AUTHORIZED',
          aciklama: 'Kullanıcı avukata vekalet verdiğini ve yetkilendirdiğini onayladı.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Vekalet Avukata Onaylandı!'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _showOdemeModal(String caseId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OdemeModal(caseId: caseId, onSuccess: _refresh),
    );
  }

  void _showCollectionModal(String caseId, String aciklama) {
    final match = RegExp(r'(\d+)\s*TL').firstMatch(aciklama);
    final miktar = match != null ? '${match.group(1)} TL' : 'Bilinmeyen Tutar';
    int puan = 5;
    final yorumController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Row(children: [
            Text('💰 ', style: TextStyle(fontSize: 24)),
            Text('Dava Kapanış Onayı'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Avukatınız bu davanın başarıyla sonuçlandığını (veya anlaşıldığını) bildirdi.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text('Tahsil Edilen Toplam Tutar:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      SizedBox(height: 4),
                      Text(
                        miktar,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Color(0xFFFFEEBA)),
                  ),
                  child: Text(
                    'Önemli Uyarı: Yukarıdaki tutar fiilen anlaştığınız tutar ile uyuşmuyorsa onaylamayınız.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF856404), height: 1.4),
                  ),
                ),
                SizedBox(height: 20),
                Text('Avukatınızı Değerlendirin', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setState(() => puan = index + 1),
                      icon: Icon(index < puan ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                    );
                  }),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: yorumController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Avukatınız hakkındaki düşüncelerinizi paylaşın...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hayır, İptal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await CaseService.updateStatus(
                    caseId: caseId,
                    status: 'CLOSED',
                    aciklama: 'Müvekkil davanın sonuçlandığını onayladı.',
                    puan: puan,
                    yorum: yorumController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Dava başarıyla kapatıldı!'),
                        backgroundColor: AppColors.accent,
                      ),
                    );
                  }
                  _refresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
              child: const Text('Evet, Onayla & Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  void _loadMesaj(String caseId, String status) {
    context.push('/chat/$caseId');
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd.MM.yyyy');

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: FutureBuilder<List<dynamic>>(
        future: _casesFuture,
        builder: (context, snapshot) {
          // Loading State - Web'deki gibi spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yükleniyor...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          // Error State
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          final cases = snapshot.data ?? [];

          // Empty State - Web'deki gibi 📁
          if (cases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.folder_open, size: 80, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Henüz dava dosyanız yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hesaplama yapın ve avukat teklifleri alın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Yeni hesaplama sekmesine git
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Hesaplamaya Başla'),
                ),
              ],
            );
          }

          // Dava Grid - Web'deki gibi (gap: 20px)
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final d = cases[index];
              final status = d['status'] ?? 'OPEN';
              
              // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ:
              double tahminiAlacak = 0.0;
              final rawAlacak = d['tahminiAlacak'];
              if (rawAlacak is num) {
                tahminiAlacak = rawAlacak.toDouble();
              } else if (rawAlacak is String) {
                tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
              }

              final tarihStr = d['createdAt'];
              final dateStr = tarihStr != null
                  ? dateFormat.format(DateTime.parse(tarihStr))
                  : '';
              final hesaplamaVerisi = d['hesaplamaVerisi'] as Map<String, dynamic>?;

              // dava-card (Web'deki birebir stil)
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // dava-card-header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // dava-card-title
                                Text(
                                  d['davaTuru'] ?? 'Kıdem/İhbar Davası',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // dava-card-sub
                                Text(
                                  '${d['sehir'] ?? 'Belirsiz'} • $dateStr',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // status-badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusBgColor(status),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(status).withAlpha(77),
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Divider(height: 1, color: AppColors.border.withAlpha(100)),

                    // dava-card-body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // dava-detail-row: Tahmini Alacak
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tahmini Alacak',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              // alacak styling (accent, bold)
                              Text(
                                currencyFormat.format(tahminiAlacak),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // dava-detail-row: Teklif Sayısı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Teklif Sayısı',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                '${d['teklifSayisi'] ?? 0} avukat',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          // renderDetayliDavaRaporu - Hesaplama detayları
                          _renderDetayliDavaRaporu(hesaplamaVerisi),

                          // _renderBelgeler - İspat belgeleri
                          _renderBelgeler(d['ispatBelgeleri']),
                        ],
                      ),
                    ),

                    // dava-card-actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _buildDavaActions(d),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Ödeme Modalı - 99₺ Güven Bedeli
class _OdemeModal extends StatefulWidget {
  final String caseId;
  final VoidCallback onSuccess;

  const _OdemeModal({required this.caseId, required this.onSuccess});

  @override
  State<_OdemeModal> createState() => _OdemeModalState();
}

class _OdemeModalState extends State<_OdemeModal> {
  final _kartNoController = TextEditingController();
  final _sonKullanmaController = TextEditingController();
  final _cvvController = TextEditingController();
  final _kartSahibiController = TextEditingController();
  bool _isLoading = false;
  String? _offerId;

  @override
  void initState() {
    super.initState();
    _loadOfferId();
  }

  Future<void> _loadOfferId() async {
    try {
      final caseData = await CaseService.getCaseDetails(widget.caseId);
      final teklifler = caseData['teklifler'] as List?;
      if (teklifler != null) {
        for (final t in teklifler) {
          if (t['status'] == 'SELECTED') {
            setState(() => _offerId = t['id']);
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _processPayment() async {
    final kartNo = _kartNoController.text.replaceAll(' ', '');
    final sonKullanma = _sonKullanmaController.text;
    final cvv = _cvvController.text;
    final kartSahibi = _kartSahibiController.text.trim();

    if (kartNo.length < 16) {
      _showError('Geçerli kart numarası girin.');
      return;
    }
    if (!sonKullanma.contains('/')) {
      _showError('Son kullanma tarihi eksik.');
      return;
    }
    if (cvv.length < 3) {
      _showError('CVV eksik.');
      return;
    }
    if (kartSahibi.length < 3) {
      _showError('Kart sahibi adı eksik.');
      return;
    }
    if (_offerId == null) {
      _showError('Teklif bilgisi eksik.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await OfferService.payUserDeposit(
        offerId: _offerId!,
        kartNo: kartNo,
        kartSahibi: kartSahibi,
        sonKullanma: sonKullanma,
        cvv: cvv,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Güven ödemesi başarılı!'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
      widget.onSuccess();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '💳 Güven (Ciddiyet) Ödemesi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Bilgi Kartı - odeme-info-card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Hizmet', 'Platform Ciddiyet Bedeli'),
                  _buildInfoRow('Kapsam', 'Avukatla Eşleşme Güvencesi'),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        currencyFormat.format(99),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // İade garantisi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9A3).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✅ Avukat atamayı yapmazsa paranız cüzdanınıza %100 oranında iade edilecektir.',
                style: TextStyle(fontSize: 12, color: Color(0xFF00D9A3), height: 1.4),
              ),
            ),

            const SizedBox(height: 24),

            // Kart Formu
            TextFormField(
              controller: _kartNoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kart Numarası',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card),
              ),
              onChanged: (val) {
                final clean = val.replaceAll(RegExp(r'\D'), '').substring(0, 16);
                final formatted = clean.replaceAllMapped(
                  RegExp(r'.{4}'),
                  (match) => '${match.group(0)} ',
                ).trim();
                if (formatted != val) {
                  _kartNoController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sonKullanmaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Son Kullanma',
                      hintText: 'MM / YY',
                    ),
                    onChanged: (val) {
                      final clean = val.replaceAll(RegExp(r'\D'), '').substring(0, 4);
                      String formatted = clean;
                      if (clean.length > 2) {
                        formatted = '${clean.substring(0, 2)} / ${clean.substring(2)}';
                      }
                      if (formatted != val) {
                        _sonKullanmaController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _kartSahibiController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Kart Üzerindeki İsim',
                hintText: 'AD SOYAD',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Ödemeyi Tamamla',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
