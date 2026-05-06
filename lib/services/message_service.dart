import 'package:dio/dio.dart';
import '../services/api_service.dart';

class MessageService {
  static Future<List<dynamic>> getMessages(String caseId) async {
    try {
      final response = await ApiService.dio.get('/messages/$caseId');
      if (response.data is List) return response.data;
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Mesajları alırken bir sorun oluştu.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<void> sendMessage(String caseId, String content) async {
    try {
      await ApiService.dio.post('/messages', data: {
        'caseId': caseId,
        'icerik': content,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Mesaj gönderilemedi.');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  static Future<String> uploadFile(List<int> bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'dosya': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await ApiService.dio.post('/messages/upload', data: formData);
      return response.data['url'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Dosya yüklenemedi.');
    } catch (e) {
      throw Exception('Dosya yükleme hatası: $e');
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final response = await ApiService.dio.get('/messages/okunmamis-sohbet');
      return response.data['sayi'] ?? 0;
    } catch (_) {
      return 0; // Sessizce fail
    }
  }
}
