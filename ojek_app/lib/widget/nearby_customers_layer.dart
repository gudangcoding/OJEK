import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class NearbyCustomersLayer extends StatelessWidget {
  final List<Map<String, dynamic>> customers;

  const NearbyCustomersLayer({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    final markers = customers.map((c) {
      final lat = (c['lat'] as num).toDouble();
      final lng = (c['lng'] as num).toDouble();
      final online = c['status_online'] == true;
      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: Icon(
          Icons.person_pin_circle,
          color: online ? Colors.blue : Colors.grey,
          size: 32,
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}
