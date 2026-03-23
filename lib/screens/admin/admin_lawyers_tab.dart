import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminLawyersTab extends StatefulWidget {
  const AdminLawyersTab({super.key});

  @override
  State<AdminLawyersTab> createState() => _AdminLawyersTabState();
}

class _AdminLawyersTabState extends State<AdminLawyersTab> {
  bool _isLoading = true;
  List<dynamic> _allLawyers = [];
  List<dynamic> _filteredLawyers = [];
  String _searchQuery = '';
  String _selectedCity = '';
  String _selectedStatus = 'Hepsi';
  
  final TextEditingController _searchController = TextEditingController();

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

  static const List<String> _statuses = ['Hepsi', 'Onaylı', 'Bekliyor', 'Banlı'];

  @override
  void initState() {
    super.initState();
    _loadLawyers();
  }

  Future<void> _loadLawyers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/admin/avukatlar');
      if (mounted) {
        setState(() {
          _allLawyers = response.data;
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
      _filteredLawyers = _allLawyers.where((a) {
        final matchesSearch = _searchQuery.isEmpty ||
            '${a['ad']} ${a['soyad']} ${a['email']}'.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCity = _selectedCity.isEmpty || _selectedCity == 'Hepsi' || a['sehir'] == _selectedCity;
        
        final isBanli = a['isActive'] == false && a['onayTarihi'] != null;
        final isOnayli = a['profilOnay'] == true && a['isActive'] == true;
        final isBekliyor = !isOnayli && !isBanli;

        bool matchesStatus = true;
        if (_selectedStatus == 'Onaylı') matchesStatus = isOnayli;
        else if (_selectedStatus == 'Bekliyor') matchesStatus = isBekliyor;
        else if (_selectedStatus == 'Banlı') matchesStatus = isBanli;

        return matchesSearch && matchesCity && matchesStatus;
      }).toList();
      });
    }
  }

  Future<void> _updateStatus(String id, String action) async {
    try {
      String endpoint = action == 'onayla' ? '/admin/avukat/$id/onayla' : '/admin/avukat/$id/reddet';
      await ApiService.dio.put(endpoint);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'onayla' ? 'Avukat onaylandı.' : 'Avukat askıya alındı.'),
            backgroundColor: action == 'onayla' ? AppColors.accent : AppColors.danger,
          ),
        );
      }
      _loadLawyers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showLawyerDetails(dynamic a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Avukat Detayı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _detailItem('Ad Soyad', '${a['ad']} ${a['soyad']}'),
                  _detailItem('E-posta', a['email'] ?? '—'),
                  _detailItem('Şehir', a['sehir'] ?? '—'),
                  _detailItem('Baro', a['baro'] ?? '—'),
                  _detailItem('Baro No', a['baroNo'] ?? '—'),
                  _detailItem('Uzmanlık', a['uzmanlik'] ?? '—'),
                  _detailItem('Kayıt Tarihi', _formatDate(a['createdAt'])),
                  _detailItem('Onay Tarihi', a['onayTarihi'] != null ? _formatDate(a['onayTarihi']) : 'Bekliyor'),
                  const SizedBox(height: 24),
                  const Text('İşlemler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildActionButtons(a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic a) {
    final isBanli = a['isActive'] == false && a['onayTarihi'] != null;
    final isOnayli = a['profilOnay'] == true && a['isActive'] == true;
    final isBekliyor = !isOnayli && !isBanli;

    return Wrap(
      spacing: 12,
      children: [
        if (isBekliyor || isBanli)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(a['id'], 'onayla');
            },
            icon: const Icon(Icons.check),
            label: Text(isBanli ? 'Aktifleştir' : 'Onayla'),
          ),
        if (isOnayli)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(a['id'], 'reddet');
            },
            icon: const Icon(Icons.block),
            label: const Text('Askıya Al'),
          ),
      ],
    );
  }

  Widget _detailItem(String label, dynamic value) {
    String displayValue = '—';
    if (value != null) {
      if (value is List) {
        displayValue = value.join(', ');
      } else {
        displayValue = value.toString();
      }
    }
    if (displayValue.isEmpty) displayValue = '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(displayValue, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredLawyers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadLawyers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLawyers.length,
                        itemBuilder: (context, index) {
                          final a = _filteredLawyers[index];
                          return _buildLawyerCard(a);
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
              hintText: 'Avukat ara...',
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
                  value: _selectedCity.isEmpty ? 'Hepsi' : _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'Şehir',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
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
                  decoration: InputDecoration(
                    labelText: 'Durum',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedStatus = v!);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerCard(dynamic a) {
    final isBanli = a['isActive'] == false && a['onayTarihi'] != null;
    final isOnayli = a['profilOnay'] == true && a['isActive'] == true;
    
    Color statusColor = AppColors.warning;
    String statusLabel = 'Bekliyor';
    if (isBanli) {
      statusColor = AppColors.danger;
      statusLabel = 'Banlı';
    } else if (isOnayli) {
      statusColor = AppColors.accent;
      statusLabel = 'Onaylı';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.bgCard,
      child: InkWell(
        onTap: () => _showLawyerDetails(a),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  ((a['ad'] ?? '?')[0] + (a['soyad'] ?? '?')[0]).toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a['ad']} ${a['soyad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(a['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                          child: Text(a['sehir'] ?? '—', style: const TextStyle(fontSize: 10)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('Avukat bulunamadı', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          if (_searchQuery.isNotEmpty || _selectedCity != 'Hepsi' || _selectedStatus != 'Hepsi')
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCity = 'Hepsi';
                  _selectedStatus = 'Hepsi';
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
