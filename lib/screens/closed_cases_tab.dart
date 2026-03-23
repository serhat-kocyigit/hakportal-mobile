import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/api_service.dart';

class ClosedCasesTab extends StatefulWidget {
  const ClosedCasesTab({super.key});

  @override
  State<ClosedCasesTab> createState() => _ClosedCasesTabState();
}

class _ClosedCasesTabState extends State<ClosedCasesTab> {
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
    _future = _fetchClosedCases();
  }

  Future<List<dynamic>> _fetchClosedCases() async {
    // Kapanan davaları getirme mantığı
    // Web uygulamasında: t.status === 'SELECTED' && ['KAPANDI', 'CLOSED', 'CANCELED'].includes(t.caseStatus)
    // Server'dan bu formattaki veriler `/api/avukat/kapanan-davalar` (veya tekliflerim) üzerinden geliyor
    // Şimdilik LawyerService.getMyOffers()'i filtreleyerek ya da yeni api metodunu kullanarak alıyoruz.
    try {
      final offers = await LawyerService.getMyOffers();
      final closed = offers.where((t) {
        final status = t['caseStatus'] ?? '';
        final offerStatus = t['status'] ?? '';
        return offerStatus == 'SELECTED' && ['KAPANDI', 'CLOSED', 'CANCELED'].contains(status);
      }).toList();
      return closed;
    } catch (e) {
      throw Exception('Kapanan davalar alınamadı: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchClosedCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

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

          final cases = snapshot.data ?? [];

          if (cases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.lock_outline, size: 80, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text('Kapanan dava kaydınız bulunmuyor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Tamamlanıp kapatılan dava dosyaları burada arşivlenir.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final c = cases[i];
              
              // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ:
              double tahminiAlacak = 0.0;
              final rawAlacak = c['tahminiAlacak'];
              if (rawAlacak is num) {
                tahminiAlacak = rawAlacak.toDouble();
              } else if (rawAlacak is String) {
                tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
              }

              final String davaTuru = c['caseDavaTuru'] ?? 'Hukuki Dava';
              final String sehir = (c['caseSehir'] ?? '').toString();

              final String muvekkilAd = (c['muvekkilAd'] ?? '').toString();
              final String muvekkilInitial = muvekkilAd.isNotEmpty ? muvekkilAd[0].toUpperCase() : 'M';
              final String? muvekkilAvatar = c['muvekkilAvatar'];

              final String ucretText;
              final ucretModeli = c['ucretModeli']?.toString();
              final oranVal = c['oran'];
              if (ucretModeli == 'yuzde') {
                if (oranVal is String && oranVal.contains('/')) {
                  ucretText = oranVal;
                } else {
                  ucretText = '%${oranVal ?? 0}';
                }
              } else {
                ucretText = '${c['sabitUcret'] ?? 0} TL';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık Satırı
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(davaTuru, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text(sehir, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, size: 14, color: AppColors.danger),
                              const SizedBox(width: 6),
                              const Text(
                                'Dava Dosyası Kapandı',
                                style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tahmini Alacak', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          currencyFormat.format(tahminiAlacak),
                          style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ücretim', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(ucretText, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Ekran görüntüsündeki noktalı ayırıcıya benzer
                    _DottedDivider(color: AppColors.border.withValues(alpha: 0.9)),

                    const SizedBox(height: 14),

                    // Kapanan Dosya İletişim Bilgileri Engeli (Web ile birebir)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Müvekkil İletişim Bilgileri:',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildAvatar(
                              avatarPath: muvekkilAvatar,
                              initials: muvekkilInitial,
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Gizli Müvekkil',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline, size: 16, color: AppColors.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dosya Kapandığı İçin İletişim Bilgileri Gizlenmiştir',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Aksiyon Butonları Disabled
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        // Disabled button
                        onPressed: null,
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('🔒 Dosya Kapandı'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
                          disabledForegroundColor: AppColors.danger,
                        ),
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

class _DottedDivider extends StatelessWidget {
  final Color color;
  const _DottedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        const strokeWidth = 1.5;

        return CustomPaint(
          size: Size(constraints.maxWidth, 8),
          painter: _DottedDividerPainter(
            color: color,
            dashWidth: dashWidth,
            dashSpace: dashSpace,
            strokeWidth: strokeWidth,
          ),
        );
      },
    );
  }
}

class _DottedDividerPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DottedDividerPainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    for (double x = 0; x < size.width; x += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(x, centerY),
        Offset(x + dashWidth, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
