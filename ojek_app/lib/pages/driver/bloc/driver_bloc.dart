import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:latlong2/latlong.dart';

part 'driver_event.dart';
part 'driver_state.dart';

class DriverBloc extends Bloc<DriverEvent, DriverState> {
  DriverBloc() : super(const DriverState()) {
    on<OpenOrderModal>((event, emit) => emit(state.copyWith(orderModalOpen: true)));
    on<CloseOrderModal>((event, emit) => emit(state.copyWith(orderModalOpen: false)));
    on<SetMyLocation>((event, emit) => emit(state.copyWith(myLatLng: event.pos)));
    on<SetRoutePoints>((event, emit) => emit(state.copyWith(routePoints: event.points)));
  }
}
