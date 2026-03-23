import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

/// Avatar URL'sini tam sunucu adresine çevirir
String _resolveAvatarUrl(String? avatar) {
  if (avatar == null || avatar.isEmpty) return '';
  if (avatar.startsWith('http')) return avatar; // zaten tam URL
  final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
  return '$serverRoot$avatar';
}

class LawyerProfileTab extends StatefulWidget {
  const LawyerProfileTab({super.key});

  @override
  State<LawyerProfileTab> createState() => _LawyerProfileTabState();
}

class _LawyerProfileTabState extends State<LawyerProfileTab> {
  String _activeTab = 'bilgi';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;

  // Profil Verisi
  Map<String, dynamic> _profilData = {};

  // Düzenleme Form Controllers
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _telefonController = TextEditingController();
  final _bioController = TextEditingController();
  String? _selectedSehir;
  
  // Şifre Form Controllers
  final _eskiSifreController = TextEditingController();
  final _yeniSifreController = TextEditingController();
  final _yeniSifreConfirmController = TextEditingController();
  bool _eskiGoster = false;
  bool _yeniGoster = false;
  bool _yeniConfirmGoster = false;

  // Fotoğraf Yükleme
  final ImagePicker _picker = ImagePicker();
  File? _selectedPhoto;

  final List<String> _sehirler = [
    'Adana', 'Ankara', 'Antalya', 'Bursa', 'Diyarbakır', 'Erzurum', 
    'Eskişehir', 'Gaziantep', 'İstanbul', 'İzmir', 'Kayseri', 'Kocaeli', 
    'Konya', 'Malatya', 'Mersin', 'Samsun', 'Şanlıurfa', 'Trabzon', 'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfilVerisi();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telefonController.dispose();
    _bioController.dispose();
    _eskiSifreController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreConfirmController.dispose();
    super.dispose();
  }

