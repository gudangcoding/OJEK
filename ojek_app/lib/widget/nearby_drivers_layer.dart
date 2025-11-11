import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class NearbyDriversLayer extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;

  const NearbyDriversLayer({super.key, required this.drivers});

  @override
  Widget build(BuildContext context) {
    final markers = drivers.map((d) {
      final lat = (d['lat'] as num).toDouble();
      final lng = (d['lng'] as num).toDouble();
      final online = d['status_online'] == true;
      return Marker(
        point: LatLng(lat, lng),
        width: 36,
        height: 36,
        child: Icon(
          Icons.motorcycle,
          color: online ? Colors.green : Colors.grey,
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}
