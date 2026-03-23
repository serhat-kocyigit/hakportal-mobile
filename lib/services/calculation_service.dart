import 'dart:convert';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class CalculationService {
  static Future<Map<String, dynamic>> calculate({
    required String isGirisTarihi,
    required String isCikisTarihi,
    required double brutMaas,
    required String cikisSekli,
    double yanHaklar = 0,
    double kullanilmayanIzin = 0,
    double fazlaMesai = 0,
    double odenmemisMaasGun = 0,
    double kumulatifMatrah = 0,
    Map<String, dynamic>? aiFacts, // AI Wizard'dan gelen hukuki olgular
  }) async {
    try {
      final response = await ApiService.dio.post('/hesaplama/kidem-ihbar', data: {
        'isGirisTarihi': isGirisTarihi,
        'isCikisTarihi': isCikisTarihi,
        'brutMaas': brutMaas,
        'cikisSekli': cikisSekli,
        'yanHaklar': yanHaklar,
        'kullanilmayanIzin': kullanilmayanIzin,
        'fazlaMesai': fazlaMesai,
        'odenmemisMaasGun': odenmemisMaasGun,
        'kumulatifMatrah': kumulatifMatrah,
        'aiFacts': aiFacts != null ? jsonEncode(aiFacts) : '{}',
      });
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Hesaplama sunucusundan hata döndü.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }
}
