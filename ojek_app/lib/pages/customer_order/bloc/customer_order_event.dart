part of 'customer_order_bloc.dart';

@immutable
sealed class CustomerOrderEvent {}

final class BookOrder extends CustomerOrderEvent {
  final double latPickup;
  final double lonPickup;
  final String pickupAddress;
  final double latDropoff;
  final double lonDropoff;
  final String dropoffAddress;
  final double totalPrice;
  final double distance;
  BookOrder({
    required this.latPickup,
    required this.lonPickup,
    required this.pickupAddress,
    required this.latDropoff,
    required this.lonDropoff,
    required this.dropoffAddress,
    required this.totalPrice,
    required this.distance,
  });
}

final class LoadHistory extends CustomerOrderEvent {}
