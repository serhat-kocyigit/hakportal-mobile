import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminCasesTab extends StatefulWidget {
  const AdminCasesTab({super.key});

  @override
  State<AdminCasesTab> createState() => _AdminCasesTabState();
}

class _AdminCasesTabState extends State<AdminCasesTab> {
  bool _isLoading = true;
  List<dynamic> _allCases = [];
  List<dynamic> _filteredCases = [];
  List<String> _caseTypes = ['Hepsi'];
  
  String _searchQuery = '';
  String _selectedCity = 'Hepsi';
  String _selectedStatus = 'Hepsi';
  String _selectedType = 'Hepsi';

  final TextEditingController _searchController = TextEditingController();

  static const Map<String, String> _statusLabels = {
    'OPEN': 'Açık',
    'PENDING_OFFER': 'Teklif Bekleniyor',
    'OFFER_MADE': 'Teklif Yapıldı',
    'WAITING_PAYMENT': 'Ödeme Bekleniyor',
    'PRE_CASE_REVIEW': 'Ön İnceleme',
    'PENDING_USER_AUTH': 'Kullanıcı Yanıtı',
    'AUTHORIZED': 'Yetkilendirildi',
    'ACTIVE': 'Aktif',
    'LAWYER_ASSIGNED': 'Avukat Atandı',
    'IN_PROGRESS': 'Devam Ediyor',
    'ILK_GORUSME': 'İlk Görüşme',
    'DAVA_ACILDI': 'Dava Açıldı',
    'DURUSMA': 'Duruşma',
    'TAHSIL': 'Tahsil',
    'FILED_IN_COURT': 'Mahkemede',
    'CLOSED': 'Kapatıldı',
    'KAPANDI': 'Kapandı'
  };

  static const Map<String, Color> _statusColors = {
    'OPEN': Colors.orange,
    'PENDING_OFFER': Colors.yellow,
    'OFFER_MADE': Colors.yellow,
    'WAITING_PAYMENT': Colors.yellow,
    'PRE_CASE_REVIEW': Colors.blue,
    'PENDING_USER_AUTH': Colors.yellow,
    'AUTHORIZED': Colors.blue,
    'ACTIVE': Colors.green,
    'LAWYER_ASSIGNED': Colors.green,
    'IN_PROGRESS': Colors.green,
    'ILK_GORUSME': Colors.blue,
    'DAVA_ACILDI': Colors.blue,
    'DURUSMA': Colors.purple,
    'TAHSIL': Colors.green,
    'FILED_IN_COURT': Colors.purple,
    'CLOSED': Colors.red,
    'KAPANDI': Colors.red
  };

  static const List<String> _cities = [
    'Hepsi', 'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin',
    'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale',
    'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
    'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin',
    'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli',
    'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas',
    'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak',
    'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan',
    'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
  ];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/admin/davalar');
      final List<dynamic> cases = response.data;
      
      final types = cases.map((e) => e['davaTuru']?.toString()).whereType<String>().toSet().toList();
      types.sort();
      
