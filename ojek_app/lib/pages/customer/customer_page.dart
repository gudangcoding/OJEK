import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config.dart';
import '../../services/api.dart';
import '../../services/realtime.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../customer_order/bloc/customer_order_bloc.dart';
import '../../widget/form_input.dart';
import '../../widget/location_search_field.dart' as reusable;
import '../../widget/nearby_drivers_widget.dart';
import 'package:geolocator/geolocator.dart';

// Wrapper untuk menggunakan reusable LocationInput dengan API yang konsisten
class LocationSearchField extends StatefulWidget {
  final String label;
  final void Function(String)? onTextChanged;
  final void Function(LatLng)? onSelectedLatLng;
  final void Function(String)? onSelectedAddress;

  const LocationSearchField({
    Key? key,
    required this.label,
    this.onTextChanged,
    this.onSelectedLatLng,
    this.onSelectedAddress,
  }) : super(key: key);

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (widget.onTextChanged != null) {
        widget.onTextChanged!(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return reusable.LocationInput(
      controller: _controller,
      label: widget.label,
      onSelected: (suggestion) {
        final lat = double.tryParse('${suggestion['lat']}');
        final lon = double.tryParse('${suggestion['lon']}');
        final name = suggestion['display_name'] ?? '';
        _controller.text = name;
        if (lat != null && lon != null && widget.onSelectedLatLng != null) {
          widget.onSelectedLatLng!(LatLng(lat, lon));
        }
        if (widget.onSelectedAddress != null) {
          widget.onSelectedAddress!(name);
        }
      },
    );
  }
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> with TickerProviderStateMixin {
  int _bottomIndex = 0;
  late TabController _homeTabs;
  late final ApiService _api;
  final RealtimeService _rt = RealtimeService();

  final MapController _mapController = MapController();
  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupText = '';
  String _dropoffText = '';
  double? _distanceKm;
  double? _price;
  bool _bookingLoading = false;
  List<dynamic> _history = [];
  List<LatLng> _routePoints = [];
  bool _orderPlaced = false;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _nearbyRequested = false;

  @override
  void initState() {
    super.initState();
    _homeTabs = TabController(length: 2, vsync: this);
    _api = RepositoryProvider.of<ApiService>(context);
    // Kirim lokasi user ke backend saat app dibuka (jika sudah login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendCurrentLocationOnce();
    });
  }

  @override
  void dispose() {
    _homeTabs.dispose();
    super.dispose();
  }

