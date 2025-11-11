import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config.dart';
import '../../services/api.dart';
import '../../services/auth_storage.dart';
import 'package:go_router/go_router.dart';
import '../../services/broadcast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../customer_order/bloc/customer_order_bloc.dart';
import '../../widget/form_input.dart';
import '../../widget/location_search_field.dart' as reusable;
import '../../widget/nearby_drivers_widget.dart';
import '../../widget/route_map.dart';
import '../../widget/nearby_drivers_layer.dart';
import '../../widget/waiting_dialog.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/nominatim.dart';
import 'bloc/customer_bloc.dart';
import '../customer/customer_route_page.dart';
import '../../models/Order.dart';

// Wrapper untuk menggunakan reusable LocationInput dengan API yang konsisten
class LocationSearchField extends StatefulWidget {
  final String label;
  final void Function(String)? onTextChanged;
  final void Function(LatLng)? onSelectedLatLng;
  final void Function(String)? onSelectedAddress;
  final String? initialText;

  const LocationSearchField({
    super.key,
    required this.label,
    this.onTextChanged,
    this.onSelectedLatLng,
    this.onSelectedAddress,
    this.initialText,
  });

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
      initialText: widget.initialText,
      onSelected: (suggestion) {
        try {
          final lat = _toDouble(suggestion['lat']);
          final lon = _toDouble(suggestion['lon'] ?? suggestion['lng']);
          final name = (suggestion['display_name'] ?? '').toString();
          if (lat != null && lon != null) {
            widget.onSelectedLatLng?.call(LatLng(lat, lon));
          }
          widget.onSelectedAddress?.call(name);
        } catch (_) {
          // Abaikan error parsing agar tidak crash UI
          // Bisa ditambahkan SnackBar jika perlu
        }
      },
    );
  }
}

