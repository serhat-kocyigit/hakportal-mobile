import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // ---------------------------------------------------------------------------
  // BAĞLANTI AYARLARI
  //
  // Android Emülatöründe:  10.0.2.2 → bilgisayarınızın localhost'una eşlenir
  // Gerçek Telefon/iOS:    bilgisayarınızın Wi-Fi IP'si kullanılmalı
  //
  // Şu an otomatik algılama yapılıyor.
  // Gerçek cihaz bağlantısı olmuyorsa aşağıdaki IP'yi elle değiştirin:
  //   static const String _realDeviceIp = '10.196.23.67';
  // ---------------------------------------------------------------------------
  static const String _realDeviceIp = '10.190.250.152'; // backend bilgisayarınızın local IP'si
  static const int _port = 3000;

  static String get baseUrl {
    // Android Emülatörü için 10.0.2.2, diğer her şey için gerçek IP
    if (Platform.isAndroid) {
      // Emülatörde çalışıyor olabilir, önce gerçek IP'yi deneyin.
      // Emülatörde çalışıyorsanız aşağıyı '10.0.2.2' yapın.
      return 'http://$_realDeviceIp:$_port/api';
    }
    return 'http://$_realDeviceIp:$_port/api';
  }

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static const _storage = FlutterSecureStorage();

  static void setupInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'hp_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // DEBUG: İstek logları (test bittikten sonra kaldırabilirsiniz)
        // ignore: avoid_print
        print('➡️ [API] ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // ignore: avoid_print
        print('✅ [API] ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // ignore: avoid_print
        print('❌ [API] ${e.response?.statusCode} ${e.requestOptions.path}: ${e.response?.data}');
        return handler.next(e);
      },
    ));
  }
}
