part of 'driver_order_bloc.dart';

@immutable
sealed class DriverOrderEvent {}

final class LoadAvailableOrders extends DriverOrderEvent {}
final class AcceptOrder extends DriverOrderEvent { final int orderId; AcceptOrder(this.orderId); }
final class RejectOrder extends DriverOrderEvent { final int orderId; RejectOrder(this.orderId); }
final class CompleteOrder extends DriverOrderEvent { final int orderId; CompleteOrder(this.orderId); }
