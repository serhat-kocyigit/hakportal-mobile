import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../services/lawyer_service.dart';
import '../services/api_service.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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
    _loadData();
  }

  void _loadData() {
    _future = LawyerService.getActiveCases();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Yükleniyor...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString().replaceAll('Exception: ', '');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                  const SizedBox(height: 16),
                  Text(errorStr, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refresh, child: const Text('Tekrar Dene')),
                ],
              ),
            );
          }

          final allOffers = snapshot.data ?? [];

          final activeCases = allOffers.where((t) {
            final bool isSelected = t['status'] == 'SELECTED';
            final String caseStatus = t['caseStatus'] ?? '';
            final List<String> activeStatuses = [
              'PRE_CASE_REVIEW', 'AUTHORIZED', 'ACTIVE', 'LAWYER_ASSIGNED',
              'FILED_IN_COURT', 'IN_PROGRESS', 'ILK_GORUSME', 'DAVA_ACILDI',
              'DURUSMA', 'TAHSIL', 'CLOSED', 'KAPANDI'
            ];
            return isSelected && activeStatuses.contains(caseStatus);
          }).toList();

          if (activeCases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Aktif dava yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teklifiniz kabul edilip ödeme yapıldıktan sonra mesajlaşabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            );
          }

          if (activeCases.length == 1) {
            final singleCase = activeCases.first;
            final caseId = singleCase['caseId']?.toString() ?? '';
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.push('/chat/$caseId');
            });
            
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Sohbet açılıyor...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Müvekkilinizi seçin:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ...activeCases.map((c) => _buildCaseCard(context, c)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, dynamic c) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final String caseId = (c['caseId'] ?? '').toString();
    final String davaTuru = c['caseDavaTuru'] ?? 'Hukuki Danışmanlık';
    final String sehir = c['caseSehir'] ?? '';
    
    String? createdAt = c['createdAt'] ?? c['selectedAt'];
    
    double tahminiAlacak = 0.0;
    var rawAlacak = c['tahminiAlacak'];
    if (rawAlacak != null) {
      if (rawAlacak is num) {
        tahminiAlacak = rawAlacak.toDouble();
      } else if (rawAlacak is String) {
        tahminiAlacak = double.tryParse(rawAlacak) ?? 0.0;
      }
    }
    
    final int okunmamisMesaj = c['okunmamisMesaj'] ?? 0;
    final String muvekkilAd = c['muvekkilAd'] ?? '';
    final String muvekkilSoyad = c['muvekkilSoyad'] ?? '';
    // Alternatif alan adlarını dene
    final String? muvekkilAvatar = c['muvekkilAvatar'] ?? c['muvekkil_avatar'] ?? c['avatar'] ?? c['userAvatar'] ?? c['user_avatar'];
    final String muvekkilInitials = muvekkilAd.isNotEmpty ? muvekkilAd[0].toUpperCase() : 'M';

    // Debug: Avatar URL'sini kontrol et
    debugPrint('AVATAR DEBUG: raw=$muvekkilAvatar, resolved=${_resolveAvatarUrl(muvekkilAvatar)}');

    String kisaltilmisTarih = '';
    if (createdAt != null) {
      try {
        kisaltilmisTarih = dateFormat.format(DateTime.parse(createdAt.toString()));
      } catch (e) {
        kisaltilmisTarih = createdAt.toString();
      }
    }

    return InkWell(
      onTap: () => context.push('/chat/$caseId'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildAvatar(avatarPath: muvekkilAvatar, initials: muvekkilInitials, radius: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  muvekkilAd.isNotEmpty ? '$muvekkilAd $muvekkilSoyad' : 'Müvekkil',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  davaTuru,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sehir, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              Text(kisaltilmisTarih, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Tahmini Alacak', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              Text(
                                currencyFormat.format(tahminiAlacak),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (okunmamisMesaj > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE63946),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$okunmamisMesaj Yeni',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/chat/$caseId'),
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('Sohbeti Aç'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
