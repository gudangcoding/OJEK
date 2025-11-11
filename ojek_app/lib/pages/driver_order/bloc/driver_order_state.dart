part of 'driver_order_bloc.dart';

@immutable
sealed class DriverOrderState {}

final class DriverOrderInitial extends DriverOrderState {}

final class DriverOrdersLoading extends DriverOrderState {}
final class DriverOrdersLoaded extends DriverOrderState { final List<OrderModel> orders; DriverOrdersLoaded(this.orders); }
final class DriverOrderActive extends DriverOrderState { final OrderModel order; DriverOrderActive(this.order); }
final class DriverOrderFailure extends DriverOrderState { final String message; DriverOrderFailure(this.message); }
