import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _isLoading = true;
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
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

  static const List<String> _statuses = ['Hepsi', 'Aktif', 'Banlı'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/admin/kullanicilar');
      if (mounted) {
        setState(() {
          _allUsers = response.data;
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
      _filteredUsers = _allUsers.where((u) {
        final matchesSearch = _searchQuery.isEmpty ||
            '${u['ad']} ${u['soyad']} ${u['email']}'.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCity = _selectedCity.isEmpty || _selectedCity == 'Hepsi' || u['sehir'] == _selectedCity;
        
        bool matchesStatus = true;
        if (_selectedStatus == 'Aktif') matchesStatus = u['isActive'] == true;
        else if (_selectedStatus == 'Banlı') matchesStatus = u['isActive'] == false;

        return matchesSearch && matchesCity && matchesStatus;
      }).toList();
      });
    }
  }

  Future<void> _updateStatus(String id, String action) async {
    try {
      String endpoint = action == 'ban' ? '/admin/kullanici/$id/ban' : '/admin/kullanici/$id/aktif';
      await ApiService.dio.put(endpoint);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'ban' ? 'Kullanıcı banlandı.' : 'Kullanıcı aktifleştirildi.'),
            backgroundColor: action == 'ban' ? AppColors.danger : AppColors.accent,
          ),
        );
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showUserDetails(dynamic u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                const Text('Kullanıcı Detayı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _detailItem('Ad Soyad', '${u['ad']} ${u['soyad']}'),
                  _detailItem('E-posta', u['email'] ?? '—'),
                  _detailItem('Şehir', u['sehir'] ?? '—'),
                  _detailItem('Kayıt Tarihi', _formatDate(u['createdAt'])),
                  _detailItem('Durum', u['isActive'] == true ? 'Aktif' : 'Banlı'),
                  const SizedBox(height: 24),
                  const Text('İşlemler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildActionButtons(u),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic u) {
    final isActive = u['isActive'] == true;

    return Wrap(
      spacing: 12,
      children: [
        if (isActive)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(u['id'], 'ban');
            },
            icon: const Icon(Icons.block),
            label: const Text('Banla'),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(u['id'], 'aktif');
            },
            icon: const Icon(Icons.check),
            label: const Text('Aktifleştir'),
          ),
      ],
    );
  }

  Widget _detailItem(String label, dynamic value) {
    String displayValue = (value ?? '—').toString();
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
              : _filteredUsers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final u = _filteredUsers[index];
                          return _buildUserCard(u);
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
              hintText: 'Kullanıcı ara...',
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

  Widget _buildUserCard(dynamic u) {
    Color statusColor = u['isActive'] == true ? AppColors.accent : AppColors.danger;
    String statusLabel = u['isActive'] == true ? 'Aktif' : 'Banlı';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.bgCard,
      child: InkWell(
        onTap: () => _showUserDetails(u),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  ((u['ad'] ?? '?')[0] + (u['soyad'] ?? '?')[0]).toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['ad']} ${u['soyad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                          child: Text(u['sehir'] ?? '—', style: const TextStyle(fontSize: 10)),
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
          const Icon(Icons.people_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('Kullanıcı bulunamadı', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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
