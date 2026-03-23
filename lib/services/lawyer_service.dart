import 'package:dio/dio.dart';
import '../services/api_service.dart';

class LawyerService {
  // GET /api/avukat/acik-davalar
  static Future<List<dynamic>> getOpenCases() async {
    try {
      final response = await ApiService.dio.get('/avukat/acik-davalar');
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data.containsKey('cases') && data['cases'] is List) return data['cases'];
      if (data is Map && data.containsKey('data') && data['data'] is List) return data['data'];
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Açık davalar alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // GET /api/avukat/tekliflerim
  static Future<List<dynamic>> getMyOffers() async {
    try {
      final response = await ApiService.dio.get('/avukat/tekliflerim');
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data.containsKey('offers') && data['offers'] is List) return data['offers'];
      if (data is Map && data.containsKey('data') && data['data'] is List) return data['data'];
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Teklifler alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // GET /api/avukat/aktif-davalar - Web'de /tekliflerim endpoint'i kullanılıyor
  static Future<List<dynamic>> getActiveCases() async {
    try {
      final response = await ApiService.dio.get('/avukat/tekliflerim');
      final data = response.data;
      
      if (data is List) return data;
      
      // Eğer backend veriyi bir obje içinde döndürüyorsa
      if (data is Map && data.containsKey('offers') && data['offers'] is List) {
        return data['offers'];
      }
      if (data is Map && data.containsKey('data') && data['data'] is List) {
        return data['data'];
      }

      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Aktif davalar alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // GET /api/avukat/kapanan-davalar
  static Future<List<dynamic>> getClosedCases() async {
    try {
      final response = await ApiService.dio.get('/avukat/kapanan-davalar');
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data.containsKey('cases') && data['cases'] is List) return data['cases'];
      if (data is Map && data.containsKey('data') && data['data'] is List) return data['data'];
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Kapanan davalar alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // POST /api/offers
  static Future<void> sendOffer({
    required String caseId,
    required String ucretModeli, // 'yuzde' veya 'sabit'
    double? oran,
    double? sabitUcret,
    bool onOdeme = false,
    required String tahminiSure,
    String aciklama = '',
  }) async {
    try {
      await ApiService.dio.post('/offers', data: {
        'caseId': caseId,
        'ucretModeli': ucretModeli,
        'oran': oran,
        'sabitUcret': sabitUcret,
        'onOdeme': onOdeme,
        'tahminiSure': tahminiSure,
        'aciklama': aciklama,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Teklif gönderilemedi.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // GET /api/avukat/profil
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await ApiService.dio.get('/avukat/profil');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Profil alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // PUT /api/offers/:id/kabul
  static Future<void> acceptMatching(String offerId) async {
    try {
      await ApiService.dio.put('/offers/$offerId/kabul');
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dosya kabul edilemedi.');
    }
  }

  // PUT /api/offers/:id/vazgec
  static Future<void> withdrawFromMatching(String offerId) async {
    try {
      await ApiService.dio.put('/offers/$offerId/vazgec');
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dosyadan vazgeçilemedi.');
    }
  }

  // POST /api/offers/:id/avukat-odeme
  static Future<void> payPlatformFee(String offerId, Map<String, dynamic> cardData) async {
    try {
      await ApiService.dio.post('/offers/$offerId/avukat-odeme', data: cardData);
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Ödeme işlemi başarısız.');
    }
  }
}
