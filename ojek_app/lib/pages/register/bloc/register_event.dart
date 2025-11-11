part of 'register_bloc.dart';

@immutable
sealed class RegisterEvent {}

final class RegisterSubmitted extends RegisterEvent {
  final String name;
  final String email;
  final String password;
  final String role;
  RegisterSubmitted(this.name, this.email, this.password, this.role);
}
