part of 'driver_bloc.dart';

@immutable
class DriverState {
  final bool orderModalOpen;
  final LatLng? myLatLng;
  final List<LatLng> routePoints;

  const DriverState({
    this.orderModalOpen = false,
    this.myLatLng,
    this.routePoints = const [],
  });

  DriverState copyWith({
    bool? orderModalOpen,
    LatLng? myLatLng,
    List<LatLng>? routePoints,
  }) {
    return DriverState(
      orderModalOpen: orderModalOpen ?? this.orderModalOpen,
      myLatLng: myLatLng ?? this.myLatLng,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}
