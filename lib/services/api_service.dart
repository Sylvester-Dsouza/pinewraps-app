import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../models/customer_details.dart';
import '../models/address.dart';
import '../models/order.dart';
import '../models/reward.dart';

class ApiService {
  static final String _baseUrl = EnvironmentConfig.apiBaseUrl;
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _cachedToken;
  DateTime? _tokenExpiry;
  final Map<String, dynamic> _cache = {};
  final Duration _cacheExpiry = const Duration(minutes: 5);
  List<Address>? _addressesCache;
  DateTime? _addressesCacheTime;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      listFormat: ListFormat.multiCompatible,
    ));

    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: print,
        retries: 2,
        retryDelays: const [
          Duration(milliseconds: 500),
          Duration(seconds: 1),
        ],
        retryableExtraStatuses: {408, 429},
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.method == 'GET') {
          final cacheKey = '${options.method}:${options.path}';
          final cachedData = _cache[cacheKey];
          if (cachedData != null) {
            final cacheTime = cachedData['time'] as DateTime;
            if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: cachedData['data'],
                  statusCode: 200,
                ),
              );
            }
            _cache.remove(cacheKey);
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.requestOptions.method == 'GET' && response.statusCode == 200) {
          final cacheKey = '${response.requestOptions.method}:${response.requestOptions.path}';
          _cache[cacheKey] = {
            'data': response.data,
            'time': DateTime.now(),
          };
        }
        return handler.next(response);
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getCachedFirebaseToken();
        print('Token available: ${token != null}');
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        print('Status code: ${error.response?.statusCode}');
        if (error.response?.statusCode == 401) {
          _clearTokenCache();
          firebase_auth.FirebaseAuth.instance.signOut();
        }
        return handler.next(error);
      },
    ));

    if (EnvironmentConfig.isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('API Log: $obj'),
      ));
    }
  }

  Future<String?> _getCachedFirebaseToken() async {
    try {
      if (_cachedToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        print('Using cached Firebase token');
        return _cachedToken;
      }

      print('Getting new Firebase token...');
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No Firebase user found');
        return null;
      }
      
      _cachedToken = await user.getIdToken();
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
      print('New Firebase token obtained');
      return _cachedToken;
    } catch (e) {
      print('Error getting Firebase token: $e');
      return null;
    }
  }

  void _clearTokenCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    final token = await _getCachedFirebaseToken();
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

  Future<Map<String, dynamic>> login({
    required String email,
  }) async {
    final token = await _getCachedFirebaseToken();
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

  Future<Map<String, dynamic>> socialAuth({
    required String provider,
    required String email,
    required String firstName,
    String? lastName,
    String? imageUrl,
    String? phone,
  }) async {
    final token = await _getCachedFirebaseToken();
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

  Future<CustomerDetails> getCustomerDetails() async {
    final response = await _dio.get('/customers/profile');
    
    if (response.statusCode == 200) {
      return CustomerDetails.fromJson(response.data['data']);
    } else {
      throw ApiException(
        message: 'Failed to get customer details',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<CustomerDetails> getCurrentCustomer() async {
    return getCustomerDetails();
  }

  Future<CustomerDetails> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final response = await _dio.patch(
      '/customers/profile',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
      },
    );

    if (response.statusCode == 200) {
      return CustomerDetails.fromJson(response.data['data']);
    } else {
      throw ApiException(
        message: 'Failed to update profile',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<List<Address>> getSavedAddresses() async {
    if (_addressesCache != null && _addressesCacheTime != null) {
      final cacheDuration = DateTime.now().difference(_addressesCacheTime!);
      if (cacheDuration < const Duration(minutes: 5)) {
        return _addressesCache!;
      }
    }

    final response = await _dio.get('/customers/addresses');
    
    if (response.statusCode == 200) {
      final List<dynamic> addressesJson = response.data['data'];
      _addressesCache = addressesJson.map((json) => Address.fromJson(json)).toList();
      _addressesCacheTime = DateTime.now();
      return _addressesCache!;
    } else {
      throw ApiException(
        message: 'Failed to get saved addresses',
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  Future<Map<String, dynamic>> getCurrentUserMap() async {
    final customerDetails = await getCustomerDetails();
    return customerDetails.toJson();
  }

  Future<List<Address>> getAddresses() async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      // Force a fresh fetch by clearing cache
      _addressesCache = null;
      _addressesCacheTime = null;

      final response = await _dio.get(
        '/customers/addresses',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Get addresses response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          final List<dynamic> addressesJson = responseData['data'];
          _addressesCache = addressesJson.map((json) => Address.fromJson(json)).toList();
          _addressesCacheTime = DateTime.now();
          return _addressesCache!;
        }
      }

      throw ApiException(
        message: 'Failed to fetch addresses',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching addresses: $e');
      rethrow;
    }
  }

  Future<Address> addAddress(Address address) async {
    final token = await _getCachedFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    final data = address.toJson();
    print('Adding address with data: $data');

    try {
      final response = await _dio.post(
        '/customers/addresses',
        data: data,
      );

      print('Response status: ${response.statusCode}');

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] != true || !responseData.containsKey('data')) {
          throw ApiException(
            message: responseData['error']?['message'] ?? 'Invalid response format from server',
            statusCode: response.statusCode ?? 500,
          );
        }
        // Clear the addresses cache after successful addition
        _addressesCache = null;
        return Address.fromJson(responseData['data']);
      }

      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Failed to add address',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while adding address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to add address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  Future<Address> updateAddress(String addressId, Address address) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final data = address.toJson();
      print('Updating address with data: $data');

      final response = await _dio.put(
        '/customers/addresses/$addressId',
        data: data,
      );
      
      // Clear both the addresses cache and the general cache
      _addressesCache = null;
      _addressesCacheTime = null;
      final cacheKey = 'GET:/customers/addresses';
      _cache.remove(cacheKey);
      
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          return Address.fromJson(responseData['data']);
        }
      }

      throw ApiException(
        message: 'Failed to update address',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.delete(
        '/customers/addresses/$addressId',
      );

      if (response.statusCode != 200 || response.data?['success'] != true) {
        throw ApiException(
          message: response.data?['error']?['message'] ?? 'Failed to delete address',
          statusCode: response.statusCode ?? 500,
        );
      }
      
      // Clear the addresses cache after successful deletion
      _addressesCache = null;
    } on DioException catch (e) {
      print('DioException while deleting address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to delete address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  Future<Address> setDefaultAddress(String addressId) async {
    final token = await _getCachedFirebaseToken();
    if (token == null) throw Exception('No authentication token');

    try {
      final response = await _dio.patch(
        '/customers/addresses/$addressId/default',
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] != true || !responseData.containsKey('data')) {
          throw ApiException(
            message: responseData['error']?['message'] ?? 'Invalid response format from server',
            statusCode: response.statusCode ?? 500,
          );
        }
        
        // Clear the addresses cache after updating default
        _addressesCache = null;
        
        return Address.fromJson(responseData['data']);
      }

      throw ApiException(
        message: response.data?['error']?['message'] ?? 'Failed to set default address',
        statusCode: response.statusCode ?? 500,
      );
    } on DioException catch (e) {
      print('DioException while setting default address: $e');
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Failed to set default address',
        statusCode: e.response?.statusCode ?? 500,
      );
    } catch (e) {
      print('Error setting default address: $e');
      rethrow;
    }
  }

  Future<OrdersResponse> getOrders({
    OrderStatus? status,
    required int page,
    required int limit,
  }) async {
    try {
      print('Fetching orders - page: $page, limit: $limit, status: ${status?.name}');
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status != OrderStatus.all) 'status': status.name,
      };

      print('Request URL: $_baseUrl/orders');
      print('Query params: $queryParams');

      final response = await _dio.get(
        '/orders',
        queryParameters: queryParams,
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return OrdersResponse.fromJson(response.data);
      }
      throw ApiException(
        message: 'Failed to fetch orders',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching orders: $e');
      throw ApiException(
        message: 'Failed to fetch orders: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.get('/orders/$orderId');

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return Order.fromJson(data);
      }
      throw ApiException(
        message: 'Failed to fetch order',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error fetching order: $e');
      rethrow;
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final token = await _getCachedFirebaseToken();
      if (token == null) throw Exception('No authentication token');

      final response = await _dio.delete('/orders/$orderId');

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to cancel order',
          statusCode: response.statusCode ?? 500,
        );
      }
    } catch (e) {
      print('Error canceling order: $e');
      rethrow;
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

  Future<Response> sendRequest(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await _getCachedFirebaseToken() : null;
      
      final options = Options(
        method: method,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        validateStatus: (status) {
          // Accept 302 status for payment redirects
          return status != null && (status < 400 || status == 302);
        },
      );

      final response = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response;
    } on DioException catch (e) {
      print('API Error: ${e.message}');
      print('Status code: ${e.response?.statusCode}');
      
      if (e.response?.statusCode == 401) {
        _clearTokenCache();
      }
      
      throw ApiException(
        message: e.response?.data?['error']?['message'] ?? 'Request failed',
        statusCode: e.response?.statusCode ?? 500,
      );
    }
  }

  // Rewards API endpoints
  Future<CustomerReward?> getCustomerRewards() async {
    try {
      final response = await _dio.get('$_baseUrl/rewards');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CustomerReward.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching customer rewards: $e');
      return null;
    }
  }

  Future<bool> redeemPoints(int points) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/rewards/redeem',
        data: {'points': points},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error redeeming points: $e');
      return false;
    }
  }

  Future<Response> validateCoupon(String code) async {
    try {
      final response = await _dio.post('/coupons/validate', data: {'code': code});
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['success'] == true) {
          return response;
        }
      }
      
      throw ApiException(
        message: 'Invalid coupon code',
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      print('Error validating coupon: $e');
      rethrow;
    }
  }
}

class Product {
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

class OrdersResponse {
  final List<Order> results;
  final Pagination pagination;

  OrdersResponse({
    required this.results,
    required this.pagination,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return OrdersResponse(
      results: (data['results'] as List<dynamic>)
          .map((item) => Order.fromJson(item))
          .toList(),
      pagination: Pagination.fromJson(data['pagination']),
    );
  }
}

class Pagination {
  final int total;
  final int page;
  final int limit;

  Pagination({
    required this.total,
    required this.page,
    required this.limit,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}
