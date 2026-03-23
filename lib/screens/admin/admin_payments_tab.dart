import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminPaymentsTab extends StatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  State<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends State<AdminPaymentsTab> {
  bool _isLoading = true;
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  String _searchQuery = '';
  double _filteredTotal = 0.0;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/admin/odemeler');
      if (mounted) {
        setState(() {
          _allPayments = response.data;
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
      _filteredPayments = _allPayments.where((p) {
        final matchesSearch = _searchQuery.isEmpty ||
            '${p['kullaniciEmail']} ${p['kartSonDort']} ${p['avukatAd']}'.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSearch;
      }).toList();
      
      _filteredTotal = _filteredPayments.fold(0.0, (sum, p) => sum + (p['tutar'] is num ? (p['tutar'] as num).toDouble() : 0.0));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        _buildSummary(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredPayments.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadPayments,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPayments.length,
                        itemBuilder: (context, index) {
                          final p = _filteredPayments[index];
                          return _buildPaymentCard(p);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filtrelenmiş Toplam Gelir', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(_formatTL(_filteredTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.bgSurface,
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchQuery = v;
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Email, kart son 4 veya avukat ara...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(dynamic p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['kullaniciEmail'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Avukat: ${p['avukatAd'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                Text(_formatTL(p['tutar']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💳 •••• ${p['kartSonDort'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('İşlem ID: ${(p['id'] ?? '').toString().substring(0, 10)}...', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatDate(p['tarih']), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(p['status'] ?? 'COMPLETED', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTL(dynamic n) {
    if (n == null) return '₺0';
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.payments_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('Ödeme bulunamadı', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          if (_searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
                _applyFilters();
              },
              child: const Text('Filtreyi Temizle'),
            ),
        ],
      ),
    );
  }
}
