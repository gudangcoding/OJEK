import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../../../services/api.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final ApiService api;
  RegisterBloc({ApiService? apiService})
      : api = apiService ?? ApiService(),
        super(RegisterInitial()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onRegisterSubmitted(RegisterSubmitted e, Emitter<RegisterState> emit) async {
    emit(RegisterLoading());
    try {
      final user = await api.register(e.name.trim(), e.email.trim(), e.password, e.role);
      emit(RegisterSuccess(user.role));
    } catch (err) {
      emit(RegisterFailure(err.toString()));
    }
  }
}
