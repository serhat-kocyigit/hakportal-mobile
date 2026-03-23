import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class OffersTab extends StatefulWidget {
  final String? caseId;
  const OffersTab({super.key, this.caseId});

  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  late Future<List<dynamic>> _offersFuture;
  Map<String, dynamic>? _selectedCase;

  @override
  void initState() {
    super.initState();
    if (widget.caseId != null) {
      // Belirli bir dava için teklifleri göster
      _offersFuture = _fetchCaseOffers(widget.caseId!);
    } else {
      // Tüm teklifleri göster
      _offersFuture = _fetchOffers();
    }
  }

  Future<List<dynamic>> _fetchOffers() async {
    try {
      final response = await ApiService.dio.get('/cases/benim');
      final cases = response.data as List<dynamic>;
      // Sadece teklif içeren davaları göster
      return cases.where((c) => (c['teklifSayisi'] ?? 0) > 0).toList();
    } catch (e) {
      throw Exception('Teklifler yüklenirken hata: $e');
    }
  }

  Future<List<dynamic>> _fetchCaseOffers(String caseId) async {
    try {
      // Teklifleri getir ve tek bir dava olarak formatla
      final response = await ApiService.dio.get('/offers/case/$caseId');
      final offers = response.data as List<dynamic>;
      // Dava bilgisini de getir
      final caseResponse = await ApiService.dio.get('/cases/$caseId');
      final caseData = caseResponse.data;
      // Teklifleri dava objesi içinde döndür
      return [{
        ...caseData,
        'teklifler': offers,
      }];
    } catch (e) {
      throw Exception('Teklifler yüklenirken hata: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() => _offersFuture = _fetchOffers());
  }

  void _showOffersForCase(Map<String, dynamic> caseItem) async {
    try {
      final response = await ApiService.dio.get('/cases/${caseItem['id']}/teklifler');
      final offers = response.data as List<dynamic>;

      if (!mounted) return;

      if (offers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Henüz teklif yok.'), backgroundColor: AppColors.warning),
        );
        return;
      }

      setState(() => _selectedCase = caseItem);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.bgSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Avukat Teklifleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                caseItem['davaTuru'] ?? 'Dava',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔒 Kişisel bilgileriniz avukatlara gösterilmez. Sadece karşılıklı onayda iletişim açılır.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Teklifler Listesi
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: offers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final offer = offers[idx];
                    return _buildOfferCard(offer, caseItem);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teklifler alınamadı: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, Map<String, dynamic> caseItem) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final ucretModeli = offer['ucretModeli'] ?? 'yuzde';
    
    // Güvenli sayı okuma
    double getAsDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final oran = getAsDouble(offer['oran']);
    final sabitUcret = getAsDouble(offer['sabitUcret']);
    final onOdeme = offer['onOdeme'] == true;
    final tahminiSure = offer['tahminiSure'] ?? 'Belirtilmemiş';
    final aciklama = offer['aciklama'] ?? '';
    final avukat = offer['avukat'] ?? {};
    final durum = offer['durum'] ?? 'BEKLIYOR';
    final degerlendirildi = offer['degerlendirildi'] == true;

    String ucretText;
    if (ucretModeli == 'yuzde') {
      ucretText = '%$oran (Kazanıştan Pay)';
    } else {
      ucretText = currencyFormat.format(sabitUcret);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: degerlendirildi ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avukat Bilgisi (Anonim)
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(child: Icon(Icons.person_outline, color: AppColors.primaryLight)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Anonim Avukat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      '${avukat['sehir'] ?? 'Şehir belirtilmemiş'} • ${avukat['deneyim'] ?? 'Deneyim bilgisi yok'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (degerlendirildi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('İncelendi', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),
          // Ücret
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ücret Modeli:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(ucretText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          // Ön Ödeme
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ön Ödeme:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                onOdeme ? '✓ Gerektiriyor' : '✗ Gerektirmiyor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: onOdeme ? AppColors.warning : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tahmini Süre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tahmini Süre:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(tahminiSure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          // Açıklama
          if (aciklama.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(aciklama, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 16),
          // Butonlar
          if (durum == 'BEKLIYOR')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOffer(offer, caseItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Teklifi Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectOffer(offer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
              ],
            )
          else if (durum == 'KABUL_EDILDI')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kabul Edildi - Ödeme Bekleniyor',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else if (durum == 'ONAYLI')
            ElevatedButton.icon(
              onPressed: () => _goToChat(caseItem, offer),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Avukatla Mesajlaş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
        ],
      ),
    );
  }

  void _acceptOffer(Map<String, dynamic> offer, Map<String, dynamic> caseItem) async {
    try {
      await ApiService.dio.post('/teklifler/${offer['id']}/kabul');
      if (!mounted) return;
      Navigator.pop(context);
      _showPaymentModal(caseItem, offer);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _rejectOffer(Map<String, dynamic> offer) async {
    try {
      await ApiService.dio.post('/teklifler/${offer['id']}/reddet');
      if (!mounted) return;
      Navigator.pop(context);
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif reddedildi.'), backgroundColor: AppColors.textSecondary),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showPaymentModal(Map<String, dynamic> caseItem, Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PaymentModal(
        caseItem: caseItem,
        offer: offer,
        onPaymentComplete: () {
          Navigator.pop(ctx);
          _refresh();
        },
      ),
    );
  }

  void _goToChat(Map<String, dynamic> caseItem, Map<String, dynamic> offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          caseId: caseItem['id'].toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: FutureBuilder<List<dynamic>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                  const SizedBox(height: 16),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refresh, child: const Text('Tekrar Dene')),
                ],
              ),
            );
          }

          final cases = snapshot.data ?? [];

          if (cases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.local_offer_outlined, size: 80, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text('Henüz teklif yok.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Dava dosyanıza avukat teklifi geldiğinde burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final caseItem = cases[index];
              final teklifSayisi = caseItem['teklifSayisi'] ?? 0;
              
              // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ: 
              // API'den gelen tahminiAlacak String veya num olabilir.
              double tahminiAlacak = 0.0;
              final rawAlacak = caseItem['tahminiAlacak'];
              if (rawAlacak is num) {
                tahminiAlacak = rawAlacak.toDouble();
              } else if (rawAlacak is String) {
                tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$teklifSayisi Teklif',
                            style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          caseItem['sehir'] ?? '',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      caseItem['davaTuru'] ?? 'Kıdem/İhbar Davası',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tahmini Alacak:', style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          currencyFormat.format(tahminiAlacak),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showOffersForCase(caseItem),
                        child: const Text('Teklifleri Görüntüle', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

// Ödeme Modalı
class _PaymentModal extends StatefulWidget {
  final Map<String, dynamic> caseItem;
  final Map<String, dynamic> offer;
  final VoidCallback onPaymentComplete;

  const _PaymentModal({required this.caseItem, required this.offer, required this.onPaymentComplete});

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  final _kartNoController = TextEditingController();
  final _sonKullanmaController = TextEditingController();
  final _cvvController = TextEditingController();
  final _kartSahibiController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _kartNoController.dispose();
    _sonKullanmaController.dispose();
    _cvvController.dispose();
    _kartSahibiController.dispose();
    super.dispose();
  }

  void _processPayment() async {
    if (_kartNoController.text.length < 16 ||
        _sonKullanmaController.text.isEmpty ||
        _cvvController.text.length < 3 ||
        _kartSahibiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm kart bilgilerini girin.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Demo ödeme - gerçek entegrasyon için backend'e bağlanmalı
      await Future.delayed(const Duration(seconds: 2));
      await ApiService.dio.post('/odemeler/guven-bedeli', data: {
        'davaId': widget.caseItem['id'],
        'teklifId': widget.offer['id'],
      });

      if (!mounted) return;
      widget.onPaymentComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ödeme başarılı! Avukat bilgilerine erişebilirsiniz.'), backgroundColor: AppColors.accent),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    
    double tahminiAlacak = 0.0;
    final rawAlacak = widget.caseItem['tahminiAlacak'];
    if (rawAlacak is num) {
      tahminiAlacak = rawAlacak.toDouble();
    } else if (rawAlacak is String) {
      tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text('💳 Platform Hizmet Bedeli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bilgi Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tahmini Alacak:', style: TextStyle(color: AppColors.textSecondary)),
                      Text(currencyFormat.format(tahminiAlacak), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Güven Bedeli:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(currencyFormat.format(99), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Kart Formu
            TextField(
              controller: _kartNoController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              decoration: const InputDecoration(
                labelText: 'Kart Numarası',
                hintText: '0000 0000 0000 0000',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sonKullanmaController,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    decoration: const InputDecoration(
                      labelText: 'Son Kullanma',
                      hintText: 'MM / YY',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kartSahibiController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kart Sahibi',
                hintText: 'AD SOYAD',
              ),
            ),
            const SizedBox(height: 24),
            // Güvenlik Notu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ödeme bilgileriniz güvende. Bu demo uygulamadır. Gerçek ödeme için İyzico/Stripe entegrasyonu yapılacaktır.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              child: _isProcessing
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Ödemeyi Tamamla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
