import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  bool _isLoading = true;
  final TextEditingController _kidemTavaniController = TextEditingController();
  final TextEditingController _skala1Controller = TextEditingController();
  final TextEditingController _skala2Controller = TextEditingController();
  final TextEditingController _skala3Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/settings/public');
      final s = response.data;
      
      if (mounted) {
        setState(() {
          _kidemTavaniController.text = (s['kidemTavani'] ?? '').toString();
          if (s['hizmetBedeliSkala'] != null && (s['hizmetBedeliSkala'] as List).isNotEmpty) {
            final skala = s['hizmetBedeliSkala'] as List;
            _skala1Controller.text = (skala[0]['ucret'] ?? 750).toString();
            if (skala.length > 1) _skala2Controller.text = (skala[1]['ucret'] ?? 1250).toString();
            if (skala.length > 2) _skala3Controller.text = (skala[2]['ucret'] ?? 2000).toString();
          } else {
            _skala1Controller.text = '750';
            _skala2Controller.text = '1250';
            _skala3Controller.text = '2000';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTavan() async {
    try {
      await ApiService.dio.put('/admin/ayarlar', data: {'kidemTavani': _kidemTavaniController.text});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kıdem tavanı güncellendi!'), backgroundColor: AppColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _saveSkala() async {
    try {
      final s1 = double.tryParse(_skala1Controller.text) ?? 750;
      final s2 = double.tryParse(_skala2Controller.text) ?? 1250;
      final s3 = double.tryParse(_skala3Controller.text) ?? 2000;

      await ApiService.dio.put('/admin/ayarlar', data: {
        'hizmetBedeliSkala': [
          {'min': 0, 'max': 20000, 'ucret': s1},
          {'min': 20000, 'max': 50000, 'ucret': s2},
          {'min': 50000, 'max': 999999999, 'ucret': s3}
        ]
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skala güncellendi!'), backgroundColor: AppColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sistem Ayarları', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _card('📊 Kıdem Tazminatı Tavanı', [
            const Text('Hesaplamalarda kullanılan güncel kıdem tazminatı tavan tutarını girin.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _kidemTavaniController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tavan Tutarı (TL)', border: OutlineInputBorder(), prefixText: '₺'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saveTavan,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
              child: const Text('Tavanı Güncelle'),
            ),
          ]),

          const SizedBox(height: 24),

          _card('💰 Hizmet Bedeli Skalası', [
            const Text('Tahmini alacak tutarına göre platform hizmet bedellerini belirleyin.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _skalaInput('0 - 20.000 TL arası', _skala1Controller),
            const SizedBox(height: 12),
            _skalaInput('20.000 - 50.000 TL arası', _skala2Controller),
            const SizedBox(height: 12),
            _skalaInput('50.000 TL üzeri', _skala3Controller),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveSkala,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
              child: const Text('Skalayı Güncelle'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _skalaInput(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(), suffixText: ' TL'),
          ),
        ),
      ],
    );
  }
}
