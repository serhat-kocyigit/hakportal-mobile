import 'package:dio/dio.dart';
import '../services/api_service.dart';

class OfferService {
  // Avukat teklif verir
  static Future<Map<String, dynamic>> submitOffer({
    required String caseId,
    required String ucretModeli,
    double? oran,
    double? sabitUcret,
    required bool onOdeme,
    required String tahminiSure,
    String? aciklama,
  }) async {
    try {
      final response = await ApiService.dio.post('/offers', data: {
        'caseId': caseId,
        'ucretModeli': ucretModeli,
        'oran': oran,
        'sabitUcret': sabitUcret,
        'onOdeme': onOdeme,
        'tahminiSure': tahminiSure,
        'aciklama': aciklama,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Teklif gönderilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Kullanıcı davaya gelen teklifleri listeler
  static Future<List<dynamic>> getCaseOffers(String caseId) async {
    try {
      final response = await ApiService.dio.get('/offers/case/$caseId');
      if (response.data is List) {
        return response.data;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dava teklifleri çekilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Kullanıcı teklif seçer
  static Future<Map<String, dynamic>> selectOffer(String offerId) async {
    try {
      final response = await ApiService.dio.put('/offers/$offerId/sec');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Teklif seçilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Avukat teklifi kabul eder (belgeleri inceledikten sonra)
  static Future<Map<String, dynamic>> acceptOffer(String offerId) async {
    try {
      final response = await ApiService.dio.put('/offers/$offerId/kabul');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Teklif kabul edilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Avukat tekliften vazgeçer
  static Future<Map<String, dynamic>> withdrawOffer(String offerId) async {
    try {
      final response = await ApiService.dio.put('/offers/$offerId/vazgec');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Tekliften vazgeçilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Kullanıcı 99 TL güven bedeli öder
  static Future<Map<String, dynamic>> payUserDeposit({
    required String offerId,
    required String kartNo,
    required String kartSahibi,
    required String sonKullanma,
    required String cvv,
  }) async {
    try {
      final response = await ApiService.dio.post('/offers/$offerId/kullanici-odeme', data: {
        'kartNo': kartNo,
        'kartSahibi': kartSahibi,
        'sonKullanma': sonKullanma,
        'cvv': cvv,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Ödeme sırasında hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // Avukat platform bedeli öder
  static Future<Map<String, dynamic>> payLawyerFee({
    required String offerId,
    required String kartNo,
    required String kartSahibi,
    required String sonKullanma,
    required String cvv,
  }) async {
    try {
      final response = await ApiService.dio.post('/offers/$offerId/avukat-odeme', data: {
        'kartNo': kartNo,
        'kartSahibi': kartSahibi,
        'sonKullanma': sonKullanma,
        'cvv': cvv,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Ödeme sırasında hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
