part of 'login_bloc.dart';

@immutable
sealed class LoginState {}

final class LoginInitial extends LoginState {}
final class LoginLoading extends LoginState {}
final class LoginSuccess extends LoginState {
  final String role;
  LoginSuccess(this.role);
}
final class LoginFailure extends LoginState {
  final String message;
  LoginFailure(this.message);
}
