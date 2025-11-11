import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'pages/login/login_page.dart';
import 'pages/register/register_page.dart';
import 'pages/customer/customer_page.dart';
import 'pages/driver/driver_page.dart';
import 'pages/login/bloc/login_bloc.dart';
import 'pages/register/bloc/register_bloc.dart';
import 'pages/customer_order/bloc/customer_order_bloc.dart';
import 'pages/driver_order/bloc/driver_order_bloc.dart';
import 'services/api.dart';

void main() {
  runApp(const OjekApp());
}

class OjekApp extends StatelessWidget {
  const OjekApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/customer',
          builder: (context, state) => CustomerPage(),
        ),
        GoRoute(
          path: '/driver',
          builder: (context, state) => const DriverPage(),
        ),
      ],
    );
    return RepositoryProvider.value(
      value: api,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LoginBloc()),
          BlocProvider(create: (_) => RegisterBloc()),
          BlocProvider(create: (_) => CustomerOrderBloc(apiService: api)),
          BlocProvider(create: (_) => DriverOrderBloc(apiService: api)),
        ],
        child: MaterialApp.router(
          title: 'Ojek App',
          theme: ThemeData(primarySwatch: Colors.blue),
          routerConfig: router,
        ),
      ),
    );
  }
}
