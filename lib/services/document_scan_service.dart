import 'package:dio/dio.dart';
import 'dart:convert';
import '../services/api_service.dart';

class DocumentScanService {
  static const String scanPath = '/analyzer/scan';

  static Future<Map<String, dynamic>> scanFile({
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'dosya': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    try {
      final response = await ApiService.dio.post(
        scanPath,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          // OCR/parse işlemi uzun sürebilir
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          // plain string
        }
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data as Map);
      }

      final body = response.data?.toString() ?? '';
      final preview = body.substring(0, body.length > 220 ? 220 : body.length);
      throw Exception('Beklenmeyen yanıt (JSON değil). Preview: $preview');
    } on DioException catch (e) {
      dynamic err = e.response?.data;
      if (err is String) {
        try {
          err = jsonDecode(err);
        } catch (_) {
          // keep string
        }
      }
      if (err is Map && err['error'] != null) {
        throw Exception(err['error'].toString());
      }

      final status = e.response?.statusCode;
      final path = e.requestOptions.path;
      final bodyStr = e.response?.data?.toString() ?? '';
      final preview = bodyStr.substring(0, bodyStr.length > 220 ? 220 : bodyStr.length);
      throw Exception('Evrak analizi yapılamadı. HTTP $status ($path) Preview: $preview');
    }
  }
}
