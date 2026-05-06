import 'package:dio/dio.dart';
import '../services/api_service.dart';

class LawyerService {
  // ---- YENİ MODEL: GELEN TALEPLER ----
  
  // GET /api/offers/gelen-talepler
  static Future<List<dynamic>> getIncomingRequests() async {
    try {
      final response = await ApiService.dio.get('/offers/gelen-talepler');
      final data = response.data;
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Gelen talepler alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // PUT /api/offers/talep/:id/kabul
  static Future<void> acceptRequest(String talepId) async {
    try {
      await ApiService.dio.put('/offers/talep/$talepId/kabul');
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Talep kabul edilemedi.');
    } catch (e) {
      throw Exception('Hata: $e');
    }
  }

  // PUT /api/offers/talep/:id/reddet
  static Future<void> rejectRequest(String talepId) async {
    try {
      await ApiService.dio.put('/offers/talep/$talepId/reddet');
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Talep reddedilemedi.');
    } catch (e) {
      throw Exception('Hata: $e');
    }
  }

  // POST /api/offers/iletisim-talebi
  static Future<void> sendContactRequest({required String avukatId, String? caseId, String? not}) async {
    try {
      await ApiService.dio.post('/offers/iletisim-talebi', data: {
        'avukatId': avukatId,
        'caseId': caseId,
        'not': not,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'İletişim talebi gönderilemedi.');
    } catch (e) {
      throw Exception('Hata: $e');
    }
  }

  // ---- MEVCUT METODLAR (Geriye Dönük Uyumluluk İçin Kısmen Korundu) ----

  // GET /api/cases/avukat/tum-dosyalar - Avukatın tüm müvekkil dosyaları
  static Future<List<dynamic>> getAllClientFiles() async {
    try {
      final response = await ApiService.dio.get('/cases/avukat/tum-dosyalar');
      final data = response.data;
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dosyalar alınamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  // ---- MEVCUT METODLAR (Geriye Dönük Uyumluluk İçin Kısmen Korundu) ----

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

  // GET /api/offers/avukatlar?sehir=...
  static Future<List<dynamic>> searchLawyers(String city, [String? caseId]) async {
    try {
      final Map<String, dynamic> queryParams = {'sehir': city};
      if (caseId != null) queryParams['caseId'] = caseId;

      final response = await ApiService.dio.get('/offers/avukatlar', queryParameters: queryParams);
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data.containsKey('avukatlar') && data['avukatlar'] is List) return data['avukatlar'];
      if (data is Map && data.containsKey('lawyers') && data['lawyers'] is List) return data['lawyers'];
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Avukatlar aranamadı.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
