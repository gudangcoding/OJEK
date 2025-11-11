import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../models/Order.dart';
import '../../widget/route_map.dart';
import '../../services/broadcast.dart';
import '../../services/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CustomerRoutePage extends StatefulWidget {
  final OrderModel order;
  const CustomerRoutePage({super.key, required this.order});

  @override
  State<CustomerRoutePage> createState() => _CustomerRoutePageState();
}

class _CustomerRoutePageState extends State<CustomerRoutePage> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  double? _durationMin;
  bool _loading = true;
  final BroadcastService _rt = BroadcastService();
  late final ApiService _api;
  LatLng? _driverLatLng;
  bool _followDriver = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _api = RepositoryProvider.of<ApiService>(context);
      _subscribeLocation();
    });
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    setState(() => _loading = true);
    try {
      final pLon = widget.order.lonPickup;
      final pLat = widget.order.latPickup;
      final dLon = widget.order.lonDropoff;
      final dLat = widget.order.latDropoff;
      final primary = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$pLon,$pLat;$dLon,$dLat?overview=full&geometries=geojson',
      );
      var res = await http.get(primary, headers: {'User-Agent': 'ojek_app'});
      if (res.statusCode != 200) {
        final fallback = Uri.parse(
          'https://routing.openstreetmap.de/routed-car/route/v1/driving/$pLon,$pLat;$dLon,$dLat?overview=full&geometries=geojson',
        );
        res = await http.get(fallback, headers: {'User-Agent': 'ojek_app'});
      }
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final route0 = routes[0];
          final List coords = route0['geometry']['coordinates'];
          final double? meters = (route0['distance'] as num?)?.toDouble();
          final double? seconds = (route0['duration'] as num?)?.toDouble();
          setState(() {
            _routePoints = [
              for (final c in coords)
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            ];
            _distanceKm = meters == null ? null : meters / 1000.0;
            _durationMin = seconds == null ? null : seconds / 60.0;
            _loading = false;
          });
          try {
            final bounds = LatLngBounds(
              LatLng(_routePoints.map((e) => e.latitude).reduce((a, b) => a < b ? a : b),
                  _routePoints.map((e) => e.longitude).reduce((a, b) => a < b ? a : b)),
              LatLng(_routePoints.map((e) => e.latitude).reduce((a, b) => a > b ? a : b),
                  _routePoints.map((e) => e.longitude).reduce((a, b) => a > b ? a : b)),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _mapController.fitBounds(
                  bounds,
                  options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
                );
              } catch (_) {}
            });
          } catch (_) {}
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribeLocation() async {
    try {
      await _rt.subscribeOrderLocation(
        widget.order.id,
        (evt) {
          try {
            final raw = evt['data'];
            final payload = raw is String && raw.isNotEmpty
                ? (jsonDecode(raw) as Map<String, dynamic>)
                : (raw as Map<String, dynamic>? ?? {});
            final lat = (payload['lat'] as num?)?.toDouble();
            final lng = (payload['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              setState(() {
                _driverLatLng = LatLng(lat, lng);
              });
              if (_followDriver) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    _mapController.move(LatLng(lat, lng), 18);
                  } catch (_) {}
                });
              }
            }
          } catch (_) {}
        },
        token: _api.token,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.order.latPickup, widget.order.lonPickup);
    final dropoff = LatLng(widget.order.latDropoff, widget.order.lonDropoff);
    final center = pickup;
    return Scaffold(
      appBar: AppBar(title: const Text('Rute Perjalanan')), 
      body: Stack(
        children: [
          RouteMap(
            mapController: _mapController,
            center: center,
            zoom: 16,
            pickup: pickup,
            dropoff: dropoff,
            routePoints: _routePoints,
            extraLayers: [
              if (_driverLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup: ${widget.order.pickupAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Dropoff: ${widget.order.dropoffAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Divider(),
                    if (_distanceKm != null)
                      Text('Estimasi jarak: ${_distanceKm!.toStringAsFixed(2)} km'),
                    if (_durationMin != null)
                      Text('Estimasi waktu: ${_durationMin!.toStringAsFixed(0)} menit'),
                    if (widget.order.totalPrice > 0)
                      Text('Harga: Rp ${widget.order.totalPrice.round()}'),
                    const SizedBox(height: 6),
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 16),
                        const SizedBox(width: 6),
                        const Text('Ikuti posisi driver'),
                        const Spacer(),
                        Switch(
                          value: _followDriver,
                          onChanged: (v) => setState(() => _followDriver = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}