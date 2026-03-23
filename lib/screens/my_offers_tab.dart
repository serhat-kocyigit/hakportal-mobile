import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/api_service.dart';
import '../widgets/case_report_widget.dart';

class MyOffersTab extends StatefulWidget {
  const MyOffersTab({super.key});

  @override
  State<MyOffersTab> createState() => _MyOffersTabState();
}

class _MyOffersTabState extends State<MyOffersTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = LawyerService.getMyOffers();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = LawyerService.getMyOffers();
    });
  }

  String _offerStatusLabel(String status) {
    const map = {
      'PENDING': '⏳ Beklemede',
      'SELECTED': '✅ Seçildi',
      'REJECTED': '❌ Reddedildi',
      'REJECTED_BY_LAWYER': '↩️ Vazgeçildi',
      'WAITING_PAYMENT': '💳 Ödeme Bekleniyor',
      'WAITING_LAWYER_PAYMENT': '💳 Ödeme Bekleniyor',
    };
    return map[status] ?? status;
  }

  Color _offerStatusColor(String status) {
    if (status == 'SELECTED' || status == 'WAITING_PAYMENT' || status == 'WAITING_LAWYER_PAYMENT') return AppColors.accent;
    if (status == 'REJECTED' || status == 'REJECTED_BY_LAWYER') return AppColors.danger;
    return AppColors.warning;
  }

  String _caseStatusLabel(String status) {
    const map = {
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
      'TAHSIL': '💰 Tahsil Edildi'
    };
    return map[status] ?? status;
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
        future: _future,
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

          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.local_offer_outlined, size: 80, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text('Henüz teklif vermediniz.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Açık davalar sekmesinden teklif vererek başlayabilirsiniz.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final o = offers[i];
              
              // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ:
              double getAsDouble(dynamic val) {
                if (val is num) return val.toDouble();
                if (val is String) return double.tryParse(val) ?? 0.0;
                return 0.0;
              }

              final tahminiAlacak = getAsDouble(o['tahminiAlacak']);
              final sabitUcret = getAsDouble(o['sabitUcret']);
              final offerStatus = o['status'] ?? 'PENDING';
              final caseStatus = o['caseStatus'] ?? '';
              final engagementStatus = o['engagementStatus'] ?? '';
              final tarihStr = o['createdAt'] != null ? dateFormat.format(DateTime.parse(o['createdAt'])) : '';
              final int okunmamisMesaj = o['okunmamisMesaj'] ?? 0;

              // WEB MANTIĞI BİREBİR:
              final bool isMatching = offerStatus == 'SELECTED' && caseStatus == 'MATCHING' && engagementStatus != 'WAITING_USER_DEPOSIT';
              final bool isWaitingUserDeposit = offerStatus == 'SELECTED' && (engagementStatus == 'WAITING_USER_DEPOSIT' || caseStatus == 'WAITING_USER_DEPOSIT');
              final bool isWaitingLawyerPayment = offerStatus == 'SELECTED' && (caseStatus == 'WAITING_LAWYER_PAYMENT' || caseStatus == 'WAITING_PAYMENT');

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMatching || isWaitingLawyerPayment 
                      ? (isMatching ? Colors.amber : AppColors.accent)
                      : _offerStatusColor(offerStatus).withValues(alpha: 0.4),
                    width: offerStatus == 'SELECTED' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o['caseDavaTuru'] ?? 'Hukuki Dava', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('${o['caseSehir'] ?? ''} • $tarihStr', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _offerStatusColor(offerStatus).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(_offerStatusLabel(offerStatus), style: TextStyle(color: _offerStatusColor(offerStatus), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: AppColors.border),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banners
                          if (isMatching) _buildBanner('🧐', 'Belge İnceleme Aşaması', 'Müvekkilin belgelerini inceleyin. Davayı kabul edin ya da vazgeçin.', Colors.amber),
                          if (isWaitingUserDeposit) _buildBanner('⏳', 'Müvekkil Güven Bedeli Bekleniyor', 'Müvekkil 99 TL güven bedelini ödediğinde platform bedeli ödeme aşamasına geçeceksiniz.', Colors.amber),
                          if (isWaitingLawyerPayment) _buildBanner('💳', 'Platform Bedeli Bekleniyor', 'Müvekkil 99 TL güven bedelini ödedi. Sıra sizde — platform bedelini ödeyerek süreci başlatın.', AppColors.accent),

                          // Alacak & Teklif Bilgisi
                          _buildDetailRow('Tahmini Alacak', currencyFormat.format(tahminiAlacak), isValuePrimary: true),
                          const SizedBox(height: 8),
                          _buildDetailRow('Sizin Teklifiniz', o['ucretModeli'] == 'yuzde' ? '%${o['oran']}' : currencyFormat.format(sabitUcret)),
                          
                          if (caseStatus.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Dava Durumu', _caseStatusLabel(caseStatus)),
                          ],

                          // Case Analysis
                          CaseReportWidget(data: o['hesaplamaVerisi'], c: o),

                          // Müvekkil Bilgileri (İletişim Açıkken)
                          if (o['muvekkilAd'] != null && !isMatching && !isWaitingUserDeposit && !isWaitingLawyerPayment && !['CLOSED', 'KAPANDI', 'CANCELED'].contains(caseStatus))
                             _buildMuvekkilInfo(o),

                          const SizedBox(height: 16),

                          // Actions
                          if (isMatching) ...[
                             Row(
                               children: [
                                 Expanded(
                                   child: ElevatedButton(
                                     onPressed: () => _confirmKabul(o['id']),
                                     style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                                     child: const Text('✅ Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: OutlinedButton(
                                     onPressed: () => _confirmVazgec(o['id']),
                                     style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                                     child: const Text('↩️ Vazgeç'),
                                   ),
                                 ),
                               ],
                             ),
                          ],

                          if (isWaitingLawyerPayment)
                             SizedBox(
                               width: double.infinity,
                               child: ElevatedButton(
                                 onPressed: () => _showOdemeModal(o['id'], tahminiAlacak),
                                 style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                                 child: Text('💸 Platform Bedelini Öde (${_calculateFee(tahminiAlacak)} TL)'),
                               ),
                             ),

                          if (offerStatus == 'SELECTED' && ['PRE_CASE_REVIEW', 'AUTHORIZED', 'ACTIVE', 'LAWYER_ASSIGNED', 'FILED_IN_COURT', 'IN_PROGRESS', 'ILK_GORUSME', 'DAVA_ACILDI', 'DURUSMA', 'TAHSIL'].contains(caseStatus))
                             SizedBox(
                               width: double.infinity,
                               child: ElevatedButton.icon(
                                 onPressed: () => _openSohbet(o['caseId']),
                                 icon: const Icon(Icons.chat_bubble_outline),
                                 label: Text('Müvekkilinizle Mesajlaş${okunmamisMesaj > 0 ? " ($okunmamisMesaj)" : ""}'),
                               ),
                             ),

                           if (offerStatus == 'SELECTED' && ['CLOSED', 'KAPANDI', 'CANCELED'].contains(caseStatus))
                             const SizedBox(
                               width: double.infinity,
                               child: OutlinedButton(
                                 onPressed: null,
                                 child: Text('🔒 Dava Dosyası Kapandi'),
                               ),
                             ),
                           
                           if (offerStatus == 'PENDING')
                             const SizedBox(
                               width: double.infinity,
                               child: OutlinedButton(
                                 onPressed: null,
                                 child: Text('⏳ Kullanıcı Kararını Bekliyor'),
                               ),
                             ),

                           if (isWaitingUserDeposit)
                             const SizedBox(
                               width: double.infinity,
                               child: OutlinedButton(
                                 onPressed: null,
                                 child: Text('⏳ Müvekkil Güven Bedeli Bekleniyor'),
                               ),
                             ),

                        ],
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

  Widget _buildBanner(String icon, String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isValuePrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isValuePrimary ? AppColors.primaryLight : null,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMuvekkilInfo(dynamic o) {
     return Container(
       padding: const EdgeInsets.only(top: 12),
       decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, style: BorderStyle.solid))),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Müvekkil İletişim Bilgileri:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
           const SizedBox(height: 4),
           Row(
             children: [
               const Icon(Icons.account_circle, color: AppColors.textMuted),
               const SizedBox(width: 8),
               Expanded(child: Text('${o['muvekkilAd']} ${o['muvekkilSoyad']}', style: const TextStyle(fontWeight: FontWeight.bold))),
             ],
           ),
           if (o['muvekkilEmail'] != null) Text(o['muvekkilEmail'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
           if (o['muvekkilTelefon'] != null) Text(o['muvekkilTelefon'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
         ],
       ),
     );
  }

  int _calculateFee(double alacak) {
    if (alacak < 20000) return 750;
    if (alacak < 50000) return 1250;
    return 2000;
  }

  void _confirmKabul(String offerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dosyayı Kabul Et'),
        content: const Text('Belgeleri incelediniz ve bu davayı üstlenmek istiyorsunuz. Müvekkile bildirim gidecek ve güven bedeli yatırması istenecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await LawyerService.acceptMatching(offerId);
                _refresh();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Dosya kabul edildi.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Evet, Kabul Et'),
          ),
        ],
      ),
    );
  }

  void _confirmVazgec(String offerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dosyadan Vazgeç'),
        content: const Text('Bu davayı üstlenmek istemediğinizi mi belirtmek istiyorsunuz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await LawyerService.withdrawFromMatching(offerId);
                _refresh();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('↩️ Vazgeçildi.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Evet, Vazgeç', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showOdemeModal(String offerId, double alacak) {
    // Ödeme modalı normalde ayrı bir widget olur ama burada basitleştirerek dialog yapıyoruz
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Platform Bedeli Öde'),
        content: Text('Davayı başlatmak için ${_calculateFee(alacak)} TL platform bedeli ödemeniz gerekmektedir.'),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
           ElevatedButton(
             onPressed: () async {
               Navigator.pop(ctx);
               // Ödeme işlemi simülasyonu / API çağrısı
               try {
                 // Web'deki avukat-odeme rutosuna benzer bir servis çağrısı
                 await LawyerService.payPlatformFee(offerId, {
                   'kartNo': '4444444444444444',
                   'sonKullanma': '12/26',
                   'cvv': '123',
                   'kartSahibi': 'Avukat'
                 });
                 _refresh();
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Ödeme başarılı!')));
               } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
               }
             },
             child: const Text('Ödemeyi Yap'),
           ),
        ],
      ),
    );
  }

  void _openSohbet(String caseId) {
    if (caseId.isNotEmpty) {
      context.push('/chat/$caseId');
    }
  }
}
