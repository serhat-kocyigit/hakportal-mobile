import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../core/theme/app_colors.dart';
import '../services/calculation_service.dart';
import '../services/case_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/document_scan_service.dart';

class CalculatorTab extends StatefulWidget {
  final bool isEmbedded;
  const CalculatorTab({super.key, this.isEmbedded = false});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  final _formKey = GlobalKey<FormState>();

  // Kullanıcı Profili
  Map<String, dynamic>? _userProfile;
  String? _userCity;

  // Ön Değerlendirme Testi State
  bool _showPreTest = true;
  String? _ptKimCikardi;
  String? _ptSure;
  String? _ptMaas;

  String? _fesihYapan;
  String? _isverenSebep;
  String? _isciSebep;
  String? _isyeriCalisanSayisi;
  bool? _iadeSuresiGectiMi;
  String? _eldenOdeme;
  String? _isverenTuru;
  String? _yaziliFesihBelgesi;

  int _wizardStep = 2;
  final List<Map<String, dynamic>> _wizardHistory = [];
  Map<String, dynamic> _wizardAnswers = {};
  List<PlatformFile> _wizardSelectedFiles = [];
  bool _wizardUploading = false;
  List<Map<String, String>> _wizardUploadedUrls = [];
  bool _wizardScanning = false;
  List<Map<String, dynamic>> _wizardScanResults = [];
  Map<String, dynamic>? _wizardCombinedAnalysis;

  // Form State
  DateTime? _startDate;
  DateTime? _endDate;
  final _salaryController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _vacationDaysController = TextEditingController();
  final _overtimeController = TextEditingController();
  final _unpaidSalaryController = TextEditingController();
  final _taxBaseController = TextEditingController();

