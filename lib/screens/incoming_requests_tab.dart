import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/api_service.dart';
import '../widgets/case_report_widget.dart';
import 'package:go_router/go_router.dart';

class IncomingRequestsTab extends StatefulWidget {
  const IncomingRequestsTab({super.key});

  @override
  State<IncomingRequestsTab> createState() => _IncomingRequestsTabState();
}

class _IncomingRequestsTabState extends State<IncomingRequestsTab> {
  bool _isLoading = true;
  String? _errorMsg;
  List<dynamic> _requests = [];

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
      _requests = await LawyerService.getIncomingRequests();
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

  Future<void> _handleAction(String id, String action) async {
    try {
      if (action == 'KABUL') {
        await LawyerService.acceptRequest(id);
      } else {
        await LawyerService.rejectRequest(id);
      }
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'KABUL' ? '✅ Talep kabul edildi. Müvekkil ile iletişim başlayabilir.' : '🛑 Talep reddedildi.'),
            backgroundColor: action == 'KABUL' ? AppColors.accent : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
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

        if (_requests.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 120),
              Icon(Icons.contact_mail_outlined, size: 80, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text('Henüz Talep Yok', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Müvekkiller sizinle iletişime geçmek istediğinde burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (ctx, i) {
            final r = _requests[i];
            final k = r['kullanici'] ?? {};
            final d = r['dava'];
            final status = r['status'] ?? 'BEKLIYOR';
            final dateStr = r['createdAt'] != null ? dateFormat.format(DateTime.parse(r['createdAt'])) : '';

            return Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📞 İletişim Talebi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(dateStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Müvekkil Bilgisi
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                              child: Text(k['ad']?.substring(0, 1).toUpperCase() ?? 'M', style: const TextStyle(color: AppColors.primaryLight)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${k['ad'] ?? ''} ${k['soyad'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(k['sehir'] ?? 'Şehir Belirtilmemiş', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (status != 'BEKLIYOR')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'KABUL' ? AppColors.accent.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status == 'KABUL' ? 'KABUL EDİLDİ' : 'REDDEDİLDİ',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'KABUL' ? AppColors.accent : AppColors.danger),
                                ),
                              ),
                          ],
                        ),

                        if (r['not'] != null && r['not'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text('💬 Not: ${r['not']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                          ),
                        ],

                        if (d != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 8),
                          const Text('⚖️ Dava Analizi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight)),
                          const SizedBox(height: 12),
                          CaseReportWidget(data: d['hesaplamaVerisi'], c: Map<String, dynamic>.from(d), isLawyer: true),
                        ],

                        if (status == 'BEKLIYOR') ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleAction(r['id'], 'RED'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Reddet'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _handleAction(r['id'], 'KABUL'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        if (status == 'KABUL') ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '✅ Talebi Kabul Ettiniz',
                                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        if (status == 'RED') ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel, color: AppColors.danger, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '❌ Talebi Reddettiniz',
                                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
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
