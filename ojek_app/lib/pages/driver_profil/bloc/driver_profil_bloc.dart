import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'driver_profil_event.dart';
part 'driver_profil_state.dart';

class DriverProfilBloc extends Bloc<DriverProfilEvent, DriverProfilState> {
  DriverProfilBloc() : super(DriverProfilInitial()) {
    on<DriverProfilEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
