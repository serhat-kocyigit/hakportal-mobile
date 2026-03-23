import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class TekliflerScreen extends StatefulWidget {
  final Map<String, dynamic> caseItem;

  const TekliflerScreen({super.key, required this.caseItem});

  @override
  State<TekliflerScreen> createState() => _TekliflerScreenState();
}

class _TekliflerScreenState extends State<TekliflerScreen> {
  late Future<List<dynamic>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _fetchOffers();
  }

  Future<List<dynamic>> _fetchOffers() async {
    final response = await ApiService.dio.get('/offers/case/${widget.caseItem['id']}');
    final data = response.data;
    if (data is List) {
      // Sadece PENDING teklifleri göster (web sitesiyle aynı)
      return data.where((t) => (t['status'] ?? 'PENDING') == 'PENDING').toList();
    }
    return [];
  }

  void _refresh() => setState(() => _offersFuture = _fetchOffers());

  Future<void> _teklifSec(Map<String, dynamic> teklif) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Teklifi Seç', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu teklifi seçmek istediğinizden emin misiniz?\n\nDiğer teklifler reddedilecek ve seçtiğiniz avukata belgeleriniz iletilecektir.\n\nAvukat dosyanızı inceleyip kabul ederse size bildirim gönderilecektir.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            child: const Text('Evet, Seç'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.dio.put('/offers/${teklif['id']}/sec');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Teklif seçildi! Avukat belgelerinizi inceleyecek. Kabul ederse bildirim alacaksınız.'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true); // Başarılı → davalar sayfasını yenile
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showYorumlar(Map<String, dynamic> teklif) {
    final yorumlar = teklif['yorumlar'] as List? ?? [];
    if (yorumlar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu avukat için henüz hiç yorum bulunmuyor.'), backgroundColor: AppColors.textSecondary),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  const Text('⚖️ Avukat Değerlendirmeleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: yorumlar.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final y = yorumlar[idx];
                  final puan = (y['puan'] as num?)?.toInt() ?? 0;
                  final yorum = y['yorum'] ?? 'Yorum yazılmamış.';
                  final dt = DateTime.tryParse(y['created_at']?.toString() ?? '');
                  final tarih = dt != null ? DateFormat('dd.MM.yyyy').format(dt) : '';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Müvekkil Yorumu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Row(children: List.generate(5, (i) => Icon(
                              i < puan ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFFFD700), size: 16,
                            ))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('"$yorum"', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                        if (tarih.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(tarih, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> teklif, int index) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final ucretModeli = teklif['ucretModeli'] ?? 'yuzde';
    
    // Güvenli sayı okuma
    double getAsDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final oran = getAsDouble(teklif['oran']);
    final sabitUcret = getAsDouble(teklif['sabitUcret']);
    final onOdeme = teklif['onOdeme'] == true;
    final tahminiSure = teklif['tahminiSure'] ?? 'Belirtilmemiş';
    final aciklama = teklif['aciklama'] ?? '';
    final ortalamaPuan = getAsDouble(teklif['ortalamaPuan']);
    final yorumSayisi = (teklif['yorumSayisi'] as num?)?.toInt() ?? 0;

    final ucretText = ucretModeli == 'yuzde'
        ? '%$oran'
        : currencyFormat.format(sabitUcret);
    final ucretAlt = ucretModeli == 'yuzde' ? 'Yüzde usulü ücret' : 'Sabit ücret';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚖️ Anonim Avukat ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Beklemede', style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Yıldız Puanı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      // Üst satır: yıldızlar + puan
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(5, (i) {
                            final double starVal = ortalamaPuan - i;
                            IconData icon;
                            if (starVal >= 1) icon = Icons.star_rounded;
                            else if (starVal >= 0.5) icon = Icons.star_half_rounded;
                            else icon = Icons.star_outline_rounded;
                            return Icon(icon, color: const Color(0xFFFFD700), size: 22);
                          }),
                          const SizedBox(width: 8),
                          Text(
                            ortalamaPuan.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Alt satır: yorum linki
                      GestureDetector(
                        onTap: () => _showYorumlar(teklif),
                        child: Text(
                          '💬 $yorumSayisi Müvekkil Yorumunu Oku',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryLight,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ücret (büyük, web sitesiyle aynı)
                Center(
                  child: Column(
                    children: [
                      Text(
                        ucretText,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryLight,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        '$ucretAlt  •  ${onOdeme ? "⚠️ Ön ödeme var" : "✅ Ön ödeme yok"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Detay: Tahmini Süre
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tahmini Süre', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(tahminiSure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),

                // Açıklama
                if (aciklama.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '"$aciklama"',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic, height: 1.4),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Seç Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _teklifSec(teklif),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Bu Teklifi Seç →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avukat Teklifleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              widget.caseItem['davaTuru'] ?? 'Dava',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Teklifler yükleniyor...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
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

          final teklifler = snapshot.data ?? [];

          if (teklifler.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⏳', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'Henüz teklif gelmedi.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Avukatlar tekliflerini hazırlıyor.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('← Davalara Dön'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: AppColors.primary,
            child: Column(
              children: [
                // Bilgi Bandı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    border: const Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.gavel_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${teklifler.length} avukattan teklif geldi.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Gizlilik Notu
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.accent.withValues(alpha: 0.06),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '🔒 Kişisel bilgileriniz avukatlara gösterilmez. Sadece karşılıklı onayda iletişim açılır.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Teklif Listesi
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: teklifler.length,
                    itemBuilder: (ctx, idx) => _buildOfferCard(teklifler[idx], idx),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
