import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:latlong2/latlong.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc() : super(const CustomerState()) {
    on<SetPickup>((e, emit) => emit(state.copyWith(pickup: e.p)));
    on<SetDropoff>((e, emit) => emit(state.copyWith(dropoff: e.p)));
    on<UpdatePickupText>((e, emit) => emit(state.copyWith(pickupText: e.text)));
    on<UpdateDropoffText>((e, emit) => emit(state.copyWith(dropoffText: e.text)));
    on<SetRoutePoints>((e, emit) => emit(state.copyWith(routePoints: e.points)));
    on<SetNearbyDrivers>((e, emit) => emit(state.copyWith(nearbyDrivers: e.drivers)));
    on<SetMapReady>((e, emit) => emit(state.copyWith(mapReady: e.ready)));
  }
}
