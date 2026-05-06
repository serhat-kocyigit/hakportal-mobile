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
  // Göreceli path → sunucu base URL'si ile birleştir
  // ApiService.baseUrl = 'http://IP:3000/api' → 'http://IP:3000' elde et
  final serverRoot = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
  return '$serverRoot$avatar';
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _activeTab = 'bilgi';
  bool _isLoading = false;
  bool _isFetchingProfile = false;
  Map<String, dynamic> _profilData = {};

  // Fotoğraf
  File? _selectedPhoto;

  // Şif re göster/gizle
  bool _showEski = false;
  bool _showYeni = false;
  bool _showYeniConfirm = false;

  // Controllers
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _telefonController = TextEditingController();
  final _adresController = TextEditingController();
  String? _selectedSehir;

  final _eskiSifreController = TextEditingController();
  final _yeniSifreController = TextEditingController();
  final _yeniSifreConfirmController = TextEditingController();

  final _baroController = TextEditingController();
  final _baroNoController = TextEditingController();
  final _deneyimYilController = TextEditingController();
  final _bioController = TextEditingController();
  final _unvanController = TextEditingController();

  String? _errorMsg;
  String? _sifreError;

  final List<String> _sehirler = [
    'Adana', 'Ankara', 'Antalya', 'Bursa', 'Diyarbakır', 'Erzurum',
    'Eskişehir', 'Gaziantep', 'İstanbul', 'İzmir', 'Kayseri', 'Kocaeli',
    'Konya', 'Malatya', 'Mersin', 'Samsun', 'Şanlıurfa', 'Trabzon', 'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telefonController.dispose();
    _adresController.dispose();
    _eskiSifreController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_isFetchingProfile) return;
    setState(() => _isFetchingProfile = true);
    try {
      final res = await ApiService.dio.get('/auth/me');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _profilData = data;
        _isFetchingProfile = false;
      });
    } catch (e) {
      // Fallback: AuthProvider'dan al
      final auth = context.read<AuthProvider>();
      setState(() {
        _profilData = auth.user ?? {};
        _isFetchingProfile = false;
      });
    }
  }

  void _fillEditForm() {
    _adController.text = _profilData['ad'] ?? '';
    _soyadController.text = _profilData['soyad'] ?? '';
    _telefonController.text = _profilData['telefon'] ?? '';
    _adresController.text = _profilData['adres'] ?? '';
    _unvanController.text = _profilData['unvan'] ?? '';
    _baroController.text = _profilData['baro'] ?? '';
    _baroNoController.text = _profilData['baroNo'] ?? '';
    _deneyimYilController.text = (_profilData['deneyimYil'] ?? '').toString();
    _bioController.text = _profilData['bio'] ?? '';
    _selectedSehir = _profilData['sehir'];
    _selectedPhoto = null;
    _errorMsg = null;
  }

  Future<void> _saveProfile() async {
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();
    if (ad.isEmpty || soyad.isEmpty || (_selectedSehir == null || _selectedSehir!.isEmpty)) {
      setState(() => _errorMsg = 'Ad, soyad ve şehir zorunludur.');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      String? finalAvatar = _profilData['avatar']?.toString();

      // 1. Yeni fotoğraf seçildiyse önce yükle
      if (_selectedPhoto != null) {
        final formData = FormData.fromMap({
          'avatar': await MultipartFile.fromFile(_selectedPhoto!.path, filename: 'avatar.jpg'),
        });
        final uploadRes = await ApiService.dio.post('/auth/upload-avatar', data: formData);
        finalAvatar = uploadRes.data['avatar']?.toString();
      }

      // 2. Profil bilgilerini kaydet
      final res = await ApiService.dio.put('/auth/profil', data: {
        'ad': ad,
        'soyad': soyad,
        'sehir': _selectedSehir,
        'telefon': _telefonController.text.trim(),
        'adres': _adresController.text.trim(),
        'unvan': _unvanController.text.trim(),
        'baro': _baroController.text.trim(),
        'baroNo': _baroNoController.text.trim(),
        'deneyimYil': int.tryParse(_deneyimYilController.text.trim()),
        'bio': _bioController.text.trim(),
        if (finalAvatar != null) 'avatar': finalAvatar,
      });

      // AuthProvider güncelle
      if (mounted) {
        final auth = context.read<AuthProvider>();
        await auth.refreshUser();
        setState(() { _isLoading = false; _profilData = res.data['user'] ?? _profilData; });
        await _loadProfile();
        setState(() => _activeTab = 'bilgi');
        _showSuccess('Profiliniz güncellendi! ✅');
      }
    } catch (e) {
      String msg = 'Güncelleme hatası.';
      if (e is DioException) msg = e.response?.data?['error'] ?? e.message ?? msg;
      setState(() { _isLoading = false; _errorMsg = msg; });
    }
  }

  Future<void> _changePassword() async {
    final eski = _eskiSifreController.text;
    final yeni = _yeniSifreController.text;
    final yeniConfirm = _yeniSifreConfirmController.text;

    if (eski.isEmpty || yeni.isEmpty || yeniConfirm.isEmpty) {
      setState(() => _sifreError = 'Tüm alanlar zorunludur.');
      return;
    }
    if (yeni.length < 8) {
      setState(() => _sifreError = 'Yeni şifre en az 8 karakter olmalı.');
      return;
    }
    if (yeni != yeniConfirm) {
      setState(() => _sifreError = 'Yeni şifreler eşleşmiyor.');
      return;
    }

    setState(() { _isLoading = true; _sifreError = null; });
    try {
      await ApiService.dio.put('/auth/sifre-degistir', data: {
        'eskiSifre': eski,
        'yeniSifre': yeni,
        'yeniSifreConfirm': yeniConfirm,
      });
      if (mounted) {
        setState(() { _isLoading = false; _activeTab = 'bilgi'; });
        _eskiSifreController.clear();
        _yeniSifreController.clear();
        _yeniSifreConfirmController.clear();
        _showSuccess('Şifreniz başarıyla değiştirildi! 🔒');
      }
    } catch (e) {
      String msg = 'Şifre değiştirme hatası.';
      if (e is DioException) msg = e.response?.data?['error'] ?? e.message ?? msg;
      setState(() { _isLoading = false; _sifreError = msg; });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked != null && mounted) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.accent),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sekme Başlıkları
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTabBtn('📋', 'Bilgilerim', 'bilgi')),
              const SizedBox(width: 8),
              Expanded(child: _buildTabBtn('✏️', 'Düzenle', 'duzenle')),
              const SizedBox(width: 8),
              Expanded(child: _buildTabBtn('🔒', 'Şifre', 'sifre')),
            ],
          ),
        ),

        // Sekme İçeriği
        Expanded(
          child: _isFetchingProfile && _profilData.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildTabContent(),
                ),
        ),
      ],
    );
  }

  Widget _buildTabBtn(String icon, String label, String tab) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = tab);
        if (tab == 'duzenle') _fillEditForm();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
              : Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
      default: return _buildBilgiTab();
    }
  }

  // ─── BİLGİLERİM ───────────────────────────────────────────────────────────
  Widget _buildBilgiTab() {
    final ad = _profilData['ad']?.toString() ?? '';
    final soyad = _profilData['soyad']?.toString() ?? '';
    final email = _profilData['email']?.toString() ?? '';
    final telefon = _profilData['telefon']?.toString() ?? '—';
    final sehir = _profilData['sehir']?.toString() ?? '—';
    final adres = _profilData['adres']?.toString() ?? '—';
    final avatar = _profilData['avatar']?.toString() ?? '';
    final role = _profilData['role']?.toString() ?? 'kullanici';
    final initials = '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatarWidget(_resolveAvatarUrl(avatar), initials, 32),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // İsim
          Text('$ad $soyad',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),

          // Rol rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role == 'admin' ? '⚙️ Yönetici' : (role == 'avukat' ? '⚖️ Avukat' : '👤 Kullanıcı'),
              style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(height: 32, color: AppColors.border),

          _buildInfoRow(Icons.phone_outlined, 'Telefon', telefon),
          _buildInfoRow(Icons.location_on_outlined, 'Şehir', sehir),
          _buildInfoRow(Icons.home_outlined, 'Adres', adres),

          if (role == 'avukat') ...[
            const Divider(height: 32, color: AppColors.border),
            _buildInfoRow(Icons.gavel_outlined, 'Unvan', _profilData['unvan'] ?? 'Avukat'),
            _buildInfoRow(Icons.account_balance_outlined, 'Baro', '${_profilData['baro'] ?? '—'} / ${_profilData['baroNo'] ?? '—'}'),
            _buildInfoRow(Icons.history_outlined, 'Deneyim', '${_profilData['deneyimYil'] ?? '0'} Yıl'),
            _buildInfoRow(Icons.info_outline, 'Hakkında', _profilData['bio'] ?? '—'),
          ],

          const SizedBox(height: 24),

          // Düzenle butonu
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _fillEditForm();
                setState(() => _activeTab = 'duzenle');
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('✏️ Profili Düzenle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Çıkış
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Çıkış Yap'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── DÜZENLE ───────────────────────────────────────────────────────────────
  Widget _buildDuzenleTab() {
    final avatar = _profilData['avatar']?.toString() ?? '';
    final ad = _profilData['ad']?.toString() ?? '';
    final soyad = _profilData['soyad']?.toString() ?? '';
    final initials = '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Profil Düzenle',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),

          // AVATAR SEÇİCİ
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 3),
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
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgCard, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Fotoğrafı değiştirmek için dokun',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 24),

          // Ad - Soyad
          Row(
            children: [
              Expanded(child: _buildField(_adController, 'Ad *', keyboardType: TextInputType.name)),
              const SizedBox(width: 12),
              Expanded(child: _buildField(_soyadController, 'Soyad *', keyboardType: TextInputType.name)),
            ],
          ),
          const SizedBox(height: 14),

          // Telefon - Şehir
          Row(
            children: [
              Expanded(
                child: _buildField(_telefonController, 'Telefon',
                    keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildSehirDropdown()),
            ],
          ),
          const SizedBox(height: 14),

          // Adres
          _buildField(_adresController, 'Adres',
              keyboardType: TextInputType.streetAddress,
              prefixIcon: Icons.home_outlined,
              maxLines: 2),
          const SizedBox(height: 20),

          if (_profilData['role'] == 'avukat') ...[
            const Divider(height: 32, color: AppColors.border),
            const Text('Avukat Bilgileri', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildField(_unvanController, 'Unvan (Örn: Av.)', prefixIcon: Icons.gavel_outlined),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildField(_baroController, 'Baro', prefixIcon: Icons.account_balance_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_baroNoController, 'Baro No')),
              ],
            ),
            const SizedBox(height: 14),
            _buildField(_deneyimYilController, 'Deneyim Yılı', keyboardType: TextInputType.number, prefixIcon: Icons.history_outlined),
            const SizedBox(height: 14),
            _buildField(_bioController, 'Hakkında (Bio)', maxLines: 4, prefixIcon: Icons.info_outline),
            const SizedBox(height: 20),
          ],

          // Hata mesajı
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(_errorMsg!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],

          // Butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _activeTab = 'bilgi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('İptal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.textMuted) : null,
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSehirDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSehir,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C2333),
          hint: const Text('Şehir *', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _sehirler
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) => setState(() => _selectedSehir = val),
        ),
      ),
    );
  }

  // ─── ŞİFRE DEĞİŞTİR ───────────────────────────────────────────────────────
  Widget _buildSifreTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Şifre Değiştir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),

          _buildPasswordField(_eskiSifreController, 'Mevcut Şifre', _showEski,
              onToggle: () => setState(() => _showEski = !_showEski)),
          const SizedBox(height: 14),
          _buildPasswordField(_yeniSifreController, 'Yeni Şifre (en az 8 karakter)', _showYeni,
              onToggle: () => setState(() => _showYeni = !_showYeni)),
          const SizedBox(height: 14),
          _buildPasswordField(_yeniSifreConfirmController, 'Yeni Şifre Tekrar', _showYeniConfirm,
              onToggle: () => setState(() => _showYeniConfirm = !_showYeniConfirm)),
          const SizedBox(height: 20),

          // Hata mesajı
          if (_sifreError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(_sifreError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],

          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Şifremi Değiştir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool show, {required VoidCallback onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: AppColors.textMuted),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  // ─── AVATAR WIDGET ─────────────────────────────────────────────────────────
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

  // ─── ÇIKIŞ DİALOG ─────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
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
