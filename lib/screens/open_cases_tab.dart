import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/api_service.dart';
import '../widgets/case_report_widget.dart';

class OpenCasesTab extends StatefulWidget {
  const OpenCasesTab({super.key});

  @override
  State<OpenCasesTab> createState() => _OpenCasesTabState();
}

class _OpenCasesTabState extends State<OpenCasesTab> {
  bool _isLoading = true;
  String? _errorMsg;
  List<dynamic> _cases = [];
  bool _isProfileApproved = false;
  String _cityName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // Önce profil durumunu kontrol et
      final profilRes = await ApiService.dio.get('/avukat/profil');
      final profil = profilRes.data;
      
      _isProfileApproved = (profil['profilOnay'] == 1 || profil['profilOnay'] == true);
      _cityName = profil['sehir'] ?? '';

      if (_isProfileApproved) {
        // Eğer onaylıysa açık davaları çek
        _cases = await LawyerService.getOpenCases();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Avatar URL çözümleme - Web ile birebir aynı
  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null) return '';
    final a = avatar.toString().trim();
    if (a.isEmpty) return '';
    if (a.startsWith('http')) return a;
    final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (a.startsWith('/')) return '$serverRoot$a';
    return '$serverRoot/$a';
  }

  Widget _buildAvatar({required String? avatarUrl, required String initials, required double size}) {
    final resolved = _resolveAvatarUrl(avatarUrl);
    if (resolved.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.primaryDark,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Teklif Verme Modalı (Mevcut Mantık Korundu) ----
  void _showOfferModal(BuildContext ctx, Map<String, dynamic> caseItem) {
    final formKey = GlobalKey<FormState>();
    final tahminiSureCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final oranCtrl = TextEditingController();
    final sabitCtrl = TextEditingController();
    String ucretModeli = 'yuzde';
    bool onOdeme = false;
    bool isSending = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚖️ Teklif Ver', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(caseItem['davaTuru'] ?? 'Hukuki Dava', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),

                  const Text('Ücret Modeli *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ucretModeli,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        items: const [
                          DropdownMenuItem(value: 'yuzde', child: Text('Yüzde (%)')),
                          DropdownMenuItem(value: 'sabit', child: Text('Sabit Ücret (₺)')),
                        ],
                        onChanged: (val) => setSheetState(() => ucretModeli = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (ucretModeli == 'yuzde')
                    TextFormField(
                      controller: oranCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Yüzde Oranı (%)', suffixText: '%'),
                      validator: (v) => v!.isEmpty ? 'Oran girin' : null,
                    )
                  else
                    TextFormField(
                      controller: sabitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sabit Ücret (₺)', prefixText: '₺ '),
                      validator: (v) => v!.isEmpty ? 'Ücret girin' : null,
                    ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ön Ödeme Alıyorum', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Switch(value: onOdeme, activeColor: AppColors.primary, onChanged: (val) => setSheetState(() => onOdeme = val))
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: tahminiSureCtrl,
                    decoration: const InputDecoration(labelText: 'Tahmini Süre *', hintText: 'Örn: 3-6 ay'),
                    validator: (v) => v!.isEmpty ? 'Tahmini süre girin' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: aciklamaCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama (İletişim bilgisi yazmayın)'),
                  ),
                  const SizedBox(height: 8),
                  const Text('⚠️ İletişim bilgisi yazmanız sistem tarafından engellenecektir.', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isSending ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheetState(() => isSending = true);
                      try {
                        await LawyerService.sendOffer(
                          caseId: caseItem['id'],
                          ucretModeli: ucretModeli,
                          oran: ucretModeli == 'yuzde' ? double.tryParse(oranCtrl.text) : null,
                          sabitUcret: ucretModeli == 'sabit' ? double.tryParse(sabitCtrl.text) : null,
                          onOdeme: onOdeme,
                          tahminiSure: tahminiSureCtrl.text.trim(),
                          aciklama: aciklamaCtrl.text.trim(),
                        );
                        if (sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('✅ Teklifiniz başarıyla gönderildi.'), backgroundColor: AppColors.accent),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setSheetState(() => isSending = false);
                        if (sheetCtx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSending
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Teklif Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd.MM.yyyy');

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: () {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (_errorMsg != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                  const SizedBox(height: 16),
                  Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
                ],
              ),
            ),
          );
        }

        if (!_isProfileApproved) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 80),
              Icon(Icons.assignment_late_outlined, size: 80, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text('Profiliniz Onay Bekliyor', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Admin ekibimiz profil bilgilerinizi inceliyor. Onaylandıktan sonra davalara teklif verebilirsiniz.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ],
          );
        }

        if (_cases.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.inbox_outlined, size: 80, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                _cityName.isNotEmpty ? '$_cityName şehrindeki yeni davalar' : 'Şehrinizde Açık Dava Yok',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Şu an açık dava yok. Yeni davalar geldiğinde burada görünecek. Sayfayı yenileyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _cases.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (ctx, i) {
            final c = _cases[i];
            
            // TÜR DÖNÜŞÜM HATASI DÜZELTİLDİ:
            double tahminiAlacak = 0.0;
            final rawAlacak = c['tahminiAlacak'];
            if (rawAlacak is num) {
              tahminiAlacak = rawAlacak.toDouble();
            } else if (rawAlacak is String) {
              tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
            }

            final tarihStr = c['createdAt'] != null ? dateFormat.format(DateTime.parse(c['createdAt'])) : '';
            final bool teklifVerildi = c['teklifVerildi'] == true;
            final int teklifSayisi = c['teklifSayisi'] ?? 0;
            
            // Müvekkil Bilgileri - Web ile birebir aynı alan adları
            final String muvekkilAd = c['muvekkilAd'] ?? '';
            final String muvekkilSoyad = c['muvekkilSoyad'] ?? '';
            // Alternatif alan adlarını dene - Web ile birebir
            final String? muvekkilAvatar = c['muvekkilAvatar'] ?? c['muvekkil_avatar'] ?? c['avatar'] ?? c['userAvatar'] ?? c['user_avatar'];
            final String muvekkilInitials = muvekkilAd.isNotEmpty ? muvekkilAd[0].toUpperCase() : 'M';

            return Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: teklifVerildi ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                  width: teklifVerildi ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kart Başlığı - Web'deki dava-card-header birebir
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['davaTuru'] ?? 'Kıdem/İhbar Davası',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c['sehir'] ?? '-'} • $tarihStr',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // Status Badge - Web'deki gibi
                        if (teklifVerildi)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D9A3).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00D9A3).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 12, color: Color(0xFF00D9A3)),
                                SizedBox(width: 4),
                                Text(
                                  'Teklif Verildi',
                                  style: TextStyle(
                                    color: Color(0xFF00D9A3),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF3A86FF).withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Teklif Bekliyor',
                              style: TextStyle(
                                color: Color(0xFF3A86FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Kart İçeriği - Web'deki dava-card-body birebir
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Müvekkil Gösterimi - Web'deki gibi
                        if (muvekkilAd.isNotEmpty) ...[
                          Row(
                            children: [
                              _buildAvatar(
                                avatarUrl: muvekkilAvatar,
                                initials: muvekkilInitials,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$muvekkilAd $muvekkilSoyad',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      'Müvekkil',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Tahmini Alacak & Teklif Sayısı - Web'deki dava-detail-row birebir
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tahmini Alacak',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(tahminiAlacak),
                                    style: const TextStyle(
                                      color: Color(0xFFA2B9FF),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12, color: AppColors.border),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Mevcut Teklif',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$teklifSayisi avukat',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // YZ Skor & Detaylı Rapor - Web'deki renderDetayliDavaRaporu
                        CaseReportWidget(data: c['hesaplamaVerisi'], c: c),
                        
                        const SizedBox(height: 16),

                        // Aksiyon Butonları - Web'deki dava-card-actions birebir
                        teklifVerildi
                          ? SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check_circle, size: 18, color: Color(0xFF00D9A3)),
                                label: const Text(
                                  'Teklif Gönderildi',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  disabledForegroundColor: const Color(0xFF00D9A3),
                                  side: BorderSide(color: const Color(0xFF00D9A3).withValues(alpha: 0.3)),
                                  backgroundColor: const Color(0xFF00D9A3).withValues(alpha: 0.05),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showOfferModal(context, c),
                                icon: const Icon(Icons.gavel, size: 18),
                                label: const Text(
                                  '⚖️ Teklif Ver',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
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
      }(),
    );
  }
}