  // ─── API ÇAĞRILARI ────────────────────────────────────────────────────────
  Future<void> _loadProfilVerisi() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await ApiService.dio.get('/avukat/profil');
      if (mounted) {
        setState(() {
          _profilData = response.data;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.response?.data['error'] ?? 'Profil yüklenemedi.';
          _isLoading = false;
        });
      }
    }
  }

  // Fotoğraf Seçimi
  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedPhoto = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();
    final sehir = _selectedSehir;

    if (ad.isEmpty || soyad.isEmpty || sehir == null) {
      setState(() => _errorMsg = 'Ad, soyad ve şehir alanları zorunludur.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      String? finalAvatar = _profilData['avatar'];

      // 1. Eğer yeni bir fotoğraf seçildiyse önce onu yükle
      if (_selectedPhoto != null) {
        final formData = FormData.fromMap({
          'avatar': await MultipartFile.fromFile(_selectedPhoto!.path, filename: 'avatar_av.jpg'),
        });

        final uploadRes = await ApiService.dio.post('/auth/upload-avatar', data: formData);
        finalAvatar = uploadRes.data['avatar']; // sunucudan dönen yeni path
      }

      // 2. Profil bilgilerini kaydet
      await ApiService.dio.put('/auth/profil', data: {
        'ad': ad,
        'soyad': soyad,
        'sehir': sehir,
        'telefon': _telefonController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar': finalAvatar,
      });

      // 3. Auth Provider'ı güncelle ve ekrana bilgi ver
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profiliniz güncellendi! ✅'), backgroundColor: AppColors.accent),
        );
        _selectedPhoto = null; // Sıfırla
        await _loadProfilVerisi(); // Yeni veriyi çek
        setState(() {
          _isSaving = false;
          _activeTab = 'bilgi'; // Bilgi sekmesine dön
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.response?.data['error'] ?? 'Profil kaydedilirken hata oluştu.';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_eskiSifreController.text.isEmpty || _yeniSifreController.text.isEmpty || _yeniSifreConfirmController.text.isEmpty) {
      setState(() => _errorMsg = 'Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      await ApiService.dio.put('/auth/sifre-degistir', data: {
        'eskiSifre': _eskiSifreController.text,
        'yeniSifre': _yeniSifreController.text,
        'yeniSifreConfirm': _yeniSifreConfirmController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifreniz başarıyla değiştirildi! 🔒'), backgroundColor: AppColors.accent),
        );
        _eskiSifreController.clear();
        _yeniSifreController.clear();
        _yeniSifreConfirmController.clear();
        setState(() {
          _isSaving = false;
          _activeTab = 'bilgi';
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.response?.data['error'] ?? 'Şifre değiştirilemedi.';
          _isSaving = false;
        });
      }
    }
  }

  // ─── YARDIMCI METOTLAR ────────────────────────────────────────────────────
  Widget _buildAvatarWidget(String resolvedUrl, String initials, double fontSize) {
    if (resolvedUrl.isNotEmpty) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight)),
        errorBuilder: (_, __, ___) => Center(
          child: Text(initials.isNotEmpty ? initials : '?',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    }
    return Center(
      child: Text(initials.isNotEmpty ? initials : '?',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  // ─── UI BİLEŞENLERİ ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sekme Navigasyonu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTabBtn('📋', 'Bilgilerim', 'bilgi')),
              Expanded(child: _buildTabBtn('✏️', 'Düzenle', 'duzenle')),
              Expanded(child: _buildTabBtn('🔒', 'Şifre', 'sifre')),
            ],
          ),
        ),

        // İçerik Alanı
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _errorMsg != null && _profilData.isEmpty
                  ? Center(child: Text(_errorMsg!, style: const TextStyle(color: AppColors.danger)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildTabContent(),
                    ),
        ),
      ],
    );
  }

  Widget _buildTabBtn(String icon, String label, String tabId) {
    final isActive = _activeTab == tabId;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabId;
          _errorMsg = null;
        });

        if (tabId == 'duzenle') {
          // Forma mevcut verileri aktar
          _adController.text = _profilData['ad'] ?? '';
          _soyadController.text = _profilData['soyad'] ?? '';
          _telefonController.text = _profilData['telefon'] ?? '';
          _bioController.text = _profilData['bio'] ?? '';
          if (_sehirler.contains(_profilData['sehir'])) {
            _selectedSehir = _profilData['sehir'];
          }
          _selectedPhoto = null;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primaryLight : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'bilgi': return _buildBilgiTab();
      case 'duzenle': return _buildDuzenleTab();
      case 'sifre': return _buildSifreTab();
      default: return const SizedBox();
    }
  }

  // ─── 1. BİLGİ SEKMESİ ─────────────────────────────────────────────────────
  Widget _buildBilgiTab() {
    final avatar = _profilData['avatar'] as String? ?? '';
    final ad = _profilData['ad'] ?? '';
    final soyad = _profilData['soyad'] ?? '';
    final unvan = _profilData['unvan'] ?? 'Av.';
    final initials = ad.isNotEmpty ? '${ad[0]}${soyad.isNotEmpty ? soyad[0] : ""}'.toUpperCase() : '?';
    
    final email = _profilData['email'] ?? '-';
    final telefon = _profilData['telefon'] ?? '-';
    final sehir = _profilData['sehir'] ?? '-';
    final bio = _profilData['bio'] as String? ?? '';
    
    final baro = _profilData['baro'] ?? '-';
    final baroNo = _profilData['baroNo'] ?? '-';
    
    final uzmanlikRaw = _profilData['uzmanlik'];
    final uzmanlik = uzmanlikRaw is List ? uzmanlikRaw.join(', ') : (uzmanlikRaw ?? '-');

    final onayDurumu = _profilData['profilOnay'] == 1 || _profilData['profilOnay'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header: Avatar & Ad Soyad
          Row(
            children: [
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatarWidget(_resolveAvatarUrl(avatar), initials, 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$unvan $ad $soyad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Avukat', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Temel Bilgiler
          _buildInfoItem('E-posta', email),
          _buildInfoItem('Telefon', telefon),
          _buildInfoItem('Şehir', sehir),
          _buildInfoItem('Baro', baro),
          _buildInfoItem('Baro No', baroNo.toString()),
          _buildInfoItem('Uzmanlık', uzmanlik.toString()),
          
          // Profil Onayı Rozeti
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 100, child: Text('Profil Onayı', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: onayDurumu ? const Color(0xFF00D9A3).withValues(alpha: 0.15) : const Color(0xFFFFB703).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: onayDurumu ? const Color(0xFF00D9A3).withValues(alpha: 0.3) : const Color(0xFFFFB703).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    onayDurumu ? '✅ Onaylı' : '⏳ Onay Bekliyor',
                    style: TextStyle(
                      color: onayDurumu ? const Color(0xFF00D9A3) : const Color(0xFFFFB703),
                      fontSize: 12,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (bio.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.border, height: 1)),
            CrossAxisAlignment.start.name == 'start' ? const SizedBox() : const SizedBox(), // Trivial, ignore
            Align(
              alignment: Alignment.centerLeft,
              child: const Text('Hakkında', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(bio, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
            ),
          ],
          
          const SizedBox(height: 24),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _activeTab = 'duzenle';
                    _adController.text = _profilData['ad'] ?? '';
                    _soyadController.text = _profilData['soyad'] ?? '';
                    _telefonController.text = _profilData['telefon'] ?? '';
                    _bioController.text = _profilData['bio'] ?? '';
                    if (_sehirler.contains(_profilData['sehir'])) _selectedSehir = _profilData['sehir'];
                    _selectedPhoto = null;
                  }),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Düzenle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showLogoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                    foregroundColor: AppColors.danger,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Çıkış'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── 2. DÜZENLE SEKMESİ ───────────────────────────────────────────────────
  Widget _buildDuzenleTab() {
    final avatar = _profilData['avatar'] as String? ?? '';
    final ad = _profilData['ad'] ?? '';
    final soyad = _profilData['soyad'] ?? '';
    final initials = ad.isNotEmpty ? '${ad[0]}${soyad.isNotEmpty ? soyad[0] : ""}'.toUpperCase() : '?';

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
          const Text('Profilini Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('Bilgilerini güncel tutarak daha güvenilir bir izlenim bırakabilirsin.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 24),

          // Fotoğraf Yükleme
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryLight, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedPhoto != null
                        ? Image.file(_selectedPhoto!, fit: BoxFit.cover)
                        : _buildAvatarWidget(_resolveAvatarUrl(avatar), initials, 28),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Form
          Row(
            children: [
              Expanded(child: _buildField(_adController, 'Adınız', prefixIcon: Icons.person_outline)),
              const SizedBox(width: 12),
              Expanded(child: _buildField(_soyadController, 'Soyadınız')),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(_telefonController, 'Telefon (555...)', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined),
          const SizedBox(height: 16),
          
          // Şehir Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSehir,
                isExpanded: true,
                hint: const Text('Şehir Seçin', style: TextStyle(color: AppColors.textMuted)),
                dropdownColor: AppColors.bgSurface,
                items: _sehirler.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _selectedSehir = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildField(_bioController, 'Hakkımda (Özgeçmiş vb.)', maxLines: 4),
          const SizedBox(height: 20),

          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Değişiklikleri Kaydet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _activeTab = 'bilgi'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('İptal'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ─── 3. ŞİFRE SEKMESİ ──────────────────────────────────────────────────────
  Widget _buildSifreTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           const Text('Şifre Değiştir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           const Text('Güvenliğin için şifreni düzenli olarak yenileyebilirsin.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
           const SizedBox(height: 24),

          _buildPasswordField(_eskiSifreController, 'Mevcut Şifre', _eskiGoster, () => setState(() => _eskiGoster = !_eskiGoster)),
          const SizedBox(height: 16),
          _buildPasswordField(_yeniSifreController, 'Yeni Şifre', _yeniGoster, () => setState(() => _yeniGoster = !_yeniGoster)),
          const SizedBox(height: 16),
          _buildPasswordField(_yeniSifreConfirmController, 'Yeni Şifre (Tekrar)', _yeniConfirmGoster, () => setState(() => _yeniConfirmGoster = !_yeniConfirmGoster)),
          const SizedBox(height: 20),

          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],

          ElevatedButton(
            onPressed: _isSaving ? null : _changePassword,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Şifremi Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {TextInputType keyboardType = TextInputType.text, IconData? prefixIcon, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textMuted, size: 20) : null,
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool isVisible, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: !isVisible,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (ctx.mounted) context.go('/');
            },
            child: const Text('Çıkış', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
