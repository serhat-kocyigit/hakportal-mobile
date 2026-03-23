import 'package:dio/dio.dart';
import '../services/api_service.dart';

class NotificationService {
  static Future<int> getUnreadCount() async {
    try {
      final response = await ApiService.dio.get('/notifications/count');
      return response.data['sayi'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<dynamic>> getNotifications() async {
    try {
      final response = await ApiService.dio.get('/notifications');
      if (response.data is List) {
        return response.data;
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Bildirimler yüklenemedi.');
    } catch (_) {
      throw Exception('Bir hata oluştu.');
    }
  }

  static Future<void> markAllAsRead() async {
    try {
      await ApiService.dio.put('/notifications/tumunu-oku');
    } catch (_) {
      // sessizce devam
    }
  }

  static Future<void> markAsRead(String notifId) async {
    try {
       await ApiService.dio.put('/notifications/$notifId/oku');
    } catch (_) {
    }
  }
}
