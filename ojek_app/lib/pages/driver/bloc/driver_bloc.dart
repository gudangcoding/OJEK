import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'driver_event.dart';
part 'driver_state.dart';

class DriverBloc extends Bloc<DriverEvent, DriverState> {
  DriverBloc() : super(DriverInitial()) {
    on<DriverEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
