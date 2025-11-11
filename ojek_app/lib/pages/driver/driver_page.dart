import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../driver_order/bloc/driver_order_bloc.dart';
import '../../services/api.dart';
import '../../services/auth_storage.dart';
import 'package:go_router/go_router.dart';
import '../../config.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../../services/broadcast.dart';
import '../../widget/route_map.dart';
import '../../widget/nearby_customers_layer.dart';
import '../../widget/order_card.dart';
import '../../widget/order_modal.dart';
import '../../widget/nearby_customers_modal.dart';
import 'package:http/http.dart' as http;
import '../../models/Order.dart';
import 'bloc/driver_bloc.dart';
import 'driver_route_page.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> with TickerProviderStateMixin {
  int _bottomIndex = 0;
  List<dynamic> _available = [];
  dynamic _activeOrder;
  late final ApiService _api;
  LatLng? _myLatLng;
  List<Map<String, dynamic>> _nearbyCustomers = [];
  bool _customersLoading = false;
  Timer? _customersRefreshTimer;
  DateTime? _lastCustomersRefreshAt;
  bool _isOnline = true;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _posSub;
  Timer? _ordersRefreshTimer;
  // int? _lastSeenOrderId; // tidak digunakan lagi agar modal bisa muncul berulang

  final MapController _mapController = MapController();
  final BroadcastService _broadcast = BroadcastService();
  int? _incomingOrderId; // track modal order id untuk dismiss saat accepted
  bool _isOrderModalOpen = false; // apakah modal order sedang terbuka
  late final DriverBloc _driverUiBloc;
  bool _routePageOpen = false; // apakah halaman rute sedang terbuka

  @override
  void initState() {
    super.initState();
    _driverUiBloc = DriverBloc();
    _api = RepositoryProvider.of<ApiService>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverOrderBloc>().add(LoadAvailableOrders());
      _sendCurrentLocationOnce();
      _subscribeToOrders();
      _startOrdersPolling();
      // Cek apakah ada order aktif milik driver setelah refresh, lalu redirect
      _restoreActiveOrderAndRedirect();
    });
  }

  Future<void> _loadAvailable() async {
    context.read<DriverOrderBloc>().add(LoadAvailableOrders());
  }

  void _subscribeToOrders() async {
    await _broadcast.subscribeOrders(
      (evt) {
        if (!mounted) return;
        // Izinkan notifikasi order masuk meski ada order aktif, agar driver tetap tahu
        try {
          final raw = evt['data'];
          Map<String, dynamic> data = {};
          if (raw is String) {
            if (raw.isNotEmpty) {
              data = (jsonDecode(raw) as Map<String, dynamic>);
            }
          } else if (raw is Map) {
            data = Map<String, dynamic>.from(raw);
          }
          // Hanya tampilkan modal untuk order berstatus pending dan belum ada driver
          final status = (data['status'] as String?)?.toLowerCase();
          final assignedDriverId = (data['driver_id'] as num?)?.toInt();
          // Jika status tidak tersedia di payload event, anggap sebagai pending
          if (status != null && status != 'pending') return;
          if (assignedDriverId != null && assignedDriverId != 0) return;
          // Jangan munculkan modal jika driver sedang offline
          if (!_isOnline) return;
          final id = (data['id'] as num?)?.toInt() ?? 0;
          _incomingOrderId = id;
          _showIncomingOrderModal(data);
        } catch (_) {}
      },
      onAccepted: (evt) {
        // jika order yang sama telah di-accept oleh driver manapun, tutup modal
        try {
          final raw = evt['data'];
          Map<String, dynamic> data = {};
          if (raw is String) {
            if (raw.isNotEmpty) {
              data = (jsonDecode(raw) as Map<String, dynamic>);
            }
          } else if (raw is Map) {
            data = Map<String, dynamic>.from(raw);
          }
          final id = (data['id'] as num?)?.toInt() ?? 0;
          final acceptedBy = (data['driver_id'] as num?)?.toInt();
          if (_incomingOrderId != null && id == _incomingOrderId) {
            // hanya tutup modal jika di-accept oleh driver lain
            final myDriverId = _api.userId;
            if (acceptedBy == null ||
                (myDriverId != null && acceptedBy != myDriverId)) {
              _incomingOrderId = null;
              if (_driverUiBloc.state.orderModalOpen) {
                try {
                  Navigator.of(context).pop();
                } catch (_) {}
                _driverUiBloc.add(CloseOrderModal());
              }
              // refresh daftar
              Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
            }
          }
        } catch (_) {}
      },
      onCancelled: (evt) {
        // jika order dibatalkan oleh customer, tutup modal jika cocok
        try {
          final raw = evt['data'];
          Map<String, dynamic> data = {};
          if (raw is String) {
            if (raw.isNotEmpty) {
              data = (jsonDecode(raw) as Map<String, dynamic>);
            }
          } else if (raw is Map) {
            data = Map<String, dynamic>.from(raw);
          }
          final id = (data['id'] as num?)?.toInt() ?? 0;
          if (_incomingOrderId != null && id == _incomingOrderId) {
            _incomingOrderId = null;
            if (_driverUiBloc.state.orderModalOpen) {
              try {
                Navigator.of(context).pop();
              } catch (_) {}
              _driverUiBloc.add(CloseOrderModal());
            }
            Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
          }
        } catch (_) {}
      },
      onCompleted: (evt) {
        try {
          final raw = evt['data'];
          Map<String, dynamic> data = {};
          if (raw is String) {
            if (raw.isNotEmpty)
              data = (jsonDecode(raw) as Map<String, dynamic>);
          } else if (raw is Map) {
            data = Map<String, dynamic>.from(raw);
          }
          final id = (data['id'] as num?)?.toInt();
          if (_activeOrder != null && id == _activeOrder.id) {
            _stopActiveTracking();
            setState(() {
              _activeOrder = null;
              _routePageOpen = false;
            });
            // Setelah selesai, tandai driver sebagai idle dan hidupkan kembali auto-refresh
            _api.updateMyStatus('idle').catchError((_) {});
            _startAutoRefresh();
            Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Order selesai')));
          }
        } catch (_) {}
      },
      token: _api.token,
    );
    // Tambahkan subscription ke inbox privat driver agar menerima offer tertarget
    final myId = _api.userId;
    if (myId != null) {
      await _broadcast.subscribeDriverInbox(
        myId,
        (evt) {
          if (!mounted) return;
          try {
            final raw = evt['data'];
            Map<String, dynamic> data = {};
            if (raw is String) {
              if (raw.isNotEmpty) {
                data = (jsonDecode(raw) as Map<String, dynamic>);
              }
            } else if (raw is Map) {
              data = Map<String, dynamic>.from(raw);
            }
            final status = (data['status'] as String?)?.toLowerCase();
            final assignedDriverId = (data['driver_id'] as num?)?.toInt();
            if (status != null && status != 'pending') return;
            if (assignedDriverId != null && assignedDriverId != 0) return;
            if (!_isOnline) return;
            final id = (data['id'] as num?)?.toInt() ?? 0;
            // Hindari duplikasi jika sudah ada modal untuk order ini
            if (_incomingOrderId != null && _incomingOrderId == id) return;
            _incomingOrderId = id;
            _showIncomingOrderModal(data);
          } catch (_) {}
        },
        onAccepted: (evt) {
          try {
            final raw = evt['data'];
            Map<String, dynamic> data = {};
            if (raw is String) {
              if (raw.isNotEmpty) {
                data = (jsonDecode(raw) as Map<String, dynamic>);
              }
            } else if (raw is Map) {
              data = Map<String, dynamic>.from(raw);
            }
            final id = (data['id'] as num?)?.toInt() ?? 0;
            final acceptedBy = (data['driver_id'] as num?)?.toInt();
            if (_incomingOrderId != null && id == _incomingOrderId) {
              final myDriverId = _api.userId;
              if (acceptedBy == null ||
                  (myDriverId != null && acceptedBy != myDriverId)) {
                _incomingOrderId = null;
                if (_driverUiBloc.state.orderModalOpen) {
                  try {
                    Navigator.of(context).pop();
                  } catch (_) {}
                  _driverUiBloc.add(CloseOrderModal());
                }
                Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
              }
            }
          } catch (_) {}
        },
        onCancelled: (evt) {
          try {
            final raw = evt['data'];
            Map<String, dynamic> data = {};
            if (raw is String) {
              if (raw.isNotEmpty) {
                data = (jsonDecode(raw) as Map<String, dynamic>);
              }
            } else if (raw is Map) {
              data = Map<String, dynamic>.from(raw);
            }
            final id = (data['id'] as num?)?.toInt() ?? 0;
            if (_incomingOrderId != null && id == _incomingOrderId) {
              _incomingOrderId = null;
              if (_driverUiBloc.state.orderModalOpen) {
                try {
                  Navigator.of(context).pop();
                } catch (_) {}
                _driverUiBloc.add(CloseOrderModal());
              }
              Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
            }
          } catch (_) {}
        },
        onCompleted: (evt) {
          try {
            final raw = evt['data'];
            Map<String, dynamic> data = {};
            if (raw is String) {
              if (raw.isNotEmpty)
                data = (jsonDecode(raw) as Map<String, dynamic>);
            } else if (raw is Map) {
              data = Map<String, dynamic>.from(raw);
            }
            final id = (data['id'] as num?)?.toInt();
            if (_activeOrder != null && id == _activeOrder.id) {
              _stopActiveTracking();
              setState(() {
                _activeOrder = null;
                _routePageOpen = false;
              });
              _api.updateMyStatus('idle').catchError((_) {});
              _startAutoRefresh();
              Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Order selesai')));
            }
          } catch (_) {}
        },
        token: _api.token,
      );
    }
  }

  void _showIncomingOrderModal(Map<String, dynamic> orderData) {
    final cust = _nearbyCustomers.firstWhere(
      (c) => c['id'] == orderData['customer_id'],
      orElse: () => {},
    );
    // Hitung jarak driver ke titik pickup (jika lokasi tersedia)
    double? driverDistanceKm;
    try {
      if (_myLatLng != null) {
        final pLat = (orderData['lat_pickup'] as num?)?.toDouble();
        final pLon = (orderData['lon_pickup'] as num?)?.toDouble();
        if (pLat != null && pLon != null) {
          driverDistanceKm = const Distance().as(
            LengthUnit.Kilometer,
            _myLatLng!,
            LatLng(pLat, pLon),
          );
        }
      }
    } catch (_) {}
    double? etaMinutes;
    if (driverDistanceKm != null) {
      const speedKmh = 25.0; // asumsi kecepatan rata-rata
      etaMinutes = (driverDistanceKm / speedKmh) * 60.0;
    }
    _driverUiBloc.add(OpenOrderModal());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrderModal(
        orderData: orderData,
        customerInfo: cust.isEmpty ? null : cust,
        initialSeconds: 15,
        driverDistanceKm: driverDistanceKm,
        estimatedPickupMinutes: etaMinutes,
        onViewPickup: () {
          try {
            final pLat = (orderData['lat_pickup'] as num?)?.toDouble();
            final pLon = (orderData['lon_pickup'] as num?)?.toDouble();
            if (pLat != null && pLon != null) {
              _mapController.move(LatLng(pLat, pLon), 18);
            }
          } catch (_) {}
        },
        onViewDropoff: () {
          try {
            final dLat = (orderData['lat_dropoff'] as num?)?.toDouble();
            final dLon = (orderData['lon_dropoff'] as num?)?.toDouble();
            if (dLat != null && dLon != null) {
              _mapController.move(LatLng(dLat, dLon), 18);
            }
          } catch (_) {}
        },
        onCancel: () {
          // Tutup dan reset flag modal, lalu refresh orders agar modal bisa muncul lagi
          _incomingOrderId = null;
          _driverUiBloc.add(CloseOrderModal());
          // Beri jeda singkat agar state CloseOrderModal terproses sebelum polling
          Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
        },
        onAccept: () async {
          try {
            final accepted = await _api.acceptOrder(orderData['id'] as int);
            setState(() {
              _activeOrder = accepted;
              _incomingOrderId = null;
              _driverUiBloc.add(CloseOrderModal());
            });
            // Tandai status job sebagai aktif (sedang mengerjakan order)
            try {
              await _api.updateMyStatus('active');
            } catch (_) {}
            // Hentikan auto refresh nearby selama order aktif
            _stopAutoRefresh();
            // Tutup dialog hanya jika masih terbuka untuk menghindari pop halaman utama
            if (_driverUiBloc.state.orderModalOpen) {
              try {
                Navigator.of(context).pop();
              } catch (_) {}
              _driverUiBloc.add(CloseOrderModal());
            }
            _fetchActivePolyline();
            _startActiveTracking();
            // Redirect ke halaman rute pickup/dropoff
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DriverRoutePage(order: accepted),
              ),
            );
          } catch (err) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Gagal accept: $err')));
          }
        },
      ),
    ).then((_) {
      // Pastikan flag modal ditutup di semua jalur dismiss (timeout, cancel, accepted, dsb)
      _incomingOrderId = null;
      _driverUiBloc.add(CloseOrderModal());
    });
  }

  Future<void> _loadNearbyCustomers() async {
    if (_api.token == null || _myLatLng == null) return;
    // Ketika order aktif, tidak perlu memanggil nearby
    if (_activeOrder != null) return;
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
      if (!mounted) return;
      setState(() {
        _nearbyCustomers = customers;
        _lastCustomersRefreshAt = DateTime.now();
      });
    } catch (_) {
      // abaikan error agar UI tetap jalan
    } finally {
      if (mounted) {
        setState(() {
          _customersLoading = false;
        });
      }
    }
  }

  void _startAutoRefresh() {
    _customersRefreshTimer?.cancel();
    _customersRefreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.nearbyCustomersRefreshSec),
      (_) {
        // Jangan refresh nearby ketika ada order aktif
        if (_activeOrder == null) {
          _loadNearbyCustomers();
        }
      },
    );
  }

  void _stopAutoRefresh() {
    _customersRefreshTimer?.cancel();
    _customersRefreshTimer = null;
  }

  void _startOrdersPolling() {
    _ordersRefreshTimer?.cancel();
    _ordersRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      // Tetap polling daftar orders meski ada order aktif
      _loadAvailable();
    });
  }

  void _stopOrdersPolling() {
    try {
      _ordersRefreshTimer?.cancel();
      _ordersRefreshTimer = null;
    } catch (_) {}
  }

  Future<void> _restoreActiveOrderAndRedirect() async {
    try {
      final active = await _api.getMyActiveOrder();
      if (!mounted) return;
      if (active != null) {
        setState(() {
          _activeOrder = active;
        });
        // Saat ada order aktif, hentikan refresh nearby dan mulai tracking
        _stopAutoRefresh();
        _fetchActivePolyline();
        _startActiveTracking();
        // Redirect ke halaman rute jika belum terbuka
        if (!_routePageOpen) {
          _routePageOpen = true;
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => DriverRoutePage(order: active),
                ),
              )
              .then((_) {
                _routePageOpen = false;
                if (_activeOrder == null) {
                  _startAutoRefresh();
                }
              });
        }
      }
    } catch (_) {}
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
    _stopActiveTracking();
    setState(() {
      _activeOrder = null;
      _routePoints = [];
    });
    // Kembalikan status job menjadi idle agar bisa menerima order lagi
    try {
      await _api.updateMyStatus('idle');
    } catch (_) {}
    _startAutoRefresh();
    Future.delayed(const Duration(milliseconds: 300), _loadAvailable);
  }

  Widget _orderList() {
    return BlocConsumer<DriverOrderBloc, DriverOrderState>(
      listener: (context, state) {
        if (!mounted) return;
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
          // Fallback: tampilkan modal jika ada order pending baru dan socket tidak memicu
          if (_activeOrder == null) {
            try {
              final latest = _available.firstWhere(
                (o) =>
                    (o.driverId == null || o.driverId == 0) &&
                    o.status.toLowerCase() == 'pending',
                orElse: () => null,
              );
              if (latest != null) {
                final id = latest.id as int;
                // Izinkan modal muncul kembali selama pending dan modal tidak terbuka
                if (!_driverUiBloc.state.orderModalOpen) {
                  _incomingOrderId = id;
                  final orderData = {
                    'id': latest.id,
                    'customer_id': latest.customerId,
                    'driver_id': latest.driverId,
                    'lat_pickup': latest.latPickup,
                    'lon_pickup': latest.lonPickup,
                    'pickup_address': latest.pickupAddress,
                    'lat_dropoff': latest.latDropoff,
                    'lon_dropoff': latest.lonDropoff,
                    'dropoff_address': latest.dropoffAddress,
                    'total_price': latest.totalPrice,
                    'distance': latest.distance,
                    'status': latest.status,
                  };
                  _showIncomingOrderModal(orderData);
                }
              }
            } catch (_) {}
          }
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
              final cust = _nearbyCustomers.firstWhere(
                (c) => c['id'] == o.customerId,
                orElse: () => {},
              );
              return OrderCard(
                order: o,
                customerInfo: cust.isEmpty ? null : cust,
                onAccept: () => _accept(o),
                onReject: () => _reject(o),
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
    final pickup = _activeOrder == null
        ? null
        : LatLng(_activeOrder.latPickup, _activeOrder.lonPickup);
    final dropoff = _activeOrder == null
        ? null
        : LatLng(_activeOrder.latDropoff, _activeOrder.lonDropoff);
    final driverMarkerLayer = (_myLatLng == null)
        ? const SizedBox.shrink()
        : MarkerLayer(
            markers: [
              Marker(
                point: _myLatLng!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
            ],
          );
    return Stack(
      children: [
        RouteMap(
          mapController: _mapController,
          center: center,
          zoom: 18,
          pickup: pickup,
          dropoff: dropoff,
          routePoints: _routePoints,
          extraLayers: [driverMarkerLayer],
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

  Future<void> _fetchActivePolyline() async {
    if (_activeOrder == null) return;
    try {
      final pLon = _activeOrder.lonPickup;
      final pLat = _activeOrder.latPickup;
      final dLon = _activeOrder.lonDropoff;
      final dLat = _activeOrder.latDropoff;
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
          final List coords = routes[0]['geometry']['coordinates'];
          if (!mounted) return;
          setState(() {
            _routePoints = [
              for (final c in coords)
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            ];
          });
        }
      }
    } catch (_) {
      // Abaikan error routing untuk sementara
    }
  }

  Future<void> _startActiveTracking() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return;
        }
      }
      _posSub?.cancel();
      _posSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5,
            ),
          ).listen((pos) async {
            if (!mounted) return;
            setState(() {
              _myLatLng = LatLng(pos.latitude, pos.longitude);
            });
            try {
              if (!mounted) return;
              if (_activeOrder != null) {
                await _api.updateOrderLocation(
                  _activeOrder.id,
                  pos.latitude,
                  pos.longitude,
                );
              }
            } catch (_) {
              // Abaikan error kirim lokasi agar UI tetap berjalan
            }
          });
    } catch (_) {
      // Abaikan error permission/stream
    }
  }

  void _stopActiveTracking() {
    try {
      _posSub?.cancel();
      _posSub = null;
    } catch (_) {}
  }

  Future<void> _sendCurrentLocationOnce() async {
    if (_api.token == null) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      await _api.updateMyLocation(
        pos.latitude,
        pos.longitude,
        // Saat awal, tandai driver sebagai siap (idle) jika tidak ada order aktif
        statusJob: _activeOrder == null ? 'idle' : 'active',
      );
      if (!mounted) return;
      setState(() {
        _myLatLng = LatLng(pos.latitude, pos.longitude);
      });
      _loadNearbyCustomers();
      _startAutoRefresh();
    } catch (_) {
      // Diamkan jika error, agar tidak mengganggu alur driver
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _stopOrdersPolling();
      _broadcast.unsubscribeAll();
    try {
      _driverUiBloc.close();
    } catch (_) {}
    super.dispose();
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

    return BlocProvider.value(
      value: _driverUiBloc,
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            RouteMap(
              mapController: _mapController,
              center: center,
              zoom: 18,
              routePoints: const [],
              extraLayers: [
                MarkerLayer(markers: [...myMarker, ...customerMarkers]),
                NearbyCustomersLayer(customers: _nearbyCustomers),
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
              right: 8,
              top: 8,
              child: Card(
                child: IconButton(
                  icon: const Icon(Icons.people),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => NearbyCustomersModal(
                        customers: _nearbyCustomers,
                        onSelect: (c) {
                          try {
                            final lat = (c['lat'] as num).toDouble();
                            final lng = (c['lng'] as num).toDouble();
                            final p = LatLng(lat, lng);
                            _mapController.move(p, 18);
                          } catch (_) {}
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  tooltip: 'Pilih customer terdekat',
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
      ),
    );
  }

  Widget _customersMapFull() {
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

    return Stack(
      children: [
        RouteMap(
          mapController: _mapController,
          center: center,
          zoom: 20,
          routePoints: const [],
          extraLayers: [
            MarkerLayer(markers: [...myMarker, ...customerMarkers]),
            NearbyCustomersLayer(customers: _nearbyCustomers),
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
          right: 8,
          top: 8,
          child: Card(
            child: IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => NearbyCustomersModal(
                    customers: _nearbyCustomers,
                    onSelect: (c) {
                      try {
                        final lat = (c['lat'] as num).toDouble();
                        final lng = (c['lng'] as num).toDouble();
                        final p = LatLng(lat, lng);
                        _mapController.move(p, 18);
                      } catch (_) {}
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
              tooltip: 'Pilih customer terdekat',
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
    // Paksa alih ke halaman rute saat ada order aktif
    if (_activeOrder != null && !_routePageOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _routePageOpen = true;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DriverRoutePage(order: _activeOrder),
            ),
          );
        } catch (_) {}
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        actions: [
          Row(
            children: [
              const Text('Online'),
              Switch(
                value: _isOnline,
                onChanged: (val) async {
                  setState(() => _isOnline = val);
                  // Gunakan 'online' ketika true, 'offline' ketika false
                  final status = val ? 'online' : 'offline';
                  try {
                    await _api.updateMyStatus(status);
                    // Jika baru online, kirim lokasi sekali agar muncul di nearby
                    if (val) {
                      _sendCurrentLocationOnce();
                    }
                  } catch (e) {
                    // Kembalikan toggle bila gagal
                    setState(() => _isOnline = !val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal update status: $e')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _bottomIndex == 0
          ? (_activeOrder == null
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _customersMapFull(),
                  )
                : _activeMap())
          : _bottomIndex == 1
          ? Padding(padding: const EdgeInsets.all(8.0), child: _historyTab())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      onPressed: () async {
                        try {
                          await _api.logout();
                        } catch (_) {
                          // Abaikan error logout; tetap hapus data lokal
                        } finally {
                          _api.clearToken();
                          await AuthStorage.clearAuth();
                          if (!mounted) return;
                          context.go('/login');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _historyTab() {
    return FutureBuilder<List<OrderModel>>(
      future: _api.listOrders(),
      builder: (context, snapshot) {
        final myId = _api.userId;
        final orders = (snapshot.data ?? [])
            .where((o) => myId != null && o.driverId == myId)
            .toList();
        final hasActive = orders.any((o) {
          final s = o.status.toLowerCase();
          return s != 'completed' && s != 'cancelled';
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeOrder != null || hasActive)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Lanjutkan order aktif'),
                  subtitle: Text(
                    _activeOrder != null
                        ? 'Order #${_activeOrder.id} - ${_activeOrder.status}'
                        : 'Ada order aktif yang belum selesai',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Gunakan _activeOrder bila tersedia, jika tidak ambil dari API
                      var order = _activeOrder;
                      if (order == null) {
                        try {
                          order = await _api.getMyActiveOrder();
                        } catch (_) {}
                      }
                      if (order != null) {
                        setState(() => _activeOrder = order);
                        _stopAutoRefresh();
                        _fetchActivePolyline();
                        _startActiveTracking();
                        if (!_routePageOpen) {
                          _routePageOpen = true;
                          if (!mounted) return;
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DriverRoutePage(order: order!),
                                ),
                              )
                              .then((_) {
                                _routePageOpen = false;
                                if (_activeOrder == null) {
                                  _startAutoRefresh();
                                }
                              });
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tidak ada order aktif'),
                          ),
                        );
                      }
                    },
                    child: const Text('Tampilkan rute'),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {},
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    final s = o.status.toLowerCase();
                    final isDone = s == 'completed' || s == 'cancelled';
                    return ListTile(
                      leading: Icon(
                        isDone ? Icons.check_circle : Icons.directions_bike,
                      ),
                      title: Text('Order #${o.id} - ${o.status}'),
                      subtitle: Text(
                        'Jarak ${o.distance} km • Rp ${o.totalPrice}',
                      ),
                      trailing: isDone
                          ? null
                          : ElevatedButton(
                              onPressed: () {
                                setState(() => _activeOrder = o);
                                _stopAutoRefresh();
                                _fetchActivePolyline();
                                _startActiveTracking();
                                if (!_routePageOpen) {
                                  _routePageOpen = true;
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DriverRoutePage(order: o),
                                        ),
                                      )
                                      .then((_) {
                                        _routePageOpen = false;
                                        if (_activeOrder == null) {
                                          _startAutoRefresh();
                                        }
                                      });
                                }
                              },
                              child: const Text('Tampilkan rute'),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // (hapus duplikasi dispose)
}
