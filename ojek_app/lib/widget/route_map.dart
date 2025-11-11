import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';

class RouteMap extends StatelessWidget {
  final MapController? mapController;
  final LatLng center;
  final double zoom;
  final LatLng? pickup;
  final LatLng? dropoff;
  final List<LatLng> routePoints;
  final List<Widget> extraLayers;
  final VoidCallback? onMapReady;
  final void Function(LatLng)? onPickupDragged;
  final void Function(LatLng)? onDropoffDragged;
  final bool enablePickupDrag;
  final bool enableDropoffDrag;

  const RouteMap({
    super.key,
    this.mapController,
    required this.center,
    this.zoom = 12,
    this.pickup,
    this.dropoff,
    this.routePoints = const [],
    this.extraLayers = const [],
    this.onMapReady,
    this.onPickupDragged,
    this.onDropoffDragged,
    this.enablePickupDrag = true,
    this.enableDropoffDrag = true,
  });

  @override
  Widget build(BuildContext context) {
    final pickupMarker = pickup == null
        ? <Marker>[]
        : [
            Marker(
              point: pickup!,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 32,
              ),
            ),
          ];
    final dropoffMarker = dropoff == null
        ? <Marker>[]
        : [
            Marker(
              point: dropoff!,
              width: 40,
              height: 40,
              child: const Icon(Icons.flag, color: Colors.red, size: 32),
            ),
          ];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        // Gunakan initial* sesuai API flutter_map v6 agar interaksi zoom/pinch bekerja baik
        initialCenter: center,
        initialZoom: zoom,
        onMapReady: onMapReady,
        // Pastikan semua interaksi aktif (pan, pinch zoom, scroll zoom)
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ojek_app',
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: routePoints, color: Colors.blue, strokeWidth: 4),
            ],
          ),
        MarkerLayer(markers: [...pickupMarker, ...dropoffMarker]),
        ...extraLayers,
        // Letakkan drag markers di akhir agar gesture tidak diintersep layer lain
        DragMarkers(
          markers: [
            if (pickup != null)
              DragMarker(
                key: GlobalKey<DragMarkerWidgetState>(),
                point: pickup!,
                size: const Size.square(40),
                offset: const Offset(0, -16),
                builder: (_, __, isDragging) => Icon(
                  isDragging ? Icons.edit_location : Icons.location_on,
                  color: Colors.green,
                  size: isDragging ? 48 : 32,
                ),
                // Gunakan long press untuk mulai drag agar tidak mengganggu pinch/zoom
                useLongPress: true,
                onDragEnd: (details, p) {
                  if (onPickupDragged != null) onPickupDragged!(p);
                },
              ),
            if (dropoff != null)
              DragMarker(
                key: GlobalKey<DragMarkerWidgetState>(),
                point: dropoff!,
                size: const Size.square(40),
                offset: const Offset(0, -16),
                builder: (_, __, isDragging) => Icon(
                  isDragging ? Icons.edit_location_alt : Icons.flag,
                  color: Colors.red,
                  size: isDragging ? 48 : 32,
                ),
                useLongPress: true,
                onDragEnd: (details, p) {
                  if (onDropoffDragged != null) onDropoffDragged!(p);
                },
              ),
          ],
        ),
      ],
    );
  }
}
