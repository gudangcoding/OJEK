part of 'driver_bloc.dart';

@immutable
sealed class DriverEvent {}

final class OpenOrderModal extends DriverEvent {}
final class CloseOrderModal extends DriverEvent {}
final class SetMyLocation extends DriverEvent { final LatLng pos; SetMyLocation(this.pos); }
final class SetRoutePoints extends DriverEvent { final List<LatLng> points; SetRoutePoints(this.points); }
