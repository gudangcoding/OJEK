import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../services/api.dart';
import '../../services/auth_storage.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = RepositoryProvider.of<ApiService>(context);
    // Mulai bootstrap segera setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final token = await AuthStorage.getToken();
      final role = await AuthStorage.getRole();
      if (token != null && token.isNotEmpty) {
        _api.setAuth(token, role: role ?? '');
        if (!mounted) return;
        final r = (role ?? '').toLowerCase();
        if (r == 'driver') {
          context.go('/driver');
        } else {
          context.go('/customer');
        }
      } else {
        if (!mounted) return;
        context.go('/login');
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}