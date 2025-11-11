import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class NominatimService {
  static Future<List<Map<String, dynamic>>> searchPlace(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/geocode/search?q=$query',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'ojek_app'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map(
            (place) => {
              'display_name': place['display_name'],
              'lat': place['lat'],
              'lon': place['lon'],
            },
          )
          .toList();
    } else {
      throw Exception('Gagal memuat data lokasi');
    }
  }

  static Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/geocode/reverse?lat=$lat&lon=$lon',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'ojek_app'},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final name = data['display_name'];
      return name is String ? name : null;
    } else {
      // Jangan lempar exception agar UI drag tidak terganggu
      return null;
    }
  }
}
