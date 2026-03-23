import 'dart:async';
import 'package:flutter/material.dart';
import 'calculator_tab.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _hesaplamaCounter = 0;
  int _davaCounter = 0;
  Timer? _counterTimer;

  // Ön değerlendirme testi
  String? _preTestKimCikardi;
  String? _preTestSure;
  String? _preTestMaas;
  bool _preTestDone = false;
  String? _preTestSonuc;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
    _startCounters();
  }

  void _startCounters() {
    int hesaplamaTarget = 12480;
    int davaTarget = 543;
    int step = 0;
    int totalSteps = 60;
    _counterTimer = Timer.periodic(const Duration(milliseconds: 25), (t) {
      step++;
      if (step >= totalSteps) {
        setState(() {
          _hesaplamaCounter = hesaplamaTarget;
          _davaCounter = davaTarget;
        });
        t.cancel();
      } else {
        double progress = step / totalSteps;
        double ease = 1 - (1 - progress) * (1 - progress);
        setState(() {
          _hesaplamaCounter = (hesaplamaTarget * ease).toInt();
          _davaCounter = (davaTarget * ease).toInt();
        });
      }
    });
  }

  void _evaluatePreTest() {
    if (_preTestKimCikardi == null || _preTestSure == null || _preTestMaas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm soruları yanıtlayın.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    String sonuc;
    if (_preTestKimCikardi == 'ben') {
      if (_preTestSure == 'cok') {
        sonuc = '⚠️ İstifa durumunda kıdem tazminatı genelde alınamaz. Ancak haklı nedenle fesih veya emeklilik gibi istisnalar söz konusu olabilir. Detaylı değerlendirme için hesaplama yapın.';
      } else {
        sonuc = '❌ İstifa ile ayrıldıysanız ve çalışma süreniz kısaysa tazminat hakkınız büyük olasılıkla yoktur. Ücretsiz hesaplama yaparak durumunuzu netleştirin.';
      }
    } else if (_preTestKimCikardi == 'isveren') {
      if (_preTestSure == 'az') {
        sonuc = '⚠️ 6 aydan az çalıştıysanız kıdem tazminatı hakkınız oluşmaz ancak haksız fesih tazminatı ve diğer alacaklar söz konusu olabilir.';
      } else if (_preTestMaas == 'alti') {
        sonuc = '⚠️ Asgari ücretin altında çalışmanız hukuka aykırıdır. Hem ücret alacağınız hem de diğer haklarınız güçlü bir hukuki zemine sahiptir.';
      } else {
        sonuc = '✅ İşverenin işbirliği ile işten çıkarıldıysanız kıdem ve ihbar tazminatı başta olmak üzere birden fazla hakkınız olabilir. Şimdi hesaplayın!';
      }
    } else if (_preTestKimCikardi == 'anlasma') {
      sonuc = '⚠️ Anlaşmalı (ikale) ayrılışlarda imzalanan belgelerin içeriği kritiktir. Haklarınızı almadan imzalamış olabilirsiniz. Hukuki değerlendirme için hesaplama yapın.';
    } else {
      sonuc = '✅ Askerlik, emeklilik veya evlilik nedeniyle ayrılanlarda bazı alacak hakları doğabilir. Hesaplama aracımızla net rakamı öğrenin.';
    }

    setState(() {
      _preTestSonuc = sonuc;
      _preTestDone = true;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _counterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: CustomScrollView(
        slivers: [
          // NAVBAR
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.bgCard,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('⚖️ ', style: TextStyle(fontSize: 20)),
                Text('Hak', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                Text('Portal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryLight)),
              ],
            ),
            actions: [
              if (auth.isAuthenticated) ...[
                TextButton(
                  onPressed: () {
                    final user = auth.user;
                    final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
                    if (role == 'admin') {
                      context.push('/admin_panel');
                    } else if (role == 'avukat') {
                      context.push('/lawyer_panel');
                    } else {
                      context.push('/user_panel');
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text('Panele Git', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => context.push('/login'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Giriş', style: TextStyle(fontSize: 13)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () => context.push('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ücretsiz Başla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildHeroSection(context, auth),
                    _buildFeaturesSection(),
                    _buildCalculatorSection(),
                    _buildHowItWorksSection(),
                    _buildBlogSection(),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── HERO ─────────────
  Widget _buildHeroSection(BuildContext context, AuthProvider auth) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -60, left: -60, child: _buildOrb(200, AppColors.primary.withValues(alpha: 0.15))),
          Positioned(bottom: -40, right: -40, child: _buildOrb(180, AppColors.accent.withValues(alpha: 0.10))),
          Positioned(top: 100, right: -30, child: _buildOrb(120, AppColors.primary.withValues(alpha: 0.08))),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
            child: Column(
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("Türkiye'nin İşçi Hakları Platformu",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Başlık — web ile birebir
                const Text(
                  'İşten Çıkarıldın mı?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'Ne Kadar Alacağın',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primaryLight, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  '30 Saniyede Hesapla.',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Alt başlık
                const Text(
                  'Kıdem, ihbar ve diğer alacaklarını güncel Yargıtay standartlarında ücretsiz hesapla. Dava dosyanı oluşturup şehrindeki avukatlardan anında teklif al. Sadece 99₺ güven bedeliyle yasal sürecini hızla başlat!',
                  style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.65),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // CTA Butonları
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (auth.isAuthenticated) {
                          final user = auth.user;
                          final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
                          if (role == 'admin') {
                            context.push('/admin_panel');
                          } else if (role == 'avukat') {
                            context.push('/lawyer_panel');
                          } else {
                            context.push('/user_panel');
                          }
                        } else {
                          context.push('/register');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      icon: const SizedBox.shrink(),
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Hesaplamaya Başla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Nasıl Çalışır?', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // İstatistikler
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        _hesaplamaCounter >= 1000
                            ? '${(_hesaplamaCounter / 1000).toStringAsFixed(1)}K+'
                            : '$_hesaplamaCounter',
                        'Hesaplama\nYapıldı',
                      ),
                      Container(width: 1, height: 36, color: Colors.white12),
                      _buildStatItem('$_davaCounter+', 'Tamamlanan\nDava'),
                      Container(width: 1, height: 36, color: Colors.white12),
                      _buildStatItem('%100', 'Ücretsiz'),
                      Container(width: 1, height: 36, color: Colors.white12),
                      _buildStatItem('3 dk.', 'Ortalama\nSüre'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Hesap Makinesi Önizleme Kartı
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2333),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF21293A),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: Colors.white12)),
                        ),
                        child: Row(
                          children: [
                            _buildDot(const Color(0xFFFF5F57)),
                            const SizedBox(width: 6),
                            _buildDot(const Color(0xFFFFBD2E)),
                            const SizedBox(width: 6),
                            _buildDot(const Color(0xFF28C840)),
                            const Spacer(),
                            const Text('Kıdem Hesaplama', style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildCalcRow('Çalışma Süresi', '4 Yıl, 3 Ay'),
                            _buildCalcRow('Kıdem Tazminatı', '₺87.640', isGreen: true),
                            _buildCalcRow('İhbar Tazminatı', '₺18.200', isGreen: true),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(color: Colors.white12),
                            ),
                            _buildCalcRow('Tahmini Toplam', '₺105.840', isBold: true, isLarge: true),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                if (auth.isAuthenticated) {
                                  final user = auth.user;
                                  final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
                                  if (role == 'admin') {
                                    context.push('/admin_panel');
                                  } else if (role == 'avukat') {
                                    context.push('/lawyer_panel');
                                  } else {
                                    context.push('/user_panel');
                                  }
                                } else {
                                  context.push('/register');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF8B5CF6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('⚖️', style: TextStyle(fontSize: 16)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Dosyanı Avukatlara Çıkar →',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── ÖN DEĞERLENDİRME TESTİ (web'deki homePreTestContainer) ─────────────
  Widget _buildPreTestSection(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      color: AppColors.bgSurface,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 32)],
        ),
        child: _preTestDone ? _buildPreTestSonuc(context, auth) : _buildPreTestForm(),
      ),
    );
  }

  Widget _buildPreTestForm() {
    return Column(
      children: [
        const Text('🔍', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        const Text('Ön Değerlendirme Testi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text(
          'Hak durumunuzu 30 saniyede anlayın.\n3 soruyu yanıtlayın, sisteme girin.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Soru 1
        _buildPreTestDropdown(
          label: 'İşten kim çıkardı?',
          value: _preTestKimCikardi,
          items: const [
            DropdownMenuItem(value: 'ben', child: Text('Ben kendi isteğimle (istifa) ayrıldım')),
            DropdownMenuItem(value: 'isveren', child: Text('İşveren (Patron) işime son verdi')),
            DropdownMenuItem(value: 'anlasma', child: Text('Anlaşarak / ikale ile ayrıldık')),
            DropdownMenuItem(value: 'diger', child: Text('Askerlik / Emeklilik / Evlilik sebebiyle')),
          ],
          onChanged: (v) => setState(() => _preTestKimCikardi = v),
        ),
        const SizedBox(height: 14),

        // Soru 2
        _buildPreTestDropdown(
          label: 'Aynı işyerinde kaç yıl çalıştınız?',
          value: _preTestSure,
          items: const [
            DropdownMenuItem(value: 'az', child: Text('6 aydan daha az')),
            DropdownMenuItem(value: 'orta', child: Text('6 ay – 1 yıl arası')),
            DropdownMenuItem(value: 'cok', child: Text('1 yıldan fazla (Uzun süreli)')),
          ],
          onChanged: (v) => setState(() => _preTestSure = v),
        ),
        const SizedBox(height: 14),

        // Soru 3
        _buildPreTestDropdown(
          label: 'Maaşınız yaklaşık ne kadardı?',
          value: _preTestMaas,
          items: const [
            DropdownMenuItem(value: 'alti', child: Text('Asgari ücretin altındaydı')),
            DropdownMenuItem(value: 'ustu', child: Text('Asgari ücret veya daha üzerindeydi')),
          ],
          onChanged: (v) => setState(() => _preTestMaas = v),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _evaluatePreTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Testi Tamamla ve Hesaplamaya Geç ➔',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreTestDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C2333),
              hint: const Text('Lütfen seçiniz...', style: TextStyle(color: Colors.white38, fontSize: 14)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreTestSonuc(BuildContext context, AuthProvider auth) {
    final isPositive = _preTestSonuc?.startsWith('✅') ?? false;
    final borderColor = isPositive ? AppColors.accent : const Color(0xFFFFBD2E);
    final bgColor = isPositive
        ? AppColors.accent.withValues(alpha: 0.07)
        : const Color(0xFFFFBD2E).withValues(alpha: 0.07);

    return Column(
      children: [
        const Text('🔍', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        const Text('Ön Değerlendirme Sonucu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            _preTestSonuc ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (auth.isAuthenticated) {
                final user = auth.user;
                final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
                if (role == 'admin') {
                  context.push('/admin_panel');
                } else if (role == 'avukat') {
                  context.push('/lawyer_panel');
                } else {
                  context.push('/user_panel');
                }
              } else {
                context.push('/register');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Detaylı Hesaplama Yap ⚖️',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _preTestDone = false;
            _preTestKimCikardi = null;
            _preTestSure = null;
            _preTestMaas = null;
            _preTestSonuc = null;
          }),
          child: const Text('← Testi Yeniden Başlat',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value,
      {bool isGreen = false, bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                color: isBold ? Colors.white : Colors.white54,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontSize: isLarge ? 18 : 14,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: isGreen ? AppColors.accent : (isBold ? Colors.white : Colors.white70),
              )),
        ],
      ),
    );
  }

  // ───────────── HAKLARINIZİ HESAPLIYORUZ ─────────────
  Widget _buildFeaturesSection() {
    final features = [
      _FeatureData('💰', 'Kıdem Tazminatı', 'Her yıl için 30 günlük brüt ücret. Kıdem tavanı uygulanır.'),
      _FeatureData('📅', 'İhbar Tazminatı', '2-8 haftalık ihbar süresi. Çalışma sürenize göre otomatik hesaplanır.'),
      _FeatureData('⏰', 'Fazla Mesai', 'Haftada 45 saati aşan çalışmalar için tam korumalı ücret hesabı.'),
      _FeatureData('🏖️', 'Yıllık İzin Ücreti', 'Kullanılmamış yıllık izin günlerinin son maaştan ücret karşılığı.'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      color: AppColors.bgSurface,
      child: Column(
        children: [
          const Text(
            'Hangi Haklarınızı Hesaplıyoruz?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Türk İş Kanunu'na göre tüm temel işçi alacakları",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: features.map((f) => _buildFeatureCard(f)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureData f) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(f.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(f.desc, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.45), overflow: TextOverflow.fade),
          ),
        ],
      ),
    );
  }

  // ───────────── HESAPLAMA ─────────────
  Widget _buildCalculatorSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
            child: Column(
              children: const [
                Text(
                  '⚖️ Tazminat Hesaplama',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Bilgilerinizi girin, anında hesaplayalım.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const CalculatorTab(isEmbedded: true),
        ],
      ),
    );
  }

  // ───────────── NASIL ÇALIŞIR ─────────────
  Widget _buildHowItWorksSection() {
    final steps = [
      _StepData('01', '🧮', 'Hesapla', 'Maaş ve tarih bilgilerinizi yapay zeka destekli motorumuza girerek net haklarınızı hesaplayın.'),
      _StepData('02', '📋', 'Teklif Al & Seç', 'Dosyanızı sistemdeki avukatlara isimsiz sunun ve gelen teklifler arasından en uygununu seçin.'),
      _StepData('03', '🛡️', 'Güvence Bedeli', 'Siz sadece 99₺ güven bedelini ödeyip vekalet sürecini başlatın, gerisini avukatınız platforma ödeyecektir.'),
      _StepData('04', '💬', 'Dava ve İletişim', 'Kabul işleminden sonra mesajlaşma açılır, belgeleri yükleyin ve kapandıktan sonra avukatınızı değerlendirin!'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      color: AppColors.bgCard,
      child: Column(
        children: [
          const Text('Nasıl Çalışır?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('4 adımda haklarınıza kavuşun',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(s.number,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                          ),
                          const SizedBox(height: 8),
                          Text(s.icon, style: const TextStyle(fontSize: 36)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 6),
                            Text(s.desc,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 28),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ───────────── BLOG / REHBER ─────────────
  Widget _buildBlogSection() {
    final blogs = [
      _BlogData(
        '📖', 'Kıdem',
        'Kıdem Tazminatı Nedir? Kimler Alabilir?',
        'İş Kanunu\'na göre kıdem tazminatının tüm şartları, hesaplama mantığı ve işçiyi koruyan detaylar.',
        '''Kıdem tazminatı, bir işçinin en az 1 yıl çalıştığı iş yerinden ayrılması durumunda bazı koşulların gerçekleşmesi halinde işveren tarafından ödenmesi gereken yasal bir alacaktır.

🔹 KİMLER ALABİLİR?
• İşveren tarafından haksız ya da geçerli nedenle işten çıkarılanlar
• Askerlik nedeniyle işten ayrılanlar
• Emeklilik, yaşlılık veya malullük aylığı almaya hak kazananlar
• Kadın işçiler evlendikten sonraki 1 yıl içinde kendi istekleriyle ayrılanlar
• İş sözleşmesinin işçi tarafından haklı nedenle feshedilmesi (mobing, ücret ödenmemesi vb.)

🔹 HESAPLAMA MANTIKI
Her tam çalışma yılı için 30 günlük brüt ücret esas alınır. Kısmi yıllar ise oransal hesaplanır. 2026 yılı kıdem tazminatı tavanı aylık 35.058,58 TL olarak belirlenmiştir; bu meblağı aşan kısım ödenmez.

🔹 ÖNEMLİ NOTLAR
• Kendi isteğiyle (istifa ile) ayrılanlar GENEL KURAL olarak kıdem tazminatı alamaz
• İşten çıkarma ibranamelere imzalatılarak hak kaybettirilmeye çalışılabilir — İmzalamadan önce mutlaka hukuki danışmanlık alın
• Hak doğuran ayrılıştan itibaren 10 yıllık zamanaşımı süreniz vardır''',
      ),
      _BlogData(
        '⏱️', 'İhbar',
        'İhbar Süreleri ve Tazminat Hesabı',
        'İhbar öneli tam olarak nedir? Çalışma sürenize göre ihbar tazminatınızı öğrenin.',
        '''İhbar tazminatı, iş sözleşmesini sona erdiren tarafın yasal bildirim (ihbar) süresine uymadan sözleşmeyi feshetmesi durumunda ödenmesi gereken bedeldir.

🔹 İHBAR SÜRELERİ (İş Kanunu Madde 17)
• 6 aydan az çalışma → 2 hafta
• 6 ay – 1.5 yıl arası → 4 hafta
• 1.5 yıl – 3 yıl arası → 6 hafta
• 3 yıldan fazla → 8 hafta

🔹 KİM KİME ÖDER?
İşveren bildirim süresine uymadan çıkarırsa: İşçiye ihbar tazminatı öder.
İşçi haber vermeden ayrılırsa: İşçi işverene ihbar tazminatı öder.

🔹 HESAPLAMA YÖNTEMİ
Günlük brüt ücret × İhbar süresi (gün) formülüyle hesaplanır. Brüt ücrete prim, ikramiye, yemek, yol gibi yan haklar da dahil edilir (giydirilmiş ücret).

🔹 ÖNEMLİ
• İhbar tazminatı için en az 1 yıl çalışma şartı YOKTUR
• Kıdem tazminatının aksine daha kısa çalışmalar için de geçerlidir
• Tazminat üzerinden %15 gelir vergisi ve damga vergisi kesilir''',
      ),
      _BlogData(
        '🔍', 'Hukuk',
        'İşten Çıkarıldığınızda İlk 10 Adım',
        'Panik yapmadan, haklarınızı kaybetmeden atmanız gereken kritik adımlar.',
        '''Aniden işsiz kaldınız. İlk saatlerde doğru adımları atmak, haklarınızın büyük bölümünü korumanızı sağlar. İşte yapmanız gerekenler:

1️⃣ SOĞUKKANLI OLUN — İşverenle tartışmaya girmeyin; yazışmaları kaydedin.

2️⃣ İBRANAMEYİ İMZALAMAYIN — "Tüm haklarımı aldım" anlamına gelen belgeleri imzalamak hak kaybına yol açar. Baskı olsa bile imzalamayın.

3️⃣ SGK ÇIKIŞ KODUNU KONTROL EDİN — İşten çıkış kodunuz, tazminat haklarınızı doğrudan etkiler. e-Devlet üzerinden kontrol edin. Hatalı kod varsa düzeltilmesini talep edin.

4️⃣ İŞE İADE DAVASINI DEĞERLENDIRIN — 30 veya daha fazla işçi çalıştıran iş yerlerinde en az 6 ay kıdemi olan çalışanlar işe iade davası açabilir. Fesih bildiriminden itibaren 1 AY içinde arabulucuya başvurulmalıdır.

5️⃣ TÜM BELGELERİ TOPLAYIN — İş sözleşmesi, bordro, işe giriş-çıkış kayıtları, mesaj ekran görüntüleri, tanık isimleri.

6️⃣ ARABULUCUYA BAŞVURUN — İşçi alacaklarında dava açmadan önce arabuluculuk zorunludur.

7️⃣ TAZMINAT HESAPLAYIN — Kıdem, ihbar, fazla mesai, yıllık izin gibi tüm alacaklarınızı HakPortal üzerinde ücretsiz hesaplayın.

8️⃣ AVUKAT ALACAKLARINI KARŞILAŞTIRIN — HakPortal\'ın şehrinize ait avukatlarından teklif alın.

9️⃣ İŞSİZLİK BAŞVURUSU YAPIN — Tazminata ek olarak işsizlik ödeneğine de hak kazanmış olabilirsiniz.

🔟 ZAMANAŞIMINI GÖZDEN KAÇIRMAYIN — İşçi alacaklarında genel zamanaşımı 5 yıl, feshe bağlı alacaklarda ise 10 yıldır.''',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      color: AppColors.bgSurface,
      child: Column(
        children: [
          const Text('İşçi Hakları Rehberi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Haklarınızı öğrenin, bilinçli kararlar alın',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ...blogs.map((b) => _buildBlogCard(b, onTap: () => _openBlogModal(context, b))),
        ],
      ),
    );
  }

  void _openBlogModal(BuildContext context, _BlogData b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Text(b.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(b.tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(b.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              Text(b.fullContent, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.75)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlogCard(_BlogData b, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(b.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(b.tag,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(b.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(b.desc,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                maxLines: 4,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            const Text(
              'Devamını Oku →',
              style: TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── FOOTER ─────────────
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('⚖️ ', style: TextStyle(fontSize: 22)),
              Text('Hak', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
              Text('Portal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryLight)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Türkiye'de çalışan işçilerin hukuki haklarını öğrenmelerine ve avukat bulmalarına yardımcı olan dijital platform.",
            style: TextStyle(fontSize: 13, color: Colors.white38, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Platform hukuki danışmanlık sunmaz. Tüm hesaplamalar tahminidir.',
            style: TextStyle(fontSize: 11, color: Colors.white24),
          ),
          const SizedBox(height: 28),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Platform',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 12),
                    _buildFooterLink('Hesaplama', () => context.push('/register')),
                    _buildFooterLink('Avukat Başvuru', () => context.push('/register')),
                    _buildFooterLink('Giriş Yap', () => context.push('/login')),
                    _buildFooterLink('Kayıt Ol', () => context.push('/register')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hukuki',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 12),
                    _buildFooterLink('KVKK Aydınlatma', () {}),
                    _buildFooterLink('Kullanım Şartları', () {}),
                    _buildFooterLink('Gizlilik Politikası', () {}),
                    _buildFooterLink('Açık Rıza Metni', () {}),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          const Text('© 2024 HakPortal. Tüm hakları saklıdır.',
              style: TextStyle(fontSize: 12, color: Colors.white24)),
          const SizedBox(height: 4),
          const Text('Bu platform bilgilendirme amaçlıdır. Hukuki tavsiye verilmez.',
              style: TextStyle(fontSize: 11, color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white38)),
      ),
    );
  }
}

// ─── Data Models ───
class _FeatureData {
  final String icon, title, desc;
  const _FeatureData(this.icon, this.title, this.desc);
}

class _StepData {
  final String number, icon, title, desc;
  const _StepData(this.number, this.icon, this.title, this.desc);
}

class _BlogData {
  final String emoji, tag, title, desc, fullContent;
  const _BlogData(this.emoji, this.tag, this.title, this.desc, this.fullContent);
}
