import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../../../services/api.dart';
import '../../../models/Order.dart';

part 'driver_order_event.dart';
part 'driver_order_state.dart';

class DriverOrderBloc extends Bloc<DriverOrderEvent, DriverOrderState> {
  final ApiService api;
  DriverOrderBloc({ApiService? apiService})
      : api = apiService ?? ApiService(),
        super(DriverOrderInitial()) {
    on<LoadAvailableOrders>(_onLoadAvailable);
    on<AcceptOrder>(_onAccept);
    on<RejectOrder>(_onReject);
    on<CompleteOrder>(_onComplete);
  }

  Future<void> _onLoadAvailable(LoadAvailableOrders e, Emitter<DriverOrderState> emit) async {
    emit(DriverOrdersLoading());
    try {
      final list = await api.listAvailableOrders();
      emit(DriverOrdersLoaded(list));
    } catch (err) {
      emit(DriverOrderFailure(err.toString()));
    }
  }

  Future<void> _onAccept(AcceptOrder e, Emitter<DriverOrderState> emit) async {
    try {
      final order = await api.acceptOrder(e.orderId);
      emit(DriverOrderActive(order));
    } catch (err) {
      emit(DriverOrderFailure(err.toString()));
    }
  }

  Future<void> _onReject(RejectOrder e, Emitter<DriverOrderState> emit) async {
    try {
      await api.rejectOrder(e.orderId);
      add(LoadAvailableOrders());
    } catch (err) {
      emit(DriverOrderFailure(err.toString()));
    }
  }

  Future<void> _onComplete(CompleteOrder e, Emitter<DriverOrderState> emit) async {
    try {
      await api.completeOrder(e.orderId);
      add(LoadAvailableOrders());
    } catch (err) {
      emit(DriverOrderFailure(err.toString()));
    }
  }
}
