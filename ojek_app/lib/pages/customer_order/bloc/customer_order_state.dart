part of 'customer_order_bloc.dart';

@immutable
sealed class CustomerOrderState {}

final class CustomerOrderInitial extends CustomerOrderState {}

final class CustomerBookingInProgress extends CustomerOrderState {}

final class CustomerBookingSuccess extends CustomerOrderState {
  final OrderModel order;
  CustomerBookingSuccess(this.order);
}

final class CustomerBookingFailure extends CustomerOrderState {
  final String message;
  CustomerBookingFailure(this.message);
}

final class CustomerHistoryLoaded extends CustomerOrderState {
  final List<OrderModel> orders;
  CustomerHistoryLoaded(this.orders);
}

final class CustomerHistoryFailure extends CustomerOrderState {
  final String message;
  CustomerHistoryFailure(this.message);
}
