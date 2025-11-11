import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../../../services/api.dart';
import '../../../services/auth_storage.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final ApiService api;
  LoginBloc({ApiService? apiService})
      : api = apiService ?? ApiService(),
        super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(LoginSubmitted e, Emitter<LoginState> emit) async {
    emit(LoginLoading());
    try {
      final (user, token) = await api.login(e.email.trim(), e.password);
      await AuthStorage.saveAuth(token: token, role: user.role, userId: user.id);
      emit(LoginSuccess(user.role));
    } catch (err) {
      emit(LoginFailure(err.toString()));
    }
  }
}
