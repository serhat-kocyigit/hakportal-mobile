import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    
    final token = await _storage.read(key: 'hp_token');
    final userStr = await _storage.read(key: 'user');
    
    if (token != null && userStr != null) {
      _user = json.decode(userStr);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Node.js backendine istek
      final response = await ApiService.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final token = response.data['token'];
      final userResponse = response.data['user'];
      
      // Token ve User'ı güvenli şekilde kaydet
      await _storage.write(key: 'hp_token', value: token);
      await _storage.write(key: 'user', value: json.encode(userResponse));
      
      _user = userResponse;
      _isLoading = false;
      notifyListeners();
      return null; // Başarılı, null döner
      
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.response?.data['error'] ?? 'Giriş yapılamadı, bilgileri kontrol edin.';
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'hp_token');
    await _storage.delete(key: 'user');
    _user = null;
    notifyListeners();
  }

  /// Sunucudan güncel profil verisini çekip yerel state'i günceller
  Future<void> refreshUser() async {
    try {
      final response = await ApiService.dio.get('/auth/me');
      final freshUser = response.data as Map<String, dynamic>;
      await _storage.write(key: 'user', value: json.encode(freshUser));
      _user = freshUser;
      notifyListeners();
    } catch (_) {
      // Hata olursa mevcut durumu koru
    }
  }
}

