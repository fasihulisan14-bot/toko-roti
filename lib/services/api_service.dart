import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:5000/api';

  // ========== PERBAIKAN: SATUKAN GET TOKEN ==========
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    // Coba beberapa key yang mungkin (fallback system)
    return prefs.getString('token') ?? // Key utama
        prefs.getString('auth_token') ?? // Key alternatif 1
        prefs.getString('authToken') ?? // Key alternatif 2
        prefs.getString('access_token'); // Key alternatif 3
  }

  // Helper untuk get headers dengan token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Handle response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // METHOD UPDATE STOCK
  Future<Map<String, dynamic>> updateProductStock(
      int productId, int stockChange) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/products/update-stock'),
            headers: headers,
            body: json
                .encode({'product_id': productId, 'stock_change': stockChange}),
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  // PUT - Edit produk
  Future<Map<String, dynamic>> updateProduct(
      int productId, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$_baseUrl/products/$productId'),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Update product failed: $e');
    }
  }

  // GET produk by ID
  Future<Map<String, dynamic>> getProductById(int productId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/products/$productId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Get product failed: $e');
    }
  }

  // CREATE produk baru
  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> productData) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/products'),
            headers: headers,
            body: json.encode(productData),
          )
          .timeout(Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Create product failed: $e');
    }
  }

  // ========== TAMBAHKAN METHOD UNTUK DEBUG ==========
  Future<void> debugToken() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    print('=== API SERVICE DEBUG ===');
    print('All SharedPreferences keys: $allKeys');

    // Cek setiap key yang mungkin berisi token
    final possibleTokenKeys = [
      'token',
      'auth_token',
      'authToken',
      'access_token'
    ];
    for (var key in possibleTokenKeys) {
      final value = prefs.getString(key);
      print('  "$key": ${value != null ? "✅ ADA" : "❌ TIDAK ADA"}');
      if (value != null && value.length > 10) {
        print('     Value: ${value.substring(0, 20)}...');
      }
    }

    // Test token yang akan digunakan
    final token = await _getToken();
    print(
        'Token yang akan digunakan: ${token != null ? "✅ $token" : "❌ NULL"}');
  }
}
