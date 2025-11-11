import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'customer_profil_event.dart';
part 'customer_profil_state.dart';

class CustomerProfilBloc extends Bloc<CustomerProfilEvent, CustomerProfilState> {
  CustomerProfilBloc() : super(CustomerProfilInitial()) {
    on<CustomerProfilEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
