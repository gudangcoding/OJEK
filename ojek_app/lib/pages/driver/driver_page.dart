import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../driver_order/bloc/driver_order_bloc.dart';
import '../../services/api.dart';
import '../../config.dart';
import 'package:geolocator/geolocator.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> with TickerProviderStateMixin {
  int _bottomIndex = 0;
  late TabController _homeTabs;
  List<dynamic> _available = [];
  dynamic _activeOrder;
  late final ApiService _api;
  LatLng? _myLatLng;
  List<Map<String, dynamic>> _nearbyCustomers = [];
  bool _customersLoading = false;
  Timer? _customersRefreshTimer;
  DateTime? _lastCustomersRefreshAt;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _homeTabs = TabController(length: 2, vsync: this);
    _api = RepositoryProvider.of<ApiService>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverOrderBloc>().add(LoadAvailableOrders());
      _sendCurrentLocationOnce();
    });
  }

  Future<void> _loadAvailable() async {
    context.read<DriverOrderBloc>().add(LoadAvailableOrders());
  }

  Future<void> _loadNearbyCustomers() async {
    if (_api.token == null || _myLatLng == null) return;
    if (_customersLoading) return;
    setState(() {
      _customersLoading = true;
    });
    try {
      final customers = await _api.listNearbyCustomers(
        _myLatLng!.latitude,
        _myLatLng!.longitude,
        radiusKm: AppConfig.nearbyRadiusKm,
        limit: AppConfig.nearbyLimit,
      );
      setState(() {
        _nearbyCustomers = customers;
        _lastCustomersRefreshAt = DateTime.now();
      });
    } catch (_) {
      // abaikan error agar UI tetap jalan
    } finally {
      if (mounted)
        setState(() {
          _customersLoading = false;
        });
    }
  }

  void _startAutoRefresh() {
    _customersRefreshTimer?.cancel();
    _customersRefreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.nearbyCustomersRefreshSec),
      (_) {
        _loadNearbyCustomers();
      },
    );
  }

  void _stopAutoRefresh() {
    _customersRefreshTimer?.cancel();
    _customersRefreshTimer = null;
  }

  Future<void> _accept(dynamic order) async {
    context.read<DriverOrderBloc>().add(AcceptOrder(order.id));
  }

  Future<void> _reject(dynamic order) async {
    context.read<DriverOrderBloc>().add(RejectOrder(order.id));
  }

  Future<void> _finish() async {
    if (_activeOrder == null) return;
    context.read<DriverOrderBloc>().add(CompleteOrder(_activeOrder.id));
  }

  Widget _orderList() {
    return BlocConsumer<DriverOrderBloc, DriverOrderState>(
      listener: (context, state) {
        if (state is DriverOrderFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${state.message}')));
        }
        if (state is DriverOrderActive) {
          setState(() {
            _activeOrder = state.order;
          });
        }
        if (state is DriverOrdersLoaded) {
          setState(() {
            _available = state.orders;
          });
        }
      },
      builder: (context, state) {
        final list = _available;
        return RefreshIndicator(
          onRefresh: _loadAvailable,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
                child: ListTile(
                  title: Text('Order #${o.id} - ${o.distance} km'),
                  subtitle: Text('Harga Rp ${o.totalPrice}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _accept(o),
                        icon: const Icon(Icons.check, color: Colors.green),
                      ),
                      IconButton(
                        onPressed: () => _reject(o),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _activeMap() {
    final center = _activeOrder != null
        ? LatLng(_activeOrder.latPickup, _activeOrder.lonPickup)
        : const LatLng(-6.2, 106.82);
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(center: center, zoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ojek_app',
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton(
            onPressed: _finish,
            child: const Text('Selesai'),
          ),
        ),
      ],
    );
  }

  Future<void> _sendCurrentLocationOnce() async {
    if (_api.token == null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever)
          return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      await _api.updateMyLocation(
        pos.latitude,
        pos.longitude,
        statusJob: 'active',
      );
      setState(() {
        _myLatLng = LatLng(pos.latitude, pos.longitude);
      });
      _loadNearbyCustomers();
      _startAutoRefresh();
    } catch (_) {
      // Diamkan jika error, agar tidak mengganggu alur driver
    }
  }

  Widget _customersMap() {
    final center = _myLatLng ?? const LatLng(-6.2, 106.82);
    final customerMarkers = _nearbyCustomers.map((c) {
      final lat = (c['lat'] as double);
      final lng = (c['lng'] as double);
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
    final myMarker = _myLatLng == null
        ? <Marker>[]
        : [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 32),
            ),
          ];

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: center, zoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ojek_app',
              ),
              MarkerLayer(markers: [...myMarker, ...customerMarkers]),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Card(
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadNearbyCustomers,
                tooltip: 'Refresh pelanggan',
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _lastCustomersRefreshAt == null
                      ? 'Terakhir: -'
                      : 'Terakhir: ${_formatTime(_lastCustomersRefreshAt!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          if (_customersLoading)
            const Positioned(
              right: 8,
              top: 8,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final t = dt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver')),
      body: _bottomIndex == 0
          ? (_activeOrder == null
                ? Column(
                    children: [
                      // Map customers online di sekitar driver
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _customersMap(),
                      ),
                      TabBar(
                        tabs: const [
                          Tab(text: 'Order'),
                          Tab(text: 'History'),
                        ],
                        controller: _homeTabs,
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _homeTabs,
                          children: [
                            _orderList(),
                            const Center(
                              child: Text('History belum diimplementasi'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _activeMap())
          : const Center(child: Text('Profil')), // placeholder
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _homeTabs.dispose();
    super.dispose();
  }
}