extension on _LocationSearchFieldState {
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage>
    with TickerProviderStateMixin {
  int _bottomIndex = 0;
  late final ApiService _api;
  final BroadcastService _rt = BroadcastService();

  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _pendingMove;
  LatLngBounds? _pendingBounds;
  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupText = '';
  String _dropoffText = '';
  double? _distanceKm;
  double? _price;
  bool _bookingLoading = false;
  final List<dynamic> _history = [];
  List<LatLng> _routePoints = [];
  bool _orderPlaced = false;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _nearbyRequested = false;
  LatLng? _driverLatLng;
  int? _activeOrderId;
  OrderModel? _activeOrderModel;
  bool _waitingDialogOpen = false;
  bool _waitingDialogPendingClose = false;
  late final CustomerBloc _customerBloc;

  @override
  void initState() {
    super.initState();
    _customerBloc = CustomerBloc();
    _api = RepositoryProvider.of<ApiService>(context);
    // Kirim lokasi user ke backend saat app dibuka (jika sudah login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendCurrentLocationOnce();
    });
  }


  double _haversine(LatLng a, LatLng b) {
    const R = 6371.0; // km
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
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
      _customerBloc.add(SetNearbyDrivers(data));
    } catch (_) {
      // Abaikan error fetch untuk sementara
    }
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
        statusJob: 'active',
      );
      // Set pickup awal ke posisi saya dan sinkronkan tampilan
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickup = me;
        _nearbyRequested = true;
      });
      _updateNearbyDrivers(me);
      _pendingMove = me;
      if (_mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(me, 18);
          } catch (e) {
            debugPrint('Map move failed (init my loc): $e');
          }
        });
      }
      // Coba reverse geocode agar field pickup terisi alamat manusiawi
      try {
        final addr = await NominatimService.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted && addr != null && addr.isNotEmpty) {
          setState(() {
            _pickupText = addr;
          });
        }
      } catch (_) {}
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
            for (final c in coords)
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ];
          _customerBloc.add(SetRoutePoints(_routePoints));
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
          final bounds = LatLngBounds(
            LatLng(minLat, minLon),
            LatLng(maxLat, maxLon),
          );
          _pendingBounds = bounds;
          if (_mapReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _mapController.fitBounds(
                  bounds,
                  options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
                );
              } catch (e) {
                debugPrint('Map fitBounds failed: $e');
              }
            });
          }
          setState(() {});
        }
      }
    } catch (_) {
      // Abaikan error routing untuk sementara (mis. rate limit)
    }
  }

  Future<void> _book() async {
    if (_pickup == null ||
        _dropoff == null ||
        _distanceKm == null ||
        _price == null) {
      return;
    }
    context.read<CustomerOrderBloc>().add(
      BookOrder(
        latPickup: _pickup!.latitude,
        lonPickup: _pickup!.longitude,
        pickupAddress: _pickupText,
        latDropoff: _dropoff!.latitude,
        lonDropoff: _dropoff!.longitude,
        dropoffAddress: _dropoffText,
        totalPrice: _price!,
        distance: _distanceKm!,
      ),
    );
  }

  Future<void> _cancelActiveOrder() async {
    final id = _activeOrderId;
    if (id == null) return;
    try {
      await _api.cancelOrder(id);
      if (!mounted) return;
      setState(() {
        _orderPlaced = false;
        _driverLatLng = null;
        _activeOrderId = null;
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order dibatalkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal batal: $e')),
      );
    }
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
          child: RouteMap(
            mapController: _mapController,
            center: center,
            zoom: 18,
            pickup: _pickup,
            dropoff: _dropoff,
            routePoints: _routePoints,
            extraLayers: [
              if (_pickup == null && _dropoff == null)
                NearbyDriversLayer(drivers: _nearbyDrivers),
              if (_driverLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.motorcycle,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                  ],
                ),
            ],
            onPickupDragged: (p) {
              setState(() {
                _pickup = p;
              });
              _customerBloc.add(SetPickup(p));
              _nearbyRequested = true;
              _updateNearbyDrivers(p);
              _pendingMove = p;
              if (_mapReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    _mapController.move(p, 18);
                  } catch (e) {
                    debugPrint('Map move failed (pickup drag): $e');
                  }
                });
              }
              // Update alamat pickup melalui reverse geocode tanpa mengganggu UI
              () async {
                final addr = await NominatimService.reverseGeocode(p.latitude, p.longitude);
                if (!mounted) return;
                if (addr != null && addr.isNotEmpty) {
                  setState(() {
                    _pickupText = addr;
                  });
                  _customerBloc.add(UpdatePickupText(addr));
                }
              }();
              _recalc();
            },
            onDropoffDragged: (p) {
              setState(() {
                _dropoff = p;
              });
              _customerBloc.add(SetDropoff(p));
              _pendingMove = p;
              if (_mapReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    _mapController.move(p, 18);
                  } catch (e) {
                    debugPrint('Map move failed (dropoff drag): $e');
                  }
                });
              }
              () async {
                final addr = await NominatimService.reverseGeocode(p.latitude, p.longitude);
                if (!mounted) return;
                if (addr != null && addr.isNotEmpty) {
                  setState(() {
                    _dropoffText = addr;
                  });
                  _customerBloc.add(UpdateDropoffText(addr));
                }
              }();
              _recalc();
            },
            onMapReady: () {
              _mapReady = true;
              _customerBloc.add(SetMapReady(true));
              // Jalankan pending move bila ada
              if (_pendingMove != null) {
                try {
                  _mapController.move(_pendingMove!, 14);
                } catch (e) {
                  debugPrint('Map move pending failed: $e');
                }
                _pendingMove = null;
              }
              // Jalankan pending fitBounds bila ada
              if (_pendingBounds != null) {
                try {
                  _mapController.fitBounds(
                    _pendingBounds!,
                    options: const FitBoundsOptions(
                      padding: EdgeInsets.all(40),
                    ),
                  );
                } catch (e) {
                  debugPrint('Map fitBounds pending failed: $e');
                }
                _pendingBounds = null;
              }
            },
          ),
        ),
        if (!_orderPlaced)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationSearchField(
                  label: 'Pickup',
                  initialText: _pickupText,
                  onTextChanged: (v) => _pickupText = v,
                  onSelectedLatLng: (p) {
                    setState(() {
                      _pickup = p;
                      _nearbyRequested = true;
                      _updateNearbyDrivers(p);
                      _recalc();
                    });
                    _customerBloc.add(SetPickup(p));
                    _pendingMove = p;
                    if (_mapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        try {
                          _mapController.move(p, 14);
                        } catch (e) {
                          debugPrint('Map move failed (pickup): $e');
                        }
                      });
                    }
                  },
                  onSelectedAddress: (addr) => _pickupText = addr,
                ),
                const SizedBox(height: 8),
                LocationSearchField(
                  label: 'Dropoff',
                  initialText: _dropoffText,
                  onTextChanged: (v) => _dropoffText = v,
                  onSelectedLatLng: (p) {
                    setState(() {
                      _dropoff = p;
                      _recalc();
                    });
                    _customerBloc.add(SetDropoff(p));
                    _pendingMove = p;
                    if (_mapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        try {
                          _mapController.move(p, 14);
                        } catch (e) {
                          debugPrint('Map move failed (dropoff): $e');
                        }
                      });
                    }
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
                  child: PrimaryButton(
                    text: 'Booking',
                    onPressed: _bookingLoading ? null : _book,
                  ),
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

  Widget _profileTab() {
    return Padding(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerOrderBloc, CustomerOrderState>(
      listener: (context, state) async {
        if (state is CustomerBookingInProgress) {
          setState(() {
            _bookingLoading = true;
          });
        } else {
          setState(() {
            _bookingLoading = false;
          });
        }
        if (state is CustomerBookingSuccess) {
          setState(() {
            _orderPlaced = true;
            _activeOrderId = state.order.id;
            _activeOrderModel = state.order;
          });
          // Subscribe to realtime order updates
          await _rt.subscribeOrderDetail(state.order.id, (evt) {
            if (!mounted) return;
            final t = evt['type'];
            if (t == 'accepted') {
              _waitingDialogPendingClose = true;
              if (_waitingDialogOpen) {
                try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
                _waitingDialogOpen = false;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order diterima driver, tidak bisa dibatalkan'),
                ),
              );
              // Redirect customer ke halaman rute perjalanan
              if (_activeOrderModel != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerRoutePage(order: _activeOrderModel!),
                  ),
                );
              }
            } else if (t == 'rejected') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order ditolak, coba lagi')),
              );
              setState(() {
                _orderPlaced = false;
                _activeOrderId = null;
                _driverLatLng = null;
              });
              try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
            } else if (t == 'completed') {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Order selesai')));
              setState(() {
                _orderPlaced = false;
                _activeOrderId = null;
                _driverLatLng = null;
              });
              try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
            } else if (t == 'cancelled') {
              // Tutup dialog jika ada pembatalan (oleh customer/driver/system)
              setState(() {
                _orderPlaced = false;
                _activeOrderId = null;
                _driverLatLng = null;
              });
              try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order dibatalkan')),
              );
            }
          }, token: _api.token);
          await _rt.subscribeOrderLocation(state.order.id, (evt) {
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
                // Ikuti pergerakan driver di peta agar tracking terasa real-time
                if (_mapReady) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      _mapController.move(LatLng(lat, lng), 18);
                    } catch (e) {
                      debugPrint('Map move failed (driver tracking): $e');
                    }
                  });
                }
              }
            } catch (_) {}
          }, token: _api.token);
          _waitingDialogOpen = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder: (_) => WaitingDialog(
              onCancel: _cancelActiveOrder,
              cancelEnabled: true,
            ),
          );
          if (_waitingDialogPendingClose) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
              _waitingDialogOpen = false;
              _waitingDialogPendingClose = false;
            });
          }
        }
        if (state is CustomerBookingFailure) {
          setState(() {
            _orderPlaced = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal booking: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: _bottomIndex == 0
            ? _orderTab()
            : _bottomIndex == 1
            ? _historyTab()
            : _profileTab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomIndex,
          onTap: (i) {
            setState(() => _bottomIndex = i);
            if (i == 1) {
              // Load riwayat ketika tab History dibuka
              context.read<CustomerOrderBloc>().add(LoadHistory());
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
