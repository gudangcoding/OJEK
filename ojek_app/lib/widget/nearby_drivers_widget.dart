// widgets/nearby_drivers_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class NearbyDriversWidget extends StatelessWidget {
  final LatLng customerLocation;
  final List<Map<String, dynamic>> drivers;
  final double zoom;

  const NearbyDriversWidget({
    super.key,
    required this.customerLocation,
    required this.drivers,
    this.zoom = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final distance = Distance();

    return Column(
      children: [
        // ====== MAP SECTION ======
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: customerLocation,
                initialZoom: zoom,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                // Marker customer
                MarkerLayer(
                  markers: [
                    Marker(
                      point: customerLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blueAccent,
                        size: 40,
                      ),
                    ),
                    // Marker semua driver
                    ...drivers.map((driver) {
                      final online = driver['status_online'] == true;
                      return Marker(
                        point: LatLng(driver['lat'], driver['lng']),
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.motorcycle,
                          color: online ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ====== LIST DRIVER SECTION ======
        Expanded(
          child: ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final driverPoint = LatLng(driver['lat'], driver['lng']);
              final km = distance.as(
                LengthUnit.Kilometer,
                customerLocation,
                driverPoint,
              );
              final plate = driver['vehicle_plate'];
              final phone = driver['phone'];
              final online = driver['status_online'] == true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: driver['avatar_url'] != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(driver['avatar_url']),
                        )
                      : CircleAvatar(
                          backgroundColor: online ? Colors.green : Colors.grey,
                          child: const Icon(
                            Icons.motorcycle,
                            color: Colors.white,
                          ),
                        ),
                  title: Text(driver['name'] ?? 'Driver'),
                  subtitle: Text(
                    [
                      '${km.toStringAsFixed(2)} km',
                      if (plate != null && plate.toString().isNotEmpty)
                        'Plat: $plate',
                      if (phone != null && phone.toString().isNotEmpty)
                        'Telp: $phone',
                    ].join(' • '),
                  ),
                  trailing: Icon(
                    Icons.circle,
                    size: 12,
                    color: online ? Colors.green : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
