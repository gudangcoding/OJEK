import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../../../services/api.dart';
import '../../../models/Order.dart';

part 'customer_order_event.dart';
part 'customer_order_state.dart';

class CustomerOrderBloc extends Bloc<CustomerOrderEvent, CustomerOrderState> {
  final ApiService api;
  CustomerOrderBloc({ApiService? apiService})
      : api = apiService ?? ApiService(),
        super(CustomerOrderInitial()) {
    on<BookOrder>(_onBookOrder);
    on<LoadHistory>(_onLoadHistory);
  }

  Future<void> _onBookOrder(BookOrder e, Emitter<CustomerOrderState> emit) async {
    emit(CustomerBookingInProgress());
    try {
      final order = await api.createOrder(
        latPickup: e.latPickup,
        lonPickup: e.lonPickup,
        pickupAddress: e.pickupAddress,
        latDropoff: e.latDropoff,
        lonDropoff: e.lonDropoff,
        dropoffAddress: e.dropoffAddress,
        totalPrice: e.totalPrice,
        distance: e.distance,
      );
      emit(CustomerBookingSuccess(order));
    } catch (err) {
      emit(CustomerBookingFailure(err.toString()));
    }
  }

  Future<void> _onLoadHistory(LoadHistory e, Emitter<CustomerOrderState> emit) async {
    try {
      final list = await api.listOrders();
      emit(CustomerHistoryLoaded(list));
    } catch (err) {
      emit(CustomerHistoryFailure(err.toString()));
    }
  }
}
