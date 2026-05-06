import 'package:dio/dio.dart';
import '../services/api_service.dart';

class CaseService {
  static Future<List<dynamic>> getMyCases() async {
    try {
      final response = await ApiService.dio.get('/cases/benim');
      final data = response.data;
      
      if (data is List) return data;
      
      // Esnek Okuma: data içindeyse çıkart
      if (data is Map) {
        if (data.containsKey('cases') && data['cases'] is List) return data['cases'];
        if (data.containsKey('data') && data['data'] is List) return data['data'];
        if (data.containsKey('items') && data['items'] is List) return data['items'];
      }

      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Davalarınızı çekerken bir sorun oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<Map<String, dynamic>> createCase({
    required String davaTuru,
    required double tahminiAlacak,
    Map<String, dynamic>? hesaplamaData,
    String? sehir,
    List<dynamic>? ispatBelgeleri,
  }) async {
    try {
      // aiFacts içinden skorlama bilgilerini çıkar
      final skorlama = hesaplamaData?['skorlama'] ?? {};
      
      final response = await ApiService.dio.post('/cases', data: {
        'davaTuru': davaTuru,
        'tahminilAcak': tahminiAlacak, // Backend bu şekilde bekliyor
        'brutMaas': hesaplamaData?['kidem']?['brut'] ?? 0,
        'hesaplamaVerisi': {
          'kidem': hesaplamaData?['kidem'],
          'ihbar': hesaplamaData?['ihbar'],
          'diger': hesaplamaData?['diger'],
          'toplamNet': hesaplamaData?['toplamNet'],
          'skorlama': skorlama,
          'legal': hesaplamaData?['legal'],
        },
        'sehir': sehir, // Kullanıcı profilinden alınacak
        'ispatBelgeleri': ispatBelgeleri,
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dava dosyası oluşturulurken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<List<dynamic>> getOpenCases() async {
    try {
      final response = await ApiService.dio.get('/cases/havuz');
      if (response.data is List) {
        return response.data;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Açık davalar çekilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<Map<String, dynamic>> getCaseDetails(String caseId) async {
    try {
      final response = await ApiService.dio.get('/cases/$caseId');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dava detayları çekilirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<void> deleteCase(String caseId) async {
    try {
      await ApiService.dio.delete('/cases/$caseId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dava silinirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<Map<String, dynamic>> updateStatus({
    required String caseId,
    required String status,
    required String aciklama,
    int? puan,
    String? yorum,
    double? tahsilat,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'status': status,
        'aciklama': aciklama,
      };
      if (puan != null) data['puan'] = puan;
      if (yorum != null) data['yorum'] = yorum;
      if (tahsilat != null) data['tahsilat'] = tahsilat;
      if (extra != null) data.addAll(extra);

      final response = await ApiService.dio.put('/cases/$caseId/status', data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dava durumu güncellenirken hata oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
