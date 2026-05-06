import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class CaseReportWidget extends StatelessWidget {
  final dynamic rawData;
  final Map<String, dynamic> c;
  final bool isLawyer;

  const CaseReportWidget({
    super.key, 
    required dynamic data, 
    required this.c,
    this.isLawyer = false,
  }) : rawData = data;

  Map<String, dynamic>? get parsedData {
    if (rawData == null) return null;
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    if (rawData is String) {
      try {
        return jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  String _mapCikisSekli(String? cikis) {
    if (cikis == null) return 'Bilinmiyor';
    switch (cikis) {
      case 'isverenTarafindan': return 'İşveren Tarafından Fesih';
      case 'hakliFesihIsci': return 'Haklı Nedenle Fesih (İşçi)';
      case 'isciIstifasi': return 'İstifa (İşçi Beyanı)';
      case 'asilliNeden': return 'Ahlak/İyi Niyet İhlali (İşveren 25/2)';
      case '02_deneme_suresi': return 'Deneme Süresi';
      case '04_haksiz_fesih': return 'Haksız Fesih';
      case '05_belirli_sure': return 'Belirli Süreli Sözleşme Bitimi';
      default: return cikis;
    }
  }

  String _formatDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '?';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildHamBeyanSatiri(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSkorBox(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }

  Widget _buildHakBox(String label, double val, Color color) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(currencyFormat.format(val), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildEkHakBox(String label, double val, Color color) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text('⚖️ ', style: TextStyle(fontSize: 10, color: color)),
              Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          Text(currencyFormat.format(val), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    List<Widget> content = [];

    // DEBUG: Log the incoming data structure
    debugPrint('CASE_REPORT_DEBUG: rawData type = ${rawData?.runtimeType}');
    debugPrint('CASE_REPORT_DEBUG: c keys = ${c.keys.toList()}');
    debugPrint('CASE_REPORT_DEBUG: skorToplam = ${c['skorToplam']}, caseSkorToplam = ${c['caseSkorToplam']}');
    debugPrint('CASE_REPORT_DEBUG: parsedData skorToplam = ${parsedData?['skorToplam']}');

    try {
      // 1. YZ RİSK / SKOR PANELİ
      // Web ile birebir çalışması için "skorToplam" değerini daha agresif okuyoruz.
      // data üzerinden de gelebilir ihtimaline karşı:
      final sToplamRaw = c['skorToplam'] ?? c['caseSkorToplam'] ?? c['skor_toplam'] ?? c['toplamSkor'] ??
                          c['aiScore'] ?? c['score'] ?? c[' Skor'] ?? c['case_score'] ??
                          parsedData?['skorToplam'] ?? parsedData?['skor_toplam'] ??
                          c['yzSkor'] ?? c['yz_skor'] ?? c['ai_skor'];
      final bool yzAktif = sToplamRaw != null;
      
      debugPrint('CASE_REPORT_DEBUG: sToplamRaw resolved to = $sToplamRaw, yzAktif = $yzAktif');

      if (isLawyer && (yzAktif || true)) { // Avukatlar için zorla göster, kullanıcılar için gizle
        final kat = c['riskKategorisi'] ?? c['caseRiskKategorisi'] ?? parsedData?['riskKategorisi'] ?? 'BILINMIYOR';
        Color badgeColor = AppColors.textPrimary;
        if (kat == 'PREMIUM') badgeColor = const Color(0xFFFB5607);
        else if (kat == 'NORMAL') badgeColor = const Color(0xFF3A86FF);
        else if (kat == 'RISKLI') badgeColor = const Color(0xFFFFBE0B);
        else if (kat == 'COK_RISKLI') badgeColor = const Color(0xFFFF006E);

        final sToplam = sToplamRaw ?? 0;
        final sHukuki = c['skorHukuki'] ?? c['caseSkorHukuki'] ?? parsedData?['skorHukuki'] ?? 0;
        final sVeri = c['skorVeri'] ?? c['caseSkorVeri'] ?? parsedData?['skorVeri'] ?? 0;
        final sTahsil = c['skorTahsil'] ?? c['caseSkorTahsil'] ?? parsedData?['skorTahsil'] ?? 0;
        
        dynamic rNotlariRaw = c['riskNotlari'] ?? c['caseRiskNotlari'] ?? parsedData?['riskNotlari'];
        List notList = [];
        if (rNotlariRaw is List) {
          notList = List.from(rNotlariRaw);
        } else if (rNotlariRaw is String && rNotlariRaw.isNotEmpty) {
          try { 
            final decoded = jsonDecode(rNotlariRaw);
            if (decoded is List) notList = List.from(decoded);
          } catch (_) {}
        }

        content.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🤖 YZ DOSYA ANALİZİ: $kat', style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$sToplam', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const Text('/100', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), style: BorderStyle.solid))),
                  child: Row(
                    children: [
                      Expanded(child: _buildSkorBox('Hukuki Güç', '$sHukuki/100', const Color(0xFF3A86FF))),
                      Expanded(child: _buildSkorBox('Veri Tutarlılığı', '$sVeri/100', (_parseDouble(sVeri) < 50) ? AppColors.danger : AppColors.accent)),
                      Expanded(child: _buildSkorBox('Tahsil İhtimali', '$sTahsil/100', Colors.white)),
                    ],
                  ),
                ),
                if (notList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: notList.map((not) => Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(not.toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                          ],
                        ),
                      )).toList(),
                    ),
                  )
              ],
            ),
          )
        );
      }

      final data = parsedData;

      if (data == null) {
        debugPrint('CASE_REPORT_DEBUG: parsedData is null, returning only AI panel');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content);
      }

      // 2. HUKUKİ NİTELENDİRME
      content.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.05),
                  border: const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚖️ Hukuki Nitelendirme', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Tahmini Toplam', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            Text(currencyFormat.format(_parseDouble(data['toplamNet'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(data['legal']?['gerekce'] ?? 'Sistem tarafından dava konusu derlendi.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ],
                ),
              ),
              
              // Tazminat Kalemleri
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_parseDouble(data['kidem']?['net']) > 0 || _parseDouble(data['ihbar']?['net']) > 0)
                      Row(
                        children: [
                          if (_parseDouble(data['kidem']?['net']) > 0)
                            Expanded(child: _buildHakBox('Kıdem Tazminatı', _parseDouble(data['kidem']['net']), const Color(0xFF00D9A3))),
                          if (_parseDouble(data['kidem']?['net']) > 0 && _parseDouble(data['ihbar']?['net']) > 0)
                            const SizedBox(width: 8),
                          if (_parseDouble(data['ihbar']?['net']) > 0)
                            Expanded(child: _buildHakBox('İhbar Tazminatı', _parseDouble(data['ihbar']['net']), const Color(0xFFA2B9FF))),
                        ],
                      ),

                    const SizedBox(height: 8),
                    
                    // Diğer Haklar
                    Builder(
                      builder: (ctx) {
                        final diger = data['diger'] as Map<String, dynamic>? ?? {};
                        final eHaklar = [
                          {'name': 'Boşta Geçen Süre', 'val': _parseDouble(diger['bostaGecenSureBrut']), 'color': const Color(0xFF52B788)},
                          {'name': 'İşe Başlatmama', 'val': _parseDouble(diger['iseBaslatmamaBrut']), 'color': const Color(0xFFFFB703)},
                          {'name': 'Kötü Niyet', 'val': _parseDouble(diger['kotuNiyetNet']), 'color': const Color(0xFFE63946)},
                          {'name': 'Sendikal', 'val': _parseDouble(diger['sendikalNet']), 'color': const Color(0xFF9D4EDD)},
                          {'name': 'Ödenmemiş Maaş', 'val': _parseDouble(diger['odenmemisMaasBrut']), 'color': const Color(0xFF4CC9F0)},
                          {'name': 'Fazla Mesai', 'val': _parseDouble(diger['mesaiBrut']), 'color': const Color(0xFFF72585)},
                          {'name': 'Yıllık İzin', 'val': _parseDouble(diger['izinBrut']), 'color': const Color(0xFFF8961E)},
                          {'name': 'Bakiye Süre', 'val': _parseDouble(diger['bakiyeSureTazminatBrut']), 'color': const Color(0xFF43AA8B)},
                        ].where((h) => (h['val'] as double) > 0).toList();

                        if (eHaklar.isEmpty) return const SizedBox();

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.5,
                          ),
                          itemCount: eHaklar.length,
                          itemBuilder: (ctx, i) => _buildEkHakBox(eHaklar[i]['name'] as String, eHaklar[i]['val'] as double, eHaklar[i]['color'] as Color),
                        );
                      }
                    ),
                    
                    // ÜYE HAM BEYANLARI
                    if (data['_inputs'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('📌 ', style: TextStyle(fontSize: 12)),
                                Text('Üye Ham Beyanları (Form Girdileri):', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildHamBeyanSatiri('Çıkış', _mapCikisSekli(data['_inputs']?['cikisSekli'])),
                            _buildHamBeyanSatiri('Dönem', '${_formatDateStr(data['_inputs']?['isGirisTarihi'])} -> ${_formatDateStr(data['_inputs']?['isCikisTarihi'])} (${data['calismaGun'] ?? '?'} Gün)'),
                            _buildHamBeyanSatiri('Maaş', '${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(_parseDouble(data['_inputs']?['brutMaas']))} Brüt | Yan Hak: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(_parseDouble(data['_inputs']?['yanHaklar']))}'),
                            _buildHamBeyanSatiri('Eksik', '${data['_inputs']?['kullanilmayanIzinGun'] ?? 0} Gün İzin / ${data['_inputs']?['haftalikFazlaMesai'] ?? 0} Saat Mesai'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        )
      );

      // 3. İSPAT BELGELERİ (Avukatlar için kritik)
      final List? belgeler = c['ispatBelgeleri'] ?? c['ispat_belgeleri'];
      if (belgeler != null && belgeler.isNotEmpty) {
        content.add(
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📄 ', style: TextStyle(fontSize: 14)),
                    Text('İSPAT BELGELERİ:', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                ...belgeler.map((b) {
                  final name = b['name']?.toString() ?? 'Belge';
                  final url = b['url']?.toString();
                  return InkWell(
                    onTap: () => _openUrl(url),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 14, color: AppColors.primaryLight),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                const Text(
                  '💡 Bu belgeler teklifiniz kabul edildikten sonra erişilebilir olacaktır.',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      } else if ((c['belgeSayisi'] ?? 0) > 0) {
        content.add(
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Text('📄 ', style: TextStyle(fontSize: 14)),
                Text(
                  'SİSTEMDE ${c['belgeSayisi']} ADET İSPAT BELGESİ YÜKLÜ',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('CASE_REPORT_ERROR: $e');
      debugPrint('CASE_REPORT_STACK: $stackTrace');
      // Hata durumunda en azından bir hata mesajı göster
      content.add(
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.danger.withValues(alpha: 0.1),
          child: Text('Rapor yüklenirken hata: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content);
  }
  
  Future<void> _openUrl(String? urlPath) async {
    if (urlPath == null || urlPath.isEmpty) return;
    String finalUrl = urlPath;
    if (!urlPath.startsWith('http')) {
      final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
      if (urlPath.startsWith('/')) {
        finalUrl = '$serverRoot$urlPath';
      } else {
        finalUrl = '$serverRoot/$urlPath';
      }
    }
    try {
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }
}
