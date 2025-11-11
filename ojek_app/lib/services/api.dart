import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/User.dart';
import '../models/Order.dart';

class ApiService {
  String? _token;
  String? get token => _token;
  String? _role;
  String? get role => _role;
  int? _userId;
  int? get userId => _userId;

  // Menghapus token lokal tanpa memanggil backend
  void clearToken() {
    _token = null;
    _role = null;
  }

  // Menyetel token/role dari storage saat startup
  void setAuth(String token, {String? role}) {
    _token = token;
    if (role != null) _role = role;
  }

  void setRole(String role) {
    _role = role;
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<(UserModel, String)> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.body}');
    }
    final j = jsonDecode(res.body);
    final user = UserModel.fromJson(j['user']);
    final token = j['token'] as String;
    _token = token;
    _role = user.role;
    _userId = user.id;
    return (user, token);
  }

  Future<UserModel> register(String name, String email, String password, String role) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/register'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'role': role}),
    );
    if (res.statusCode != 201) throw Exception('Register failed: ${res.body}');
    final j = jsonDecode(res.body);
    final user = UserModel.fromJson(j['user']);
    final token = j['token'];
    _token = token;
    _role = role;
    _userId = user.id;
    return user;
  }

  Future<void> logout() async {
    final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/logout'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Logout failed');
    _token = null;
  }

  Future<List<OrderModel>> listOrders() async {
    final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/orders'), headers: _headers());
    if (res.statusCode != 200) throw Exception('List orders failed: ${res.body}');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel> createOrder({
    required double latPickup,
    required double lonPickup,
    required String pickupAddress,
    required double latDropoff,
    required double lonDropoff,
    required String dropoffAddress,
    required double totalPrice,
    required double distance,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/orders'),
      headers: _headers(),
      body: jsonEncode({
        'lat_pickup': latPickup,
        'lon_pickup': lonPickup,
        'pickup_address': pickupAddress,
        'lat_dropoff': latDropoff,
        'lon_dropoff': lonDropoff,
        'dropoff_address': dropoffAddress,
        'total_price': totalPrice,
        'distance': distance,
      }),
    );
    if (res.statusCode != 201) throw Exception('Create order failed: ${res.body}');
    return OrderModel.fromJson(jsonDecode(res.body));
  }

  Future<void> updateDriverLocation(int orderId, double lat, double lng) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/location'),
      headers: _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode != 204) throw Exception('Update location failed: ${res.body}');
  }

  // Berikut endpoint opsional; implementasi backend bisa berbeda.
  Future<List<OrderModel>> listAvailableOrders() async {
    final orders = await listOrders();
    // Orders tanpa driver dan status pending dianggap tersedia
    return orders.where((o) => (o.driverId == null || o.driverId == 0) && o.status.toLowerCase() == 'pending').toList();
  }

  // Mengambil order aktif yang sedang dijalankan oleh driver saat ini (bila ada)
  Future<OrderModel?> getMyActiveOrder() async {
    final myId = _userId;
    if (myId == null) return null;
    final orders = await listOrders();
    // Anggap status selain 'completed' dan 'cancelled' masih aktif/berjalan
    final active = orders.where((o) {
      final s = o.status.toLowerCase();
      return o.driverId == myId && s != 'completed' && s != 'cancelled';
    }).toList();
    if (active.isEmpty) return null;
    // Ambil yang terbaru (anggap urutan dari backend sudah terbaru di depan)
    return active.first;
  }

  Future<OrderModel> acceptOrder(int orderId) async {
    final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/accept'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Accept order failed: ${res.body}');
    return OrderModel.fromJson(jsonDecode(res.body));
  }

  Future<OrderModel> rejectOrder(int orderId) async {
    final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/reject'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Reject order failed: ${res.body}');
    return OrderModel.fromJson(jsonDecode(res.body));
  }

  Future<void> completeOrder(int orderId) async {
    final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/complete'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Complete order failed: ${res.body}');
  }

  Future<OrderModel> cancelOrder(int orderId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/cancel'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Cancel order failed: ${res.body}');
    }
    return OrderModel.fromJson(jsonDecode(res.body));
  }

  Future<List<Map<String, dynamic>>> listNearbyDrivers(double lat, double lng, {double radiusKm = 5, int limit = 20}) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/drivers/nearby?lat=$lat&lng=$lng&radius=$radiusKm&limit=$limit');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('List nearby drivers failed: ${res.body}');
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => {
      'id': e['id'],
      'name': e['name'],
      'lat': (e['lat'] as num).toDouble(),
      'lng': (e['lng'] as num).toDouble(),
      'distance_km': ((e['distance_km'] ?? 0) as num).toDouble(),
      'status_online': e['status_online'] ?? (e['status_job'] == 'active'),
      'status_job': e['status_job'],
      'phone': e['phone'],
      'avatar_url': e['avatar_url'],
      'vehicle_plate': e['vehicle_plate'],
      'vehicle_model': e['vehicle_model'],
      'rating': e['rating'] == null ? null : ((e['rating'] as num).toDouble()),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> listNearbyCustomers(double lat, double lng, {double radiusKm = 5, int limit = 20}) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/customers/nearby?lat=$lat&lng=$lng&radius=$radiusKm&limit=$limit');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('List nearby customers failed: ${res.body}');
    }
    final j = jsonDecode(res.body);
    // Backend returns { data: [...], meta: {...} }
    final data = (j is List) ? j : (j['data'] as List);
    return data.map((e) => {
      'id': e['id'],
      'name': e['name'],
      'lat': (e['lat'] as num).toDouble(),
      'lng': (e['lng'] as num).toDouble(),
      'distance_km': ((e['distance_km'] ?? 0) as num).toDouble(),
      'status_online': e['status_online'] ?? (e['status_job'] == 'active'),
      'status_job': e['status_job'],
      'phone': e['phone'],
      'avatar_url': e['avatar_url'],
      'vehicle_plate': e['vehicle_plate'],
      'vehicle_model': e['vehicle_model'],
      'rating': e['rating'] == null ? null : ((e['rating'] as num).toDouble()),
    }).toList();
  }

  Future<void> updateMyLocation(double lat, double lng, {String? statusJob}) async {
    final body = {
      'lat': lat,
      'lng': lng,
      if (statusJob != null) 'status_job': statusJob,
    };
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/me/location'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 204) {
      throw Exception('Update my location failed: ${res.body}');
    }
  }

  Future<void> updateMyStatus(String statusJob) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/me/status'),
      headers: _headers(),
      body: jsonEncode({'status_job': statusJob}),
    );
    if (res.statusCode != 200) {
      throw Exception('Update my status failed: ${res.body}');
    }
    try {
      final j = jsonDecode(res.body);
      // Optionally keep role or other fields; for now ignore
    } catch (_) {}
  }

  Future<void> updateOrderLocation(int orderId, double lat, double lng) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/orders/$orderId/location'),
      headers: _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Update order location failed: ${res.body}');
    }
  }
}