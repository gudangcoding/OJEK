part of 'customer_bloc.dart';

@immutable
class CustomerState {
  final LatLng? pickup;
  final LatLng? dropoff;
  final String pickupText;
  final String dropoffText;
  final List<LatLng> routePoints;
  final List<Map<String, dynamic>> nearbyDrivers;
  final bool mapReady;

  const CustomerState({
    this.pickup,
    this.dropoff,
    this.pickupText = '',
    this.dropoffText = '',
    this.routePoints = const [],
    this.nearbyDrivers = const [],
    this.mapReady = false,
  });

  CustomerState copyWith({
    LatLng? pickup,
    LatLng? dropoff,
    String? pickupText,
    String? dropoffText,
    List<LatLng>? routePoints,
    List<Map<String, dynamic>>? nearbyDrivers,
    bool? mapReady,
  }) {
    return CustomerState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupText: pickupText ?? this.pickupText,
      dropoffText: dropoffText ?? this.dropoffText,
      routePoints: routePoints ?? this.routePoints,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
      mapReady: mapReady ?? this.mapReady,
    );
  }
}
