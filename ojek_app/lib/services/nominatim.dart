import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimService {
  static Future<List<Map<String, dynamic>>> searchPlace(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=10',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'flutter_app'},
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
}