      if (mounted) {
        setState(() {
          _allCases = cases;
          _caseTypes = ['Hepsi', ...types];
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _applyFilters() {
    if (mounted) {
      setState(() {
      _filteredCases = _allCases.where((d) {
        final matchesSearch = _searchQuery.isEmpty ||
            '${d['kullaniciAd']} ${d['kullaniciSoyad']} ${d['kullaniciEmail']}'.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCity = _selectedCity == 'Hepsi' || d['sehir'] == _selectedCity;
        final matchesStatus = _selectedStatus == 'Hepsi' || d['status'] == _selectedStatus;
        final matchesType = _selectedType == 'Hepsi' || d['davaTuru'] == _selectedType;

        return matchesSearch && matchesCity && matchesStatus && matchesType;
      }).toList();
      });
    }
  }

  Future<void> _closeCase(String id) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Davayı Kapat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dava başarıyla bittiyse tahsil edilen tutarı girin.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahsilat Tutarı (TL)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Kapat ve Tahsilat Gir'),
          ),
        ],
      ),
    );

    if (result != null || controller.text.isEmpty) {
      try {
        await ApiService.dio.put('/admin/dava/$id/kapat', data: {'tahsilat': result});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dava kapatıldı.'), backgroundColor: AppColors.accent),
          );
        }
        _loadCases();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _showCaseDetails(dynamic d) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CaseDetailsSheet(caseData: d, onUpdate: _loadCases, onClose: (id) => _closeCase(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredCases.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadCases,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCases.length,
                        itemBuilder: (context, index) {
                          final c = _filteredCases[index];
                          return _buildCaseCard(c);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.bgSurface,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) {
              _searchQuery = v;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Kullanıcı veya E-posta ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: _filterDecoration('Şehir'),
                  isExpanded: true,
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedCity = v!);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _filterDecoration('Durum'),
                  isExpanded: true,
                  items: ['Hepsi', ..._statusLabels.keys].map((s) => DropdownMenuItem(value: s, child: Text(s == 'Hepsi' ? 'Hepsi' : (_statusLabels[s] ?? s), style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedStatus = v!);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: _filterDecoration('Dava Türü'),
            isExpanded: true,
            items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              setState(() => _selectedType = v!);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildCaseCard(dynamic c) {
    final status = c['status'] ?? 'OPEN';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final statusLabel = _statusLabels[status] ?? status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.bgCard,
      child: InkWell(
        onTap: () => _showCaseDetails(c),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${c['kullaniciAd'] ?? ''} ${c['kullaniciSoyad'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(c['sehir'] ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  const Icon(Icons.gavel_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(c['davaTuru'] ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tahmini Alacak', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(_formatTL(c['tahminiAlacak']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  if (c['avukatAd'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Avukat', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text('${c['avukatAd']} ${c['avukatSoyad'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  Text(_formatDate(c['createdAt'], short: true), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTL(dynamic n) {
    if (n == null) return '₺0';
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    return currency.format(n is num ? n : 0);
  }

  String _formatDate(dynamic date, {bool short = false}) {
    if (date == null) return '—';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat(short ? 'dd.MM.yy' : 'dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('Dava bulunamadı', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          if (_searchQuery.isNotEmpty || _selectedCity != 'Hepsi' || _selectedStatus != 'Hepsi' || _selectedType != 'Hepsi')
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCity = 'Hepsi';
                  _selectedStatus = 'Hepsi';
                  _selectedType = 'Hepsi';
                });
                _applyFilters();
              },
              child: const Text('Filtreleri Temizle'),
            ),
        ],
      ),
    );
  }
}

class _CaseDetailsSheet extends StatefulWidget {
  final dynamic caseData;
  final VoidCallback onUpdate;
  final Function(String) onClose;

  const _CaseDetailsSheet({required this.caseData, required this.onUpdate, required this.onClose});

  @override
  State<_CaseDetailsSheet> createState() => _CaseDetailsSheetState();
}

class _CaseDetailsSheetState extends State<_CaseDetailsSheet> {
  bool _isLoading = true;
  Map<String, dynamic> _details = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final response = await ApiService.dio.get('/admin/dava/${widget.caseData['id']}/detay');
      if (mounted) {
        setState(() {
          _details = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dava Detayı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  _section('Genel Bilgiler', [
                    _item('Dava ID', widget.caseData['id']),
                    _item('Şehir', widget.caseData['sehir'] ?? '—'),
                    _item('Dava Türü', widget.caseData['davaTuru'] ?? '—'),
                    _item('Durum', widget.caseData['status'] ?? '—'),
                    _item('Tahmini Alacak', _formatTL(widget.caseData['tahminiAlacak'])),
                    _item('Tahsil Edilen', _formatTL(_details['gerceklesenTahsilat']), color: Colors.green),
                  ]),
                  _section('Taraflar', [
                    _item('Kullanıcı', '${widget.caseData['kullaniciAd']} ${widget.caseData['kullaniciSoyad']}'),
                    _item('E-posta', widget.caseData['kullaniciEmail'] ?? '—'),
                    _item('Avukat', widget.caseData['avukatAd'] != null ? '${widget.caseData['avukatAd']} ${widget.caseData['avukatSoyad']}' : 'Henüz atanmadı'),
                  ]),
                  _section('Süreç Günlüğü', [
                    ...(_details['logs'] as List? ?? []).map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDate(l['created_at']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(l['aciklama'] ?? '', style: const TextStyle(fontSize: 13)),
                              const Divider(height: 12),
                            ],
                          ),
                        )),
                    if ((_details['logs'] as List? ?? []).isEmpty) const Text('Günlük kaydı yok.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                  _section('Mesajlar', [
                    ...(_details['messages'] as List? ?? []).map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: m['gonderen_rol'] == 'kullanici' ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(m['ad'] ?? 'Silinmiş', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text(_formatDate(m['tarih']), style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(m['icerik'] ?? '', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        )),
                    if ((_details['messages'] as List? ?? []).isEmpty) const Text('Mesajlaşma yok.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 16),
                  if (widget.caseData['status'] != 'KAPANDI' && widget.caseData['status'] != 'CLOSED')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onClose(widget.caseData['id']);
                      },
                      child: const Text('Davayı Kapat / Tahsilat Gir'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _item(String label, dynamic value, {Color? color}) {
    String displayValue = (value ?? '—').toString();
    if (displayValue.isEmpty) displayValue = '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(displayValue, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  String _formatTL(dynamic n) {
    if (n == null) return '—';
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    return currency.format(n is num ? n : 0);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return date.toString();
    }
  }
}
