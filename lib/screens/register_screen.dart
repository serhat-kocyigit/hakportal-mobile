import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  bool _isLawyer = false;
  bool _isLoading = false;

  void _requestRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService.dio.post('/auth/register', data: {
        'ad': _adController.text.trim(),
        'soyad': _soyadController.text.trim(),
        'email': _emailController.text.trim(),
        'telefon': _telefonController.text.trim(),
        'sifre': _passwordController.text,
        'role': _isLawyer ? 'LAWYER' : 'USER',
      });
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kayıt Başarılı! Lütfen giriş yapın.'), 
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pushReplacement('/login');
      }
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      final errorMsg = e.response?.data['error'] ?? 'Kayıt olurken bir hata oluştu.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $errorMsg', style: const TextStyle(fontWeight: FontWeight.bold)), 
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ücretsiz Kayıt Ol', style: TextStyle(fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aramıza Katıl',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Row içinde Ad ve Soyad
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _adController,
                          decoration: const InputDecoration(labelText: 'Ad'),
                          validator: (val) => val!.isEmpty ? 'Boş olamaz' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _soyadController,
                          decoration: const InputDecoration(labelText: 'Soyad'),
                          validator: (val) => val!.isEmpty ? 'Boş olamaz' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _telefonController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon No (5XX...)',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (val) => val!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta Adresi',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) => val!.isEmpty || !val.contains('@') ? 'Geçerli e-posta girin' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Şifreniz',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (val) => val!.length < 6 ? 'En az 6 karakter girin' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Avukatım', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sisteme avukat olarak kayıt olmak istiyorum', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    value: _isLawyer,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isLawyer = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _requestRegister,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Kayıt Ol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pushReplacement('/login'),
                    child: const Text('Zaten hesabınız var mı? Giriş Yapın', style: TextStyle(color: AppColors.primaryLight)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