  double _haversine(LatLng a, LatLng b) {
    const R = 6371.0; // km
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) * math.cos(_deg2rad(b.latitude)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  void _recalc() {
    if (_pickup != null && _dropoff != null) {
      _distanceKm = _haversine(_pickup!, _dropoff!);
      _price = AppConfig.baseFare + AppConfig.perKmRate * (_distanceKm ?? 0);
      _fetchRoutePolyline();
      setState(() {});
    }
  }

  Future<void> _updateNearbyDrivers(LatLng center) async {
    if (_api.token == null) return; // membutuhkan auth Sanctum
    try {
      final data = await _api.listNearbyDrivers(
        center.latitude,
        center.longitude,
        radiusKm: AppConfig.nearbyRadiusKm,
        limit: AppConfig.nearbyLimit,
      );
      if (!mounted) return;
      setState(() {
        _nearbyDrivers = data;
      });
    } catch (_) {
      // Abaikan error fetch untuk sementara
    }
  }

  Future<void> _sendCurrentLocationOnce() async {
    if (_api.token == null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      await _api.updateMyLocation(pos.latitude, pos.longitude, statusJob: 'active');
    } catch (_) {
      // Abaikan error agar UI tidak terganggu
    }
  }

  Future<void> _fetchRoutePolyline() async {
    if (_pickup == null || _dropoff == null) return;
    try {
      // Coba OSRM official
      final primary = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/${_pickup!.longitude},${_pickup!.latitude};${_dropoff!.longitude},${_dropoff!.latitude}'
        '?overview=full&geometries=geojson',
      );
      var res = await http.get(primary, headers: {'User-Agent': 'ojek_app'});
      if (res.statusCode != 200) {
        // Fallback ke OSRM OSM (CORS-friendly)
        final fallback = Uri.parse(
          'https://routing.openstreetmap.de/routed-car/route/v1/driving'
          '/${_pickup!.longitude},${_pickup!.latitude};${_dropoff!.longitude},${_dropoff!.latitude}'
          '?overview=full&geometries=geojson',
        );
        res = await http.get(fallback, headers: {'User-Agent': 'ojek_app'});
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final List coords = routes[0]['geometry']['coordinates'];
          _routePoints = [
            for (final c in coords) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())
          ];
          // Sesuaikan tampilan peta agar polyline terlihat
          double minLat = _routePoints.first.latitude;
          double maxLat = _routePoints.first.latitude;
          double minLon = _routePoints.first.longitude;
          double maxLon = _routePoints.first.longitude;
          for (final p in _routePoints) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLon) minLon = p.longitude;
            if (p.longitude > maxLon) maxLon = p.longitude;
          }
          final bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
          _mapController.fitBounds(bounds, options: const FitBoundsOptions(padding: EdgeInsets.all(40)));
          setState(() {});
        }
      }
    } catch (_) {
      // Abaikan error routing untuk sementara (mis. rate limit)
    }
  }

  Future<void> _book() async {
    if (_pickup == null || _dropoff == null || _distanceKm == null || _price == null) return;
    context.read<CustomerOrderBloc>().add(BookOrder(
      latPickup: _pickup!.latitude,
      lonPickup: _pickup!.longitude,
      pickupAddress: _pickupText,
      latDropoff: _dropoff!.latitude,
      lonDropoff: _dropoff!.longitude,
      dropoffAddress: _dropoffText,
      totalPrice: _price!,
      distance: _distanceKm!,
    ));
  }

  Widget _orderTab() {
    final center = _pickup ?? const LatLng(-6.200000, 106.816666);
    if (!_orderPlaced && _nearbyDrivers.isEmpty && !_nearbyRequested) {
      _nearbyRequested = true;
      // Fetch async tanpa mengganggu build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateNearbyDrivers(center);
      });
    }
    return Column(
      children: [
        Expanded(
          child: _orderPlaced
              ? FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(center: center, zoom: 12),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ojek_app'),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 4),
                      ]),
                    MarkerLayer(markers: [
                      if (_pickup != null)
                        Marker(point: _pickup!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green)),
                      if (_dropoff != null)
                        Marker(point: _dropoff!, width: 40, height: 40, child: const Icon(Icons.flag, color: Colors.red)),
                    ]),
                  ],
                )
              : NearbyDriversWidget(customerLocation: center, drivers: _nearbyDrivers),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationSearchField(
                label: 'Pickup',
                onTextChanged: (v) => _pickupText = v,
                onSelectedLatLng: (p) {
                  _pickup = p;
                  _mapController.move(p, 14);
                  _nearbyRequested = true;
                  _updateNearbyDrivers(p);
                  _recalc();
                  setState(() {});
                },
                onSelectedAddress: (addr) => _pickupText = addr,
              ),
              const SizedBox(height: 8),
              LocationSearchField(
                label: 'Dropoff',
                onTextChanged: (v) => _dropoffText = v,
                onSelectedLatLng: (p) {
                  _dropoff = p;
                  _mapController.move(p, 14);
                  _recalc();
                  setState(() {});
                },
                onSelectedAddress: (addr) => _dropoffText = addr,
              ),
              const SizedBox(height: 8),
              if (_distanceKm != null)
                Text('Estimasi jarak: ${_distanceKm!.toStringAsFixed(2)} km'),
              if (_price != null)
                Text('Estimasi harga: Rp ${_price!.round()}'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(text: 'Booking', onPressed: _bookingLoading ? null : _book),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyTab() {
    return BlocBuilder<CustomerOrderBloc, CustomerOrderState>(
      builder: (context, state) {
        List<dynamic> orders = _history;
        if (state is CustomerHistoryLoaded) {
          orders = state.orders;
        }
        return RefreshIndicator(
          onRefresh: () async {
            context.read<CustomerOrderBloc>().add(LoadHistory());
          },
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              return ListTile(
                title: Text('Order #${o.id} - ${o.status}'),
                subtitle: Text('Jarak ${o.distance} km - Rp ${o.totalPrice}'),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerOrderBloc, CustomerOrderState>(
      listener: (context, state) async {
        if (state is CustomerBookingInProgress) {
          setState(() { _bookingLoading = true; });
        } else {
          setState(() { _bookingLoading = false; });
        }
        if (state is CustomerBookingSuccess) {
          setState(() { _orderPlaced = true; });
          // Subscribe to realtime order updates
          await _rt.subscribeOrderDetail(state.order.id, (evt) {
            if (!mounted) return;
            final t = evt['type'];
            if (t == 'accepted') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order diterima driver')));
              Navigator.of(context).pop();
            } else if (t == 'rejected') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ditolak, coba lagi')));
              Navigator.of(context).pop();
            } else if (t == 'completed') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order selesai')));
              Navigator.of(context).pop();
            }
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Menunggu respon driver...')]),
            ),
          );
        }
        if (state is CustomerBookingFailure) {
          setState(() { _orderPlaced = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal booking: ${state.message}')));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: _bottomIndex == 0
            ? Column(children: [
                TabBar(tabs: const [Tab(text: 'Order'), Tab(text: 'History')], controller: _homeTabs),
                Expanded(
                  child: TabBarView(controller: _homeTabs, children: [
                    _orderTab(),
                    _historyTab(),
                  ]),
                ),
              ])
            : const Center(child: Text('Profil')), // placeholder
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomIndex,
          onTap: (i) => setState(() => _bottomIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
