part of 'login_bloc.dart';

@immutable
sealed class LoginEvent {}

final class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;
  LoginSubmitted(this.email, this.password);
}
