import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_details.dart';
import '../models/address.dart';
import '../models/order.dart';

class ApiService {
  // Updated base URL to match the correct API endpoint
  static const String _baseUrl = 'http://192.168.1.2:3001/api';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getFirebaseToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized access
          firebase_auth.FirebaseAuth.instance.signOut();
        }
        return handler.next(error);
      },
    ));
  }

  // Get Firebase token
  Future<String?> _getFirebaseToken() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      print('Error getting Firebase token: $e');
      return null;
    }
  }

  // Register with email/password
  Future<Map<String, dynamic>> register({
    required String email,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.post(
      '/customers/auth/register',
      data: {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
      },
    );

    if (response.statusCode == 201) {
      return response.data['data'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Login with email/password
  Future<Map<String, dynamic>> login({
    required String email,
  }) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.post(
      '/customers/auth/login',
      data: {
        'email': email,
      },
    );

    if (response.statusCode == 200) {
      return response.data['data'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Social authentication
  Future<Map<String, dynamic>> socialAuth({
    required String provider,
    required String email,
    required String firstName,
    String? lastName,
    String? imageUrl,
    String? phone,
  }) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    print('Attempting social auth with token: ${token.substring(0, 10)}...');

    final response = await _dio.post(
      '/customers/auth/social',
      data: {
        'token': token,
        'provider': provider,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'imageUrl': imageUrl,
        'phone': phone,
      },
    );

    print('Social auth response: ${response.statusCode} - ${response.data}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data['data'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.get(
      '/customers/auth/me',
    );

    if (response.statusCode == 200) {
      return response.data['data']['customer'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dateOfBirth,
  }) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.put(
      '/customers/auth/profile',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      },
    );

    if (response.statusCode == 200) {
      return response.data['data'];
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Get products (public endpoint)
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await _dio.get('/products');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return data['data'] ?? [];
      } else {
        throw ApiException(
          message: 'Failed to process request',
          statusCode: response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: 500,
      );
    }
  }

  // Get addresses
  Future<List<Address>> getAddresses() async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.get(
      '/customers/addresses',
    );

    if (response.statusCode == 200) {
      final List<dynamic> addressesJson = response.data['data'];
      return addressesJson.map((json) => Address.fromJson(json)).toList();
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Add address
  Future<Address> addAddress(Address address) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.post(
      '/customers/addresses',
      data: address.toJson(),
    );

    if (response.statusCode == 201) {
      return Address.fromJson(response.data['data']);
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Update address
  Future<Address> updateAddress(String addressId, Address address) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.put(
      '/customers/addresses/$addressId',
      data: address.toJson(),
    );

    if (response.statusCode == 200) {
      return Address.fromJson(response.data['data']);
    } else {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Delete address
  Future<void> deleteAddress(String addressId) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.delete(
      '/customers/addresses/$addressId',
    );

    if (response.statusCode != 200) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  // Set default address
  Future<void> setDefaultAddress(String addressId) async {
    final token = await _getFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final response = await _dio.put(
      '/customers/addresses/$addressId/default',
    );

    if (response.statusCode != 200) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<List<Order>> getOrders({OrderStatus? status}) async {
    try {
      final token = await _getFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final queryParams = status != null && status != OrderStatus.all
          ? {'status': status.name}
          : null;

      final response = await _dio.get(
        '/orders',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['orders'] ?? [];
        return data.map((json) => Order.fromJson(json)).toList();
      }
      throw ApiException(
        message: 'Failed to process request',
        statusCode: 500,
      );
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: 500,
      );
    }
  }

  Future<Order> getOrderDetails(String orderId) async {
    try {
      final token = await _getFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.get(
        '/orders/$orderId',
      );
      
      if (response.statusCode == 200) {
        return Order.fromJson(response.data['order']);
      }
      throw ApiException(
        message: 'Failed to process request',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: 500,
      );
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final token = await _getFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.patch(
        '/orders/$orderId/cancel',
      );
      
      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to process request',
          statusCode: response.statusCode ?? 500,
        );
      }
    } on DioException catch (e) {
      throw ApiException(
        message: 'Failed to process request',
        statusCode: 500,
      );
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

class Product {
  // Assuming Product class has a fromJson constructor
  Product.fromJson(Map<String, dynamic> json);
}

class ApiError {
  final String message;
  final int statusCode;

  ApiError({required this.message, required this.statusCode});
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException({
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}
