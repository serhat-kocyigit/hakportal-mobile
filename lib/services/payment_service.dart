import 'package:dio/dio.dart';
import '../services/api_service.dart';

class PaymentService {
  static const double PLATFORM_UCRETI = 99.0;

  static Future<Map<String, dynamic>> processPayment({
    required String caseId,
    required String kartNo,
    required String sonKullanma,
    required String cvv,
    required String kartSahibi,
  }) async {
    try {
      final response = await ApiService.dio.post('/offers/odeme', data: {
        'caseId': caseId,
        'kartNo': kartNo,
        'sonKullanma': sonKullanma,
        'cvv': cvv,
        'kartSahibi': kartSahibi,
        'tutar': PLATFORM_UCRETI,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Ödeme işlemi sırasında hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<Map<String, dynamic>> getPaymentStatus(String caseId) async {
    try {
      final response = await ApiService.dio.get('/offers/odeme-durum/$caseId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Ödeme durumu kontrol edilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
