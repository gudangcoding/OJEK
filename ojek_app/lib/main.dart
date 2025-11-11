import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'pages/login/login_page.dart';
import 'pages/register/register_page.dart';
import 'pages/customer/customer_page.dart';
import 'pages/driver/driver_page.dart';
import 'pages/splash/splash_page.dart';
import 'pages/login/bloc/login_bloc.dart';
import 'pages/register/bloc/register_bloc.dart';
import 'pages/customer_order/bloc/customer_order_bloc.dart';
import 'pages/driver_order/bloc/driver_order_bloc.dart';
import 'services/api.dart';
import 'services/auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  // Preload token & role dari storage agar redirect GoRouter tidak mengirim ke /login saat refresh
  try {
    final token = await AuthStorage.getToken();
    final role = await AuthStorage.getRole();
    if (token != null && token.isNotEmpty) {
      api.setAuth(token, role: role ?? '');
    }
  } catch (_) {
    // abaikan, akan dianggap belum login
  }
  runApp(OjekApp(api: api));
}

class OjekApp extends StatelessWidget {
  final ApiService api;
  const OjekApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final api = RepositoryProvider.of<ApiService>(context);
        final fullPath = state.fullPath ?? state.uri.toString();
        final onLogin = fullPath.startsWith('/login');
        final onRegister = fullPath.startsWith('/register');
        final onSplash = fullPath.startsWith('/splash');

        final hasToken = (api.token != null && api.token!.isNotEmpty);

        // Biarkan Splash menangani navigasi awal sendiri
        if (onSplash) return null;

        // Jika belum login, arahkan ke /login kecuali sudah di /login atau /register
        if (!hasToken) {
          if (onLogin || onRegister) return null;
          return '/login';
        }

        // Jika sudah login dan mencoba buka /login atau /register, arahkan ke dashboard sesuai role
        if (onLogin || onRegister) {
          final role = (api.role ?? '').toLowerCase();
          if (role == 'driver') return '/driver';
          return '/customer';
        }

        // Opsional: jika role driver membuka /customer, bisa diarahkan ke /driver (atau biarkan)
        // Opsional: jika role customer membuka /driver, arahkan ke /customer
        // Untuk saat ini, biarkan akses tetap berjalan.
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(path: '/customer', builder: (context, state) => CustomerPage()),
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
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue),
          routerConfig: router,
        ),
      ),
    );
  }
}
