part of 'customer_bloc.dart';

@immutable
sealed class CustomerEvent {}

final class SetPickup extends CustomerEvent { final LatLng p; SetPickup(this.p); }
final class SetDropoff extends CustomerEvent { final LatLng p; SetDropoff(this.p); }
final class UpdatePickupText extends CustomerEvent { final String text; UpdatePickupText(this.text); }
final class UpdateDropoffText extends CustomerEvent { final String text; UpdateDropoffText(this.text); }
final class SetRoutePoints extends CustomerEvent { final List<LatLng> points; SetRoutePoints(this.points); }
final class SetNearbyDrivers extends CustomerEvent { final List<Map<String, dynamic>> drivers; SetNearbyDrivers(this.drivers); }
final class SetMapReady extends CustomerEvent { final bool ready; SetMapReady(this.ready); }
