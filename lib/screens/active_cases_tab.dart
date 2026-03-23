import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/case_service.dart';
import '../services/api_service.dart';
import '../widgets/case_report_widget.dart';

class ActiveCasesTab extends StatefulWidget {
  const ActiveCasesTab({super.key});

  @override
  State<ActiveCasesTab> createState() => _ActiveCasesTabState();
}

class _ActiveCasesTabState extends State<ActiveCasesTab> {
  late Future<List<dynamic>> _future;

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null) return '';
    final a = avatar.toString().trim();
    if (a.isEmpty) return '';
    if (a.startsWith('http')) return a;

    final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (a.startsWith('/')) return '$serverRoot$a';
    return '$serverRoot/$a';
  }

  Widget _buildAvatar({required String? avatarPath, required String initials, required double radius}) {
    final resolved = _resolveAvatarUrl(avatarPath);
    if (resolved.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryDark,
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryDark,
      child: ClipOval(
        child: Image.network(
          resolved,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: AppColors.primaryDark,
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _future = LawyerService.getActiveCases();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = LawyerService.getActiveCases();
    });
  }

  String _statusLabel(String status) {
    const map = {
      'MATCHING': '🔍 Eşleşme',
      'WAITING_USER_DEPOSIT': '💳 Güven Bedeli Bekleniyor',
      'WAITING_PAYMENT': '💳 Ödeme Bekleniyor',
      'WAITING_LAWYER_PAYMENT': '💳 Avukat Ödemesi Bekleniyor',
      'PRE_CASE_REVIEW': '🧐 Ön İnceleme',
      'PENDING_USER_AUTH': '⏳ Vekalet Bekleniyor',
      'AUTHORIZED': '✅ Vekalet Onaylı',
      'FILED_IN_COURT': '🏛️ Dava Açıldı',
      'ACTIVE': '🟢 Aktif',
      'IN_PROGRESS': '💬 İşlemde',
      'ILK_GORUSME': '🤝 İlk Görüşme',
      'DAVA_ACILDI': '🏛️ Dava Açıldı',
      'DURUSMA': '⚖️ Duruşma',
      'TAHSIL': '💰 Tahsilat',
      'CLOSED': '🛑 Tamamlandı',
      'KAPANDI': '🛑 Kapatıldı',
    };
    return map[status] ?? status;
  }

  Color _statusColor(String status) {
    if (['AUTHORIZED', 'ACTIVE', 'FILED_IN_COURT', 'IN_PROGRESS', 'DAVA_ACILDI'].contains(status)) return AppColors.accent;
    if (['CLOSED', 'KAPANDI', 'TAHSIL'].contains(status)) return AppColors.textMuted;
    return AppColors.warning;
  }

  Future<void> _requestUserAuth(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Evraklar Yeterli (Vekalet İste)', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Müvekkilinizden resmi vekaletname talep ediyorsunuz. Onaylıyor musunuz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            child: const Text('Evet, Talep Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CaseService.updateStatus(
          caseId: caseId,
          status: 'PENDING_USER_AUTH',
          aciklama: 'Avukat evrakları inceledi ve müvekkilden vekaletname onaylamasını bekliyor.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vekalet isteği gönderildi!'), backgroundColor: AppColors.accent));
          _refresh();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _fileInCourt(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Dava Açıldı', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Müvekkilinizin davasını mahkemeye sunduğunuzu onaylıyor musunuz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black),
            child: const Text('Evet, Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CaseService.updateStatus(
           caseId: caseId,
           status: 'FILED_IN_COURT',
           aciklama: 'Avukat davayı resmi olarak mahkemeye taşıdı.',
        );
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dava durumu güncellendi!'), backgroundColor: AppColors.accent));
           _refresh();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  void _reportCollectionModal(String caseId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('💰 Tahsilat Bildir', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dava başarıyla sonuçlandıysa veya sulh olduysa alınan toplam tutarı girin.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Miktar (TL)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              try {
                await CaseService.updateStatus(
                  caseId: caseId,
                  status: 'TAHSIL',
                  aciklama: 'Avukat davanın sonuçlandığını ve $val TL tahsilat yapıldığını bildirdi.',
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tahsilat bildirildi! Müvekkilin onayı bekleniyor.'), backgroundColor: AppColors.accent));
                  _refresh();
                }
              } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Bildir'),
          ),
        ],
      ),
    );
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

          final allOffers = snapshot.data ?? [];
          
          // Web ile aynı filtreleme mantığı: sadece SELECTED ve aktif davalar
          final cases = allOffers.where((t) {
            final bool isSelected = t['status'] == 'SELECTED';
            final String caseStatus = t['caseStatus'] ?? '';
            final List<String> activeStatuses = [
              'PRE_CASE_REVIEW', 'AUTHORIZED', 'ACTIVE', 'LAWYER_ASSIGNED',
              'FILED_IN_COURT', 'IN_PROGRESS', 'ILK_GORUSME', 'DAVA_ACILDI',
              'DURUSMA', 'TAHSIL'
            ];
            return isSelected && activeStatuses.contains(caseStatus);
          }).toList();

          if (cases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.gavel, size: 80, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text('Henüz aktif dava yok.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Teklifiniz kabul edilip ödeme yapıldıktan sonra burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final c = cases[i];
              
              // Backend /tekliflerim endpoint'i farklı alan adları kullanıyor
              final String davaId = c['caseId']?.toString() ?? c['id']?.toString() ?? '';
              final String davaTuru = c['caseDavaTuru'] ?? c['davaTuru'] ?? 'Hukuki Dava';
              final String sehir = c['caseSehir'] ?? c['sehir'] ?? '';
              final String status = c['caseStatus'] ?? c['status'] ?? 'ACTIVE';
              final String? createdAt = c['createdAt'] ?? c['selectedAt'];
              
              // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ:
              double tahminiAlacak = 0.0;
              final rawAlacak = c['tahminiAlacak'];
              if (rawAlacak is num) {
                tahminiAlacak = rawAlacak.toDouble();
              } else if (rawAlacak is String) {
                tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
              }

              final tarihStr = createdAt != null ? dateFormat.format(DateTime.parse(createdAt)) : '';
              final int okunmamisMesaj = c['okunmamisMesaj'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent), // Web'deki gibi accent border
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık Satırı - Web'deki gibi
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(davaTuru, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(sehir, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        // Web'deki gibi statü badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status == 'PRE_CASE_REVIEW' ? '🧐 Ön İnceleme' :
                            status == 'PENDING_USER_AUTH' ? '⏳ Vekalet İsteğinde' :
                            status == 'AUTHORIZED' ? '✅ Vekalet Onaylı' :
                            status == 'FILED_IN_COURT' ? '🏛️ Dava Açıldı' :
                            status == 'DAVA_ACILDI' ? '🏛️ Dava Açıldı' :
                            status == 'DURUSMA' ? '⚖️ Duruşma' :
                            status == 'TAHSIL' ? '💰 Tahsilat' :
                            status == 'ILK_GORUSME' ? '🤝 İlk Görüşme' :
                            status == 'IN_PROGRESS' ? '💬 İşlemde' :
                            status == 'ACTIVE' ? '🟢 Aktif' : _statusLabel(status),
                            style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tahmini Alacak satırı - Web'deki gibi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tahmini Alacak', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(currencyFormat.format(tahminiAlacak), 
                          style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Ücretim satırı - Web'deki gibi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ücretim', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          c['ucretModeli'] == 'yuzde' 
                            ? '%${c['oran']?.toStringAsFixed(0) ?? '0'}'
                            : currencyFormat.format(c['sabitUcret'] ?? 0),
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),

                    // Müvekkil Bilgisi - Web'deki gibi
                    if (c['muvekkilAd'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAvatar(
                              avatarPath: c['muvekkilAvatar'],
                              initials: (c['muvekkilAd'] ?? '').toString().isNotEmpty
                                  ? (c['muvekkilAd'] ?? '').toString()[0].toUpperCase()
                                  : 'M',
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Müvekkil İletişim Bilgileri:',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c['muvekkilAd']} ${c['muvekkilSoyad']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  if (c['muvekkilEmail'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '📧 ${c['muvekkilEmail']}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    Text(
                                      '📞 ${c['muvekkilTelefon'] ?? '—'}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ] else
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
                                      ),
                                      child: const Text(
                                        '🔒 İletişim bilgileri gizli',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Aksiyon Butonları - Web'deki gibi
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (status == 'PRE_CASE_REVIEW')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _requestUserAuth(davaId),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('✅ Evraklar Yeterli (Vekalet İste)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D9A3),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        if (status == 'AUTHORIZED')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _fileInCourt(davaId),
                              icon: const Icon(Icons.account_balance, size: 18),
                              label: const Text('🏛️ Dava Açıldı (Dosya No Gir)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB300),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        if (['FILED_IN_COURT', 'IN_PROGRESS', 'DURUSMA', 'DAVA_ACILDI'].contains(status))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _reportCollectionModal(davaId),
                              icon: const Icon(Icons.monetization_on_outlined, size: 18),
                              label: const Text('💰 Tahsilat Bildir (Dava Bitti)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/chat/$davaId'),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 18),
                              if (okunmamisMesaj > 0)
                                Positioned(
                                  right: -4, top: -4,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                          label: Text(
                            okunmamisMesaj > 0 ? 'Müvekkilimle Mesajlaş ($okunmamisMesaj)' : '💬 Müvekkilimle Mesajlaş',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                          ),
                        ),
                      ],
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
