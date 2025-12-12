// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isAuthenticated = false; // ← INI YANG PENTING!
  String? _error;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated; // ← PASTIKAN INI ADA!
  String? get error => _error;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    // Auto check auth status saat provider dibuat
    checkAuthStatus();
  }

  // ========== CHECK AUTH STATUS ==========
  Future<void> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUser = prefs.getString('user_data');

      if (storedToken != null && storedUser != null) {
        _token = storedToken;
        _user = json.decode(storedUser);
        _isAuthenticated = true;

        try {
          final api = ApiService();
          // Anda mungkin perlu set token di ApiService dulu
          // api.setToken(_token!);
          // await api.get('auth/check');
        } catch (e) {
          print('Token validation failed: $e');
          // Token mungkin expired, lakukan logout
          await logout();
        }
      } else {
        _isAuthenticated = false;
        _token = null;
        _user = null;
      }
    } catch (e) {
      print('Error checking auth status: $e');
      _isAuthenticated = false;
    } finally {
      notifyListeners();
    }
  }

  // ========== LOGIN ==========
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.post('auth/login', {
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        // Simpan data
        _token = response['data']['token'];
        _user = response['data']['user'];
        _isAuthenticated = true; // ← SET KE TRUE!

        // Simpan ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', json.encode(_user));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    try {
      // Hapus dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Hapus SEMUA data auth
      await prefs.remove('auth_token');
      await prefs.remove('user_data');

      // Reset state
      _token = null;
      _user = null;
      _isAuthenticated = false; // ← SET KE FALSE!
      _error = null;

      print('✅ Logout successful - isAuthenticated: $_isAuthenticated');
    } catch (e) {
      print('❌ Logout error: $e');
      _error = 'Logout error: $e';
    } finally {
      notifyListeners();
    }
  }

  // ========== REGISTER ==========
  Future<bool> register(
      String name, String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.post('auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });

      if (response['success'] == true) {
        // Auto login setelah register
        return await login(email, password);
      } else {
        _error = response['message'] ?? 'Registrasi gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
