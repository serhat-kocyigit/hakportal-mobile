import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AuthService {
  /// Kullanıcı profilini getirir (şehir, ad, soyad vb.)
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await ApiService.dio.get('/auth/me');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Kullanıcı bilgileri alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
