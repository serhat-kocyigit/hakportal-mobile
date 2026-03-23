import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class OffersSheet extends StatefulWidget {
  final Map<String, dynamic> caseItem;
  final VoidCallback onRefresh;

  const OffersSheet({super.key, required this.caseItem, required this.onRefresh});

  @override
  State<OffersSheet> createState() => _OffersSheetState();
}

class _OffersSheetState extends State<OffersSheet> {
  late Future<List<dynamic>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _fetchOffers();
  }

  Future<List<dynamic>> _fetchOffers() async {
    try {
      final response = await ApiService.dio.get('/offers/case/${widget.caseItem['id']}');
      final data = response.data;
      if (data is List) {
        return data;
      } else if (data is Map && data.containsKey('error')) {
        throw Exception(data['error']);
      }
      return [];
    } catch (e) {
      throw Exception('Teklifler yüklenirken hata: $e');
    }
  }

  void _refresh() {
    setState(() => _offersFuture = _fetchOffers());
    widget.onRefresh();
  }

  void _acceptOffer(Map<String, dynamic> offer) async {
    // Kullanıcı teklifi seçiyor (sec endpoint)
    try {
      await ApiService.dio.put('/offers/${offer['id']}/sec');
      if (!mounted) return;
      Navigator.pop(context); // sheet kapat
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Teklif seçildi! Avukat belgelerinizi inceleyecek.'),
          backgroundColor: AppColors.accent,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _rejectOffer(Map<String, dynamic> offer) async {
    // Reject için şu an backend endpoint yok ama başka teklif seçilebilir.
    // Sadece UI feedback ver.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu teklifi geçtiniz. Diğer teklifleri inceleyebilirsiniz.'),
        backgroundColor: AppColors.textSecondary,
      ),
    );
  }

  void _showPaymentModal(Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PaymentModal(
        caseItem: widget.caseItem,
        offer: offer,
        onPaymentComplete: () {
          Navigator.pop(ctx);
          _refresh();
        },
      ),
    );
  }

  void _goToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          caseId: widget.caseItem['id'].toString(),
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    // Güvenli sayı okuma fonksiyonu
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
    // Backend 'status' döndürüyor (PENDING, SELECTED, REJECTED vs.)
    final status = (offer['status'] ?? 'PENDING').toString();
    final teklifNo = offer['teklifNo'] ?? '';

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
        border: Border.all(
          color: status == 'SELECTED' ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
          width: status == 'SELECTED' ? 1.5 : 1.0,
        ),
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
                child: Center(
                  child: Text(
                    teklifNo.toString(),
                    style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avukat Teklifi #$teklifNo', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      'Anonim • Kimlik korunuyor',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (status == 'SELECTED')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Seçildi', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold)),
                )
              else if (status == 'REJECTED')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Reddedildi', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold)),
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
          // Butonlar - sadece PENDING ise seç butonu göster
          if (status == 'PENDING')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => _acceptOffer(offer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('✅ Bu Teklifi Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _rejectOffer(offer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Geç', style: TextStyle(fontSize: 13)),
                ),
              ],
            )
          else if (status == 'SELECTED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Text('Teklif Seçildi - Avukat İnceliyor', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          else if (status == 'REJECTED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text('Bu teklif geçildi', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avukat Teklifleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            widget.caseItem['davaTuru'] ?? 'Dava',
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
                      const Expanded(
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
            child: FutureBuilder<List<dynamic>>(
              future: _offersFuture,
              builder: (ctx, snapshot) {
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

                final offers = snapshot.data ?? [];

                if (offers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('Henüz teklif yok.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: offers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final offer = offers[idx];
                    return _buildOfferCard(offer);
                  },
                );
              },
            ),
          ),
        ],
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
      // Demo ödeme
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
            TextField(
              controller: _kartNoController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              decoration: const InputDecoration(labelText: 'Kart Numarası', hintText: '0000 0000 0000 0000', counterText: ''),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _sonKullanmaController, keyboardType: TextInputType.number, maxLength: 7, decoration: const InputDecoration(labelText: 'Son Kullanma', hintText: 'MM / YY', counterText: '')),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(controller: _cvvController, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: 'CVV', hintText: '123', counterText: '')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _kartSahibiController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Kart Sahibi', hintText: 'AD SOYAD')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Ödeme bilgileriniz güvende. Bu demo uygulamadır.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              child: _isProcessing ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Ödemeyi Tamamla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