  bool _isCalculating = false;
  Map<String, dynamic>? _lastCalculationResult;
  String? _createdCaseId; // Oluşturulan dava ID'si (belge yükleme için)

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _userCity = profile['sehir']?.toString();
      });
    } catch (e) {
      // Profil yüklenemese bile devam et
      debugPrint('Profil yüklenemedi: $e');
    }
  }

  void _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnackBar('Lütfen işe giriş ve çıkış tarihlerini seçin.', AppColors.danger);
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final dfLog = DateFormat('yyyy-MM-dd');
      
      // aiFacts oluştur
      final aiFacts = _buildAiFacts();
      
      final resultData = await CalculationService.calculate(
        isGirisTarihi: dfLog.format(_startDate!),
        isCikisTarihi: dfLog.format(_endDate!),
        brutMaas: double.tryParse(_salaryController.text) ?? 0,
        cikisSekli: _getCikisSekliKodu(),
        yanHaklar: double.tryParse(_benefitsController.text) ?? 0,
        kullanilmayanIzin: double.tryParse(_vacationDaysController.text) ?? 0,
        fazlaMesai: double.tryParse(_overtimeController.text) ?? 0,
        odenmemisMaasGun: double.tryParse(_unpaidSalaryController.text) ?? 0,
        kumulatifMatrah: double.tryParse(_taxBaseController.text) ?? 0,
        aiFacts: aiFacts,
      );

      setState(() {
        _isCalculating = false;
        _lastCalculationResult = resultData;
      });
      
      _showResultModal(resultData);

    } catch (e) {
      setState(() => _isCalculating = false);
      _showSnackBar(e.toString(), AppColors.danger);
    }
  }

  Map<String, dynamic> _buildAiFacts() {
    return {
      'cikisSekli': _getCikisSekliKodu(),
      'fesihYapan': _fesihYapan,
      'isverenSebep': _isverenSebep,
      'isciSebep': _isciSebep,
      'isyeriCalisanSayisi': _isyeriCalisanSayisi,
      'iadeSuresiGectiMi': _iadeSuresiGectiMi,
      'eldenOdeme': _eldenOdeme,
      'isverenTuru': _isverenTuru,
      'yaziliFesihBelgesi': _yaziliFesihBelgesi,
      'wizardEvraklar': _wizardUploadedUrls,
      'calismaSuresi': _ptSure,
      'maasDurumu': _ptMaas,
    };
  }

  String _getCikisSekliKodu() {
    if (_fesihYapan == 'isveren') {
      if (_isverenSebep == 'haksiz_gecerli') return 'isverenIstifasi';
      if (_isverenSebep == 'ahlak') return 'ahlakFeshi';
      return 'isverenFeshi';
    } else {
      if (_isciSebep == 'askerlik') return 'askerlik';
      if (_isciSebep == 'emeklilik') return 'emeklilik';
      if (_isciSebep == 'evlilik') return 'evlilik';
      if (_isciSebep == 'hakli_neden') return 'hakliFesih';
      return 'isciIstifasi';
    }
  }

  void _showSnackBar(String msg, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bgColor),
    );
  }

  void _showResultModal(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final double toplamNet = (data['toplamNet'] ?? 0).toDouble();
    final Map<String, dynamic> kidem = data['kidem'] ?? {};
    final Map<String, dynamic> ihbar = data['ihbar'] ?? {};
    final Map<String, dynamic> diger = data['diger'] ?? {};
    final Map<String, dynamic> skorlama = data['skorlama'] ?? {};
    final Map<String, dynamic> legal = data['legal'] ?? {};
    final Map<String, dynamic>? alternatif = data['alternatifSenaryo'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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

              // Skorlama (Web'deki gibi)
              if (skorlama.isNotEmpty) _buildSkorlamaCardWeb(skorlama, formatter),
              
              // Hukuki Gerekçe (Web'deki gibi)
              if (legal.isNotEmpty && legal['gerekce'] != null) _buildLegalCardWeb(legal),
              
              // Toplam Net (Web'deki gibi - büyük yeşil)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Tahmini Toplam Net Alacak', 
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      formatter.format(toplamNet),
                      style: const TextStyle(
                        color: AppColors.accent, 
                        fontSize: 32, 
                        fontWeight: FontWeight.w900
                      ),
                    ),
                  ],
                ),
              ),
              
              // Kıdem ve İhbar Kutuları (Web'deki gibi - yan yana)
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCalcBoxWeb(
                      'Kıdem Tazminatı',
                      kidem['net'] ?? 0,
                      formatter,
                      kidem['net'] != null && kidem['net'] > 0 ? AppColors.accent : AppColors.textMuted,
                      kidem['net'] != null && kidem['net'] > 0,
                      'Tam Yıl/Kısmi Yıl Esası (Damga Düşülmüştür)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCalcBoxWeb(
                      'İhbar Tazminatı',
                      ihbar['net'] ?? 0,
                      formatter,
                      ihbar['net'] != null && ihbar['net'] > 0 ? const Color(0xFFa2b9ff) : AppColors.textMuted,
                      ihbar['net'] != null && ihbar['net'] > 0,
                      'Giydirilmiş Ücret Bazlı NET Hakediş',
                    ),
                  ),
                ],
              ),

              // Ekstra Haklar (Web'deki gibi)
              if (diger['izinBrut'] != null && diger['izinBrut'] > 0)
                _buildExtraCardWeb('🌴 Yıllık İzin Ücreti', diger['izinBrut'], formatter, 
                  'Kullanılmayan izinlerinizin brüt yevmiyesi üzerinden hesaplanmıştır.', AppColors.textPrimary),
              
              if (diger['mesaiBrut'] != null && diger['mesaiBrut'] > 0)
                _buildExtraCardWeb('⏱️ Fazla Mesai Ücreti', diger['mesaiBrut'], formatter,
                  'Fazla çalışılan saatler, yasaya uygun olarak %150 zamlı ücretten hesaplanmıştır.', AppColors.textPrimary),
              
              if (diger['odenmemisMaasBrut'] != null && diger['odenmemisMaasBrut'] > 0)
                _buildExtraCardWeb('💼 Ödenmemiş Maaş', diger['odenmemisMaasBrut'], formatter,
                  'Kıstelyevm hesabıyla gün bazlı hak edişiniz.', AppColors.textPrimary),

              if (diger['kotuNiyetNet'] != null && diger['kotuNiyetNet'] > 0)
                _buildExtraCardWeb('🚨 Kötü Niyet Tazminatı', diger['kotuNiyetNet'], formatter,
                  'İhbar Tazminatının 3 katı tutarında emsal ceza.', const Color(0xFFff4d4f), isDanger: true),

              if (diger['sendikalNet'] != null && diger['sendikalNet'] > 0)
                _buildExtraCardWeb('🚩 Sendikal Tazminat', diger['sendikalNet'], formatter,
                  '1 Yıllık brüt olmayan çıplak ücret tutarı.', const Color(0xFF1890ff), isInfo: true),

              if (diger['bakiyeSureTazminatBrut'] != null && diger['bakiyeSureTazminatBrut'] > 0)
                _buildExtraCardWeb('⏳ Bakiye Süre Ücreti', diger['bakiyeSureTazminatBrut'], formatter,
                  'Belirli Süreli Sözleşme Erken Fesih (Kalan aylar).', AppColors.textPrimary),

              if (diger['bostaGecenSureBrut'] != null && diger['bostaGecenSureBrut'] > 0)
                _buildExtraCardWeb('⚖️ Boşta Geçen Süre Ücreti (İşe İade)', diger['bostaGecenSureBrut'], formatter,
                  'Maksimum 4 Aya kadar koruma ücreti.', const Color(0xFF52c41a), isSuccess: true),

              if (diger['iseBaslatmamaBrut'] != null && diger['iseBaslatmamaBrut'] > 0)
                _buildExtraCardWeb('⚖️ İşe Başlatmama Tazminatı (İşe İade)', diger['iseBaslatmamaBrut'], formatter,
                  'İşe iade kararına rağmen başlatılmama durumunda.', const Color(0xFFfaad14), isWarning: true),

              // Alternatif Senaryo (Web'deki gibi)
              if (alternatif != null) _buildAlternatifCardWeb(alternatif, data, formatter),

              // Disclaimer
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Bu hesaplama 2026 Gelir Vergisi Dilimleri ile Yargıtay Standartlarında net / brüt matrah mantıklarına göre hazırlanmıştır. Kesin ve resmi kurallardır, bilgi amaçlıdır.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),

              // Buton
              if (toplamNet > 0) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showTeklifModal();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '⚖️ Avukatlardan Teklif Al →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Web'deki gibi skorlama kartı
  Widget _buildSkorlamaCardWeb(Map<String, dynamic> skorlama, NumberFormat formatter) {
    final String kategori = skorlama['kategori'] ?? 'NORMAL';
    final int toplam = skorlama['toplam'] ?? 0;
    final int hukuki = skorlama['hukuki'] ?? 0;
    final int veri = skorlama['veri'] ?? 0;
    final int tahsilat = skorlama['tahsilat'] ?? skorlama['tahsil'] ?? 0;
    final List<dynamic> notlar = skorlama['notlar'] ?? [];

    Color bgKat;
    switch (kategori) {
      case 'PREMIUM': bgKat = const Color(0xFFfb5607); break;
      case 'NORMAL': bgKat = const Color(0xFF3a86ff); break;
      case 'RISKLI': bgKat = const Color(0xFFffbe0b); break;
      default: bgKat = const Color(0xFFff006e);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgKat),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🤖 Dosya Risk ve İspat Skorunuz',
                style: TextStyle(color: bgKat, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '$toplam/100',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSkorItemWeb('Hak Doğumu', hukuki, AppColors.primaryLight),
              ),
              Expanded(
                child: _buildSkorItemWeb('İspat / Delil', veri, veri < 50 ? AppColors.danger : AppColors.accent),
              ),
              Expanded(
                child: _buildSkorItemWeb('Tahsilat İhtimali', tahsilat, tahsilat < 50 ? AppColors.danger : AppColors.accent),
              ),
            ],
          ),
          if (notlar.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notlar.map((not) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Text('⚠️ ', style: TextStyle(color: AppColors.danger)),
                  Expanded(
                    child: Text(
                      not.toString(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )),
          ],
          const SizedBox(height: 8),
          const Text(
            'Puanınız avukatlar tarafından görülecek ve davanızın alınma hızını etkileyecektir.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSkorItemWeb(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          '$value/100',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildLegalCardWeb(Map<String, dynamic> legal) {
    final String gerekce = legal['gerekce'] ?? '';
    final List<dynamic> uyarilar = legal['uyarilar'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚖️ Hukuki Gerekçe ve Nitelendirme',
            style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            gerekce,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          if (uyarilar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠️ Motor Uyarısı: ${uyarilar.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF856404)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalcBoxWeb(String title, dynamic value, NumberFormat formatter, Color color, bool hasValue, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? formatter.format(value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0) : 'Hak yok',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
          if (hasValue) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border.withAlpha(100))),
              ),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtraCardWeb(String title, dynamic value, NumberFormat formatter, String subtitle, Color color, {bool isDanger = false, bool isInfo = false, bool isSuccess = false, bool isWarning = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDanger ? const Color(0xFFff4d4f) : 
                isInfo ? const Color(0xFF1890ff) :
                isSuccess ? const Color(0xFF52c41a) :
                isWarning ? const Color(0xFFfaad14) :
                AppColors.border,
          width: isDanger || isInfo || isSuccess || isWarning ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            formatter.format(value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternatifCardWeb(Map<String, dynamic> alt, Map<String, dynamic> result, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFe63946), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFe63946),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '🛑 ÇAKIŞAN SENARYO — Belgedeki Fesih Türü Beyanınızla Eşleşmiyor',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEYANINIZA GÖRE',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text('Kıdem: ${formatter.format(result['kidem']?['net'] ?? 0)}', style: const TextStyle(fontSize: 12)),
                      Text('İhbar: ${formatter.format(result['ihbar']?['net'] ?? 0)}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        formatter.format(result['toplamNet'] ?? 0),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 80, color: AppColors.border),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alt['aciklama']?.toString().toUpperCase() ?? 'ALTERNATİF',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFe63946)),
                        ),
                        const SizedBox(height: 4),
                        Text('Kıdem: ${formatter.format(alt['kidem']?['net'] ?? 0)}', style: const TextStyle(fontSize: 12)),
                        Text('İhbar: ${formatter.format(alt['ihbar']?['net'] ?? 0)}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(
                          formatter.format(alt['toplamNet'] ?? 0),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFe63946)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFe63946).withAlpha(20),
            ),
            child: const Text(
              '⚡ Avukatınız hangi senaryonun geçerli olduğunu belirleyecek; haklarınız risk altında olabilir.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeklifModal() {
    final davaTurleri = [
      _DavaTuru('kıdem-ihbar', 'Kıdem / İhbar Tazminatı'),
      _DavaTuru('fazla-mesai', 'Fazla Mesai'),
      _DavaTuru('yillik-izin', 'Yıllık İzin'),
      _DavaTuru('ucret-alacagi', 'Ücret Alacağı'),
      _DavaTuru('diger', 'Diğer'),
    ];
    
    String? selectedTuru;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  const Expanded(
                    child: Text('⚖️ Avukatlardan Teklif Al', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Hesapladığınız davanızı şimdi platformdaki yörenizin avukatlarına sunun.', 
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              
              const Text('Dava Türü', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTuru,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Dava türü seçin...'),
                    ),
                    isExpanded: true,
                    dropdownColor: AppColors.bgCard,
                    items: davaTurleri.map((t) => DropdownMenuItem(
                      value: t.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(t.label),
                      ),
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedTuru = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🔒 Güvence: Kişisel verileriniz avukatlara gösterilmez. Sadece karşılıklı onayda açılır.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: selectedTuru == null ? null : () async {
                  Navigator.pop(ctx);
                  await _createCase(selectedTuru!);
                },
                child: const Text('Dava Dosyasını Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCase(String davaTuru) async {
    if (_lastCalculationResult == null) return;
    
    // Şehir kontrolü
    if (_userCity == null || _userCity!.isEmpty) {
      _showSnackBar('Profilinizde şehir bilgisi eksik. Lütfen profilinizi güncelleyin.', AppColors.warning);
      return;
    }
    
    try {
      final result = await CaseService.createCase(
        davaTuru: davaTuru,
        tahminiAlacak: (_lastCalculationResult!['toplamNet'] ?? 0).toDouble(),
        hesaplamaData: _lastCalculationResult!,
        sehir: _userCity,
        ispatBelgeleri: _wizardUploadedUrls.isNotEmpty ? _wizardUploadedUrls : null,
      );
      
      // Oluşturulan case ID'sini sakla
      _createdCaseId = result['id']?.toString() ?? (result['case'] != null ? result['case']['id']?.toString() : null);
      
      if (_wizardUploadedUrls.isNotEmpty) {
        _showSnackBar('✅ Dava dosyanız belgelerle birlikte oluşturuldu!', AppColors.accent);
      } else {
        _showSnackBar('✅ Dava dosyanız oluşturuldu!', AppColors.accent);
      }
    } catch (e) {
      _showSnackBar('Dosya oluşturma hatası: $e', AppColors.danger);
    }
  }

  // BELGE YÜKLEME MODALI (Web'deki gibi)
  void _showBelgeYukleModal(String caseId) {
    List<PlatformFile> selectedFiles = [];
    bool isUploading = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  const Expanded(
                    child: Text('📎 İspat Belgeleri Yükle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Davanızı güçlendirecek belgeleri yükleyin (İşe giriş/çıkış belgesi, bordro, vb.).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              // Dosya seçme alanı
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryLight),
                    const SizedBox(height: 12),
                    const Text('Dosya Seç', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'En fazla 3 dosya, her biri max 5MB',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isUploading ? null : () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.any,
                        );
                        if (result != null) {
                          if (result.files.length > 3) {
                            _showSnackBar('En fazla 3 dosya yükleyebilirsiniz.', AppColors.warning);
                            return;
                          }
                          for (final file in result.files) {
                            if ((file.size) > 5 * 1024 * 1024) {
                              _showSnackBar('${file.name} 5MB\'dan büyük.', AppColors.warning);
                              return;
                            }
                          }
                          setModalState(() {
                            selectedFiles = result.files;
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Dosya Seç'),
                    ),
                  ],
                ),
              ),
              
              // Seçilen dosyalar listesi
              if (selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...selectedFiles.map((file) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: AppColors.primaryLight),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${(file.size / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setModalState(() {
                            selectedFiles.remove(file);
                          });
                        },
                      ),
                    ],
                  ),
                )),
              ],
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Şimdi Değil'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedFiles.isEmpty || isUploading ? null : () async {
                        setModalState(() => isUploading = true);
                        try {
                          // Dosyaları yükle
                          final urls = await _uploadFiles(selectedFiles);
                          // Case'e bağla
                          await ApiService.dio.post('/cases/$caseId/belgeler', data: {
                            'ispatBelgeleri': urls,
                          });
                          Navigator.pop(ctx);
                          _showSnackBar('✅ Belgeler başarıyla yüklendi!', AppColors.accent);
                        } catch (e) {
                          _showSnackBar('Yükleme hatası: $e', AppColors.danger);
                        } finally {
                          setModalState(() => isUploading = false);
                        }
                      },
                      child: isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Belgeleri Yükle'),
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

  Future<List<Map<String, String>>> _uploadFiles(List<PlatformFile> files) async {
    final List<Map<String, String>> uploadedUrls = [];
    
    for (final file in files) {
      if (file.path == null) continue;
      
      final formData = FormData.fromMap({
        'dosya': await MultipartFile.fromFile(file.path!, filename: file.name),
      });
      
      final response = await ApiService.dio.post('/messages/upload', data: formData);
      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = null;
        }
      }

      final map = (data is Map) ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
      uploadedUrls.add({
        'name': map['originalName']?.toString() ?? file.name,
        'url': map['url']?.toString() ?? '',
      });
    }
    
    return uploadedUrls;
  }

  Widget _buildResultCard(String title, double amount, NumberFormat formatter, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(formatter.format(amount), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');

    if (widget.isEmbedded) {
      // Ana sayfaya gömülü mod: paneldeki ile birebir aynı akış (ön test → form)
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _showPreTest ? _buildPreTest() : _buildCalculatorForm(df),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _showPreTest ? _buildPreTest() : _buildCalculatorForm(df),
    );
  }

  // ÖN DEĞERLENDİRME TESTİ
  Widget _buildPreTest() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('🔍', style: TextStyle(fontSize: 48))),
          const SizedBox(height: 15),
          const Text(
            'Ön Değerlendirme Testi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hak durumunuzu 30 saniyede anlayın. 3 soruyu yanıtlayın, sisteme girin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 32),

          // Soru 1: Kim Çıkardı
          _buildPreTestQuestion(
            'İşten kim çıkardı?',
            _ptKimCikardi,
            [
              _PreTestOption('ben', 'Ben kendi isteğimle (istifa ederek) ayrıldım'),
              _PreTestOption('isveren', 'İşveren (Patron) işime son verdi'),
              _PreTestOption('anlasma', 'Anlaşarak / ikale ile ayrıldık'),
              _PreTestOption('diger', 'Askerlik / Emeklilik / Evlilik sebebiyle ayrıldım'),
            ],
            (val) => setState(() => _ptKimCikardi = val),
          ),
          const SizedBox(height: 20),

          // Soru 2: Çalışma Süresi
          _buildPreTestQuestion(
            'Aynı işyerinde kaç yıl çalıştınız?',
            _ptSure,
            [
              _PreTestOption('az', '6 aydan daha az'),
              _PreTestOption('orta', '6 ay - 1 yıl arası'),
              _PreTestOption('cok', '1 yıldan fazla (Uzun süreli)'),
            ],
            (val) => setState(() => _ptSure = val),
          ),
          const SizedBox(height: 20),

          // Soru 3: Maaş
          _buildPreTestQuestion(
            'Maaşınız yaklaşık ne kadardı?',
            _ptMaas,
            [
              _PreTestOption('alti', 'Asgari ücretin altındaydı'),
              _PreTestOption('ustu', 'Asgari ücret veya daha üzerindeydi'),
            ],
            (val) => setState(() => _ptMaas = val),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _evaluatePreTest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Testi Tamamla ve Hesaplamaya Geç ➔',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreTestQuestion(String question, String? selectedValue, List<_PreTestOption> options, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Lütfen seçiniz...', style: TextStyle(color: AppColors.textMuted)),
              ),
              isExpanded: true,
              dropdownColor: AppColors.bgSurface,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.keyboard_arrow_down),
              ),
              items: options.map((opt) => DropdownMenuItem(
                value: opt.value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(opt.label, style: const TextStyle(fontSize: 14)),
                ),
              )).toList(),
              onChanged: (val) => setState(() => onChanged(val!)),
            ),
          ),
        ),
      ],
    );
  }

  void _evaluatePreTest() {
    if (_ptKimCikardi == null || _ptSure == null || _ptMaas == null) {
      _showSnackBar('Lütfen tüm ön değerlendirme sorularını yanıtlayınız.', AppColors.warning);
      return;
    }

    // 🚨 OTOMATİK RED MOTORU (Web'deki gibi)
    // Kendi isteğiyle ayrılıp, 1 yıldan az çalışanlar en düşük kazanma ihtimaline sahiptir.
    if (_ptKimCikardi == 'ben' && (_ptSure == 'az' || _ptSure == 'orta')) {
      _showSnackBar(
        'Dosyanız detaylı incelemeye uygun görünmemektedir. (Kendi isteğiyle çıkış ve 1 yıldan kısa çalışma süresi nedeniyle yasal tazminat hakkı doğmamaktadır).',
        AppColors.danger,
      );
      return; // İlerlemelerine İzin Verme
    }

    // Sınavı Geçti! Asıl Modülü Aç.
    setState(() => _showPreTest = false);
  }

  // HESAPLAMA FORMU
  Widget _buildCalculatorForm(DateFormat df) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Geri Dön Butonu
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showPreTest = true),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Ön Teste Dön'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const Row(
              children: [
                 Text('⚖️', style: TextStyle(fontSize: 24)),
                 SizedBox(width: 8),
                 Text('Tazminat Hesaplama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            // AI WIZARD
            _buildAIWizard(),
            const SizedBox(height: 24),

            // Tarih Seçimi
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'İşe Giriş Tarihi *'),
                      child: Text(_startDate == null ? 'Seçiniz' : df.format(_startDate!)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Çıkış Tarihi *'),
                      child: Text(_endDate == null ? 'Seçiniz' : df.format(_endDate!)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Maaş ve Yan Haklar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Brüt Maaş (₺) *', prefixText: '₺ '),
                    validator: (val) => val!.isEmpty ? 'Boş olamaz' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _benefitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Yan Haklar (₺)', prefixText: '₺ '),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryLight, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tazminatlar Giydirilmiş Brüt Ücret üzerinden hesaplanır (Maaş + Yan Haklar).',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Diğer Alacaklar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vacationDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kullanılmayan İzin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _overtimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fazla Mesai (Saat)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unpaidSalaryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ödenmemiş Maaş (Gün)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _taxBaseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Vergi Matrahı (₺)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isCalculating ? null : _calculate,
              child: _isCalculating 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Hesapla →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _wizardRestart() {
    setState(() {
      _wizardStep = 2;
      _wizardHistory.clear();
      _wizardAnswers = {};
      _wizardSelectedFiles = [];
      _wizardUploading = false;
      _wizardUploadedUrls = [];
      _wizardScanning = false;
      _wizardScanResults = [];
      _wizardCombinedAnalysis = null;

      _fesihYapan = null;
      _isverenSebep = null;
      _isciSebep = null;
      _isyeriCalisanSayisi = null;
      _iadeSuresiGectiMi = null;
      _isverenTuru = null;
      _eldenOdeme = null;
      _yaziliFesihBelgesi = null;
    });
  }

  void _wizardGoBack() {
    if (_wizardHistory.isEmpty) return;
    final prev = _wizardHistory.removeLast();
    setState(() {
      _wizardStep = prev['step'] as int;
      _wizardAnswers = Map<String, dynamic>.from(prev['answers'] as Map);
      _applyWizardAnswersToFields();
    });
  }

  void _wizardChangeUpload() {
    setState(() {
      _wizardStep = 9;
      _wizardCombinedAnalysis = null;
      _wizardScanResults = [];
      _wizardScanning = false;
      _wizardUploading = false;
      _wizardSelectedFiles = [];
      _wizardUploadedUrls = [];
      _yaziliFesihBelgesi = null;
      _wizardAnswers.remove('yaziliFesihBelgesi');
    });
  }

  void _applyWizardAnswersToFields() {
    _fesihYapan = _wizardAnswers['fesihYapan'] as String?;
    _isverenSebep = _wizardAnswers['isverenSebep'] as String?;
    _isciSebep = _wizardAnswers['isciSebep'] as String?;
    _isyeriCalisanSayisi = _wizardAnswers['isyeriCalisanSayisi'] as String?;
    _iadeSuresiGectiMi = _wizardAnswers['iadeSuresiGectiMi'] as bool?;
    _isverenTuru = _wizardAnswers['isverenTuru'] as String?;
    _eldenOdeme = _wizardAnswers['eldenOdeme'] as String?;
    _yaziliFesihBelgesi = _wizardAnswers['yaziliFesihBelgesi'] as String?;
  }

  void _wizardHandleSelect({required int next, Map<String, dynamic>? actions}) {
    final snapshot = {
      'step': _wizardStep,
      'answers': Map<String, dynamic>.from(_wizardAnswers),
    };
    setState(() {
      _wizardHistory.add(snapshot);
      if (actions != null) {
        _wizardAnswers.addAll(actions);
      }
      _wizardStep = next;
      _applyWizardAnswersToFields();
      if (_wizardStep != 95) {
        _wizardSelectedFiles = [];
        _wizardUploading = false;
        _wizardScanning = false;
        _wizardScanResults = [];
        _wizardCombinedAnalysis = null;
      }
    });
  }

  Future<void> _wizardScanSelectedFiles() async {
    if (_wizardSelectedFiles.isEmpty) {
      _showSnackBar('Önce belge seçin.', AppColors.warning);
      return;
    }
    setState(() {
      _wizardScanning = true;
      _wizardScanResults = [];
    });
    try {
      for (final f in _wizardSelectedFiles) {
        if (f.path == null) continue;
        final resp = await DocumentScanService.scanFile(filePath: f.path!, fileName: f.name);
        final analysis = (resp['analysis'] is Map<String, dynamic>) ? (resp['analysis'] as Map<String, dynamic>) : <String, dynamic>{};
        setState(() {
          _wizardScanResults.add({
            'fileName': f.name,
            'analysis': analysis,
          });
        });
      }
      if (_wizardScanResults.isNotEmpty) {
        _showSnackBar('✅ Evrak analizi tamamlandı.', AppColors.accent);
      }
    } catch (e) {
      _showSnackBar('Analiz hatası: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _wizardScanning = false);
    }
  }

  String? _getExpectedFesihTuruFromWizard() {
    if (_fesihYapan == 'isveren') {
      if (_isverenSebep == 'ahlak') return 'ISVEREN_FESHI_AHLAK';
      return 'ISVEREN_FESHI_GECERLI';
    }
    if (_fesihYapan == 'isci') {
      if (_isciSebep == 'istifa') return 'ISCI_ISTIFASI';
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _combineScanResults() {
    if (_wizardScanResults.isEmpty) return null;
    final combined = <String, dynamic>{
      'dates': <String>{},
      'moneys': <String>{},
      'labels': <String>{},
      'fesihTuru': null,
    };
    for (final r in _wizardScanResults) {
      final analysis = (r['analysis'] is Map<String, dynamic>) ? (r['analysis'] as Map<String, dynamic>) : <String, dynamic>{};
      final dates = (analysis['dates'] is List) ? (analysis['dates'] as List).map((e) => e.toString()) : const Iterable<String>.empty();
      final moneys = (analysis['moneys'] is List) ? (analysis['moneys'] as List).map((e) => e.toString()) : const Iterable<String>.empty();
      final labels = (analysis['labels'] is List) ? (analysis['labels'] as List).map((e) => e.toString()) : const Iterable<String>.empty();
      (combined['dates'] as Set<String>).addAll(dates);
      (combined['moneys'] as Set<String>).addAll(moneys);
      (combined['labels'] as Set<String>).addAll(labels);
      combined['fesihTuru'] ??= analysis['fesihTuru']?.toString();
    }
    return {
      'dates': (combined['dates'] as Set<String>).toList(),
      'moneys': (combined['moneys'] as Set<String>).toList(),
      'labels': (combined['labels'] as Set<String>).toList(),
      'fesihTuru': combined['fesihTuru'],
    };
  }

  // AI WIZARD - Web'deki gibi tek soru, geri destekli
  Widget _buildAIWizard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('🤖', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akıllı Karar Asistanı',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    Text(
                      'Sizi adım adım yönlendirerek hukuki senaryonuzu çıkaracağız.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (_wizardHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton(
                onPressed: _wizardGoBack,
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted, padding: EdgeInsets.zero),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('← Geri', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),

          if (_wizardStep == 2)
            _buildWizardSingleQuestion(
              question: '🔍 İş sözleşmesini fiilen kim sona erdirdi?',
              options: [
                _WizardOption('isveren', 'İşveren çıkardı'),
                _WizardOption('isci', 'Ben ayrıldım (İstifa/Fesih)'),
                _WizardOption('vefat', 'İşçi Vefat Etti'),
              ],
              selectedValue: _fesihYapan,
              onSelected: (val) {
                _wizardHandleSelect(next: val == 'isveren' ? 3 : (val == 'isci' ? 6 : 7), actions: {'fesihYapan': val});
              },
            ),

          if (_wizardStep == 3)
            _buildWizardSingleQuestion(
              question: '🔍 İşveren sizi işten çıkarırken hangi gerekçeyi öne sürdü?',
              options: [
                _WizardOption('haksiz_gecerli', 'Herhangi bir gerekçe göstermedi veya işler azaldı, küçülme var, performans düşük vb. dedi. (Geçerli/Haksız Neden)'),
                _WizardOption('ahlak', 'Hırsızlık, devamsızlık, hakaret, güveni kötüye kullanma (Ahlak/İyiniyet İhlali - Md 25/II)'),
                _WizardOption('saglik_zorlayici', 'Uzun süreli sağlık sorunu veya işyeri dışında zorlayıcı sebepler (Md 25/I-III)'),
                _WizardOption('sendikal', 'Sırf sendikaya üye olduğum için çıkardı (Sendikal Neden)'),
                _WizardOption('kotu_niyet', 'Maaşımı istedim/şikayet ettiğim için sırf inat/kötü niyetle çıkardı'),
              ],
              selectedValue: _isverenSebep,
              onSelected: (val) => _wizardHandleSelect(next: 4, actions: {'isverenSebep': val}),
            ),

          if (_wizardStep == 4)
            _buildWizardSingleQuestion(
              question: '🔍 Çalıştığınız işyerinde (tüm şubeleri dahil) 30 veya daha fazla işçi bulunuyor muydu?',
              options: [
                _WizardOption('fazla', 'Evet, 30\'dan fazlaydık'),
                _WizardOption('az', 'Hayır, 30\'dan azdık'),
              ],
              selectedValue: _isyeriCalisanSayisi,
              onSelected: (val) => _wizardHandleSelect(next: 5, actions: {'isyeriCalisanSayisi': val}),
            ),

          if (_wizardStep == 5)
            _buildWizardSingleQuestion(
              question: '🔍 İşten çıkarılma tarihinizin (tebliğ tarihinin) üzerinden ne kadar zaman geçti?',
              options: [
                _WizardOption('dolmadi', '1 (Bir) Ay henüz DOLMADI'),
                _WizardOption('gecti', '1 (Bir) Ay veya daha FAZLA geçti'),
              ],
              selectedValue: _iadeSuresiGectiMi == null ? null : (_iadeSuresiGectiMi! ? 'gecti' : 'dolmadi'),
              onSelected: (val) => _wizardHandleSelect(next: 7, actions: {'iadeSuresiGectiMi': val == 'gecti'}),
            ),

          if (_wizardStep == 6)
            _buildWizardSingleQuestion(
              question: '🔍 İşi neden siz bıraktınız (kendi feshiniz)? Hukuki dayanağınız nedir?',
              options: [
                _WizardOption('istifa', 'Kişisel sebeplerimle / Kendi mesleğim kariyerim vs. için baska ise gectim (Kuru İstifa)'),
                _WizardOption('hakli_neden', 'Maaşım, mesailerim, SGK\'m eksik yattı / Mobbing, hakaret gördüm (4857 Md 24 - Haklı Neden)'),
                _WizardOption('askerlik', 'Muvazzaf Askerlik görevim sebebiyle'),
                _WizardOption('evlilik', 'Evlilik sebebiyle (Nikah sonrası 1 yıl içinde) - Kadın İşçi'),
                _WizardOption('emeklilik', 'Emeklilik (Yaşlılık aylığı veya 15 yıl 3600 gün şartı) tablosuna uyduğum için'),
              ],
              selectedValue: _isciSebep,
              onSelected: (val) => _wizardHandleSelect(next: 7, actions: {'isciSebep': val}),
            ),

          if (_wizardStep == 7)
            _buildWizardSingleQuestion(
              question: '🔍 Eski işvereninizin firmanın ticari ölçeği nasıldı? (Davayı kazandığınızda paranın tahsili için)',
              options: [
                _WizardOption('kurumsal', 'Büyük Şirket / Kurumsal Firma / Holding'),
                _WizardOption('kobi', 'Orta ve Küçük Ölçekli İşletme (KOBİ)'),
                _WizardOption('kucuk_esnaf', 'Küçük Esnaf (Market, Bakkal, Berber, Atölye)'),
                _WizardOption('iflas_kapali', 'Şirket/Dükkan Kapandı veya İflas Etti'),
              ],
              selectedValue: _isverenTuru,
              onSelected: (val) => _wizardHandleSelect(next: 8, actions: {'isverenTuru': val}),
            ),

          if (_wizardStep == 8)
            _buildWizardSingleQuestion(
              question: '🔍 Çalışırken maaşınızın bir bölümü (Asgari ücretin üstü) banka yerine \'Elden\' veriliyor muydu?',
              options: [
                _WizardOption('evet', 'Evet, bir kısmı tarafıma elden veriliyordu (Düşük SGK Prime esas)'),
                _WizardOption('hayir', 'Hayır, çalışma bedelinin tamamı resmi (Banka hesabı vb.) ödeniyordu'),
              ],
              selectedValue: _eldenOdeme,
              onSelected: (val) => _wizardHandleSelect(next: 9, actions: {'eldenOdeme': val}),
            ),

          if (_wizardStep == 9)
            _buildWizardSingleQuestion(
              question: '🔍 İşten çıkışınıza dair elinizde resmi bir belge veya yazılı bildirim var mı? (İhtarname, Yazılı Fesih Belgesi, Sms vb.)',
              options: [
                _WizardOption('evet', 'Evet, yazılı olarak (Evrak, Mail, Mesaj, Noter) belgelerim var'),
                _WizardOption('hayir', 'Hayır, olay sadece sözlü gelişti. Şahitlerle kanıtlayabilirim'),
              ],
              selectedValue: _yaziliFesihBelgesi,
              onSelected: (val) {
                if (val == 'evet') {
                  _wizardHandleSelect(next: 95, actions: {'yaziliFesihBelgesi': 'evet'});
                } else {
                  _wizardHandleSelect(next: 10, actions: {'yaziliFesihBelgesi': 'hayir'});
                }
              },
            ),

          if (_wizardStep == 95) _buildWizardUploadStep(),

          if (_wizardStep == 10)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sorular tamamlandı. Hesaplamaya geçebilirsiniz.',
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _wizardRestart,
                    style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWizardSingleQuestion({
    required String question,
    required List<_WizardOption> options,
    required String? selectedValue,
    required Function(String) onSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 15),
          ...options.map((opt) {
            final isSelected = selectedValue == opt.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelected(opt.value),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.bgSurface : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle, color: AppColors.primaryLight, size: 22),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWizardUploadStep() {
    final combined = _wizardCombinedAnalysis;
    final scannedFesihTuru = combined?['fesihTuru']?.toString();
    final expectedFesihTuru = _getExpectedFesihTuruFromWizard();
    final isMatch = (scannedFesihTuru != null && expectedFesihTuru != null) ? scannedFesihTuru == expectedFesihTuru : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨ Harika! Yazılı ispat belgeleriniz davanızın daha hızlı ve çok daha güçlü değerlendirilmesini sağlar.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _wizardUploading
                ? null
                : () async {
                    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
                    if (result == null) return;
                    if (result.files.length > 3) {
                      _showSnackBar('En fazla 3 belge ekleyebilirsiniz.', AppColors.warning);
                      return;
                    }
                    for (final f in result.files) {
                      if (f.size > 5 * 1024 * 1024) {
                        _showSnackBar('${f.name} - 5 MB sınırını aşıyor.', AppColors.warning);
                        return;
                      }
                    }
                    setState(() {
                      _wizardSelectedFiles = result.files;
                    });
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: const Column(
                children: [
                  Text('📂', style: TextStyle(fontSize: 34)),
                  SizedBox(height: 8),
                  Text('Belge seçmek için tıklayın', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('PDF, JPG, PNG, WEBP • Maks. 5 MB/dosya • En fazla 3', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('${_wizardSelectedFiles.length} / 3 belge eklendi', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          if (_wizardSelectedFiles.isNotEmpty)
            ..._wizardSelectedFiles.map(
              (f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Text('📄', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: _wizardUploading
                          ? null
                          : () {
                              setState(() {
                                _wizardSelectedFiles = List.of(_wizardSelectedFiles)..remove(f);
                              });
                            },
                      icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          if (combined != null) ...[
            if (isMatch == false && scannedFesihTuru != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🛑 BELGE & BEYAN ÇAKIŞMASI TESPİT EDİLDİ',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BEYANINIZ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  _getFesihTuruLabel(expectedFesihTuru),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 40, color: AppColors.border),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('BELGEDE GÖRÜNEN', style: TextStyle(fontSize: 10, color: Color(0xFFfca311))),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFesihTuruLabel(scannedFesihTuru),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFfca311)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.danger.withAlpha(20)),
                      child: const Text(
                        '⚡ Sistem her iki senaryoyu da ayrı ayrı hesaplayacak. Avukatınız gerçek senaryoyu belirleyecektir.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else if (isMatch == true)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.black, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✅ BELGE VE BEYANINIZ UYUMLU',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Belgeden okunan fesih türü (${_getFesihTuruLabel(scannedFesihTuru)}) beyanınızla örtüşüyor. İspat gücünüz yüksek.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if ((combined['dates'] is List) && (combined['dates'] as List).isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tarih ibareleri: ${(combined['dates'] as List).take(5).join(', ')}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if ((combined['labels'] is List) && (combined['labels'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hukuki nitelendirmeler: ${(combined['labels'] as List).take(6).join(' • ')}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _wizardUploading || _wizardScanning ? null : () => _wizardHandleSelect(next: 10, actions: const {}),
                child: const Text('✅ Hesaplamaya Geç ➔'),
              ),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_wizardSelectedFiles.isEmpty || _wizardUploading || _wizardScanning)
                  ? null
                  : () async {
                      setState(() {
                        _wizardUploading = true;
                        _wizardScanning = true;
                        _wizardScanResults = [];
                        _wizardCombinedAnalysis = null;
                      });
                      try {
                        // 1) OCR + Analiz (webdeki gibi)
                        for (final f in _wizardSelectedFiles) {
                          if (f.path == null) continue;
                          final resp = await DocumentScanService.scanFile(filePath: f.path!, fileName: f.name);
                          final analysis = (resp['analysis'] is Map<String, dynamic>) ? (resp['analysis'] as Map<String, dynamic>) : <String, dynamic>{};
                          _wizardScanResults.add({'fileName': f.name, 'analysis': analysis});
                        }
                        final combinedNow = _combineScanResults();
                        setState(() {
                          _wizardCombinedAnalysis = combinedNow;
                        });

                        // 2) Belgeleri kalıcı upload (mevcut API'niz)
                        final urls = await _uploadFiles(_wizardSelectedFiles);
                        setState(() {
                          _wizardUploadedUrls = urls;
                        });
                        _showSnackBar('✅ Belgeler eklendi. Analiz sonucu hazır.', AppColors.accent);
                      } catch (e) {
                        _showSnackBar('Yükleme hatası: $e', AppColors.danger);
                      } finally {
                        if (mounted) {
                          setState(() {
                            _wizardUploading = false;
                            _wizardScanning = false;
                          });
                        }
                      }
                    },
              child: (_wizardUploading || _wizardScanning)
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Belgeleri Ekle ve Hesaplamaya Geç ➔'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _wizardUploading ? null : () => _wizardHandleSelect(next: 10, actions: const {}),
              child: const Text('Belge olmadan devam et'),
            ),
          ),
        ],
      ),
    );
  }

  String _getFesihTuruLabel(String? slug) {
    if (slug == null) return 'Bilinmiyor';
    switch (slug) {
      case 'ISVEREN_FESHI_GECERLI': return 'İşveren Geçerli Fesih (4857/17)';
      case 'ISVEREN_FESHI_AHLAK': return 'İşveren Haklı Fesih / Ahlak-25/2';
      case 'ISCI_ISTIFASI': return 'İşçi İstifası';
      case 'IKALE_IBRANAME': return 'İkale / İbraname';
      case 'askerlik': return 'Askerlik';
      case 'emeklilik': return 'Emeklilik';
      case 'evlilik': return 'Evlilik';
      case 'hakli_neden': return 'Haklı Neden (24.md)';
      case 'haksiz_gecerli': return 'İşveren Haksız Fesih';
      case 'ahlak': return 'İşveren 25/2 Fesih';
      default: return slug;
    }
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _benefitsController.dispose();
    _vacationDaysController.dispose();
    _overtimeController.dispose();
    _unpaidSalaryController.dispose();
    _taxBaseController.dispose();
    super.dispose();
  }
}

class _PreTestOption {
  final String value;
  final String label;
  _PreTestOption(this.value, this.label);
}

class _WizardOption {
  final String value;
  final String label;
  final String? description;
  _WizardOption(this.value, this.label, [this.description]);
}

class _DavaTuru {
  final String value;
  final String label;
  _DavaTuru(this.value, this.label);
}
