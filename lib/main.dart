import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ApiService'i Token yakalaması için ayağa kaldırıyoruz.
  ApiService.setupInterceptors(); 
  
  runApp(
    // AuthProvider'ı proje çapında state'e bağladık. 
    // Proje açıldığında ..initAuth() diyerek kayıtlı oturum var mı kontrol edilecek.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initAuth()),
      ],
      child: const HakPortalApp(),
    ),
  );
}

class HakPortalApp extends StatelessWidget {
  const HakPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HakPortal',
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
