import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../widget/form_input.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final ApiService _api;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _api = RepositoryProvider.of<ApiService>(context);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final (user, _) = await _api.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (user.role.toLowerCase() == 'driver') {
        if (!mounted) return;
        context.go('/driver');
      } else {
        if (!mounted) return;
        context.go('/customer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login gagal: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              FormInput(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Email wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              FormInput(
                label: 'Password',
                controller: _password,
                obscure: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              PrimaryButton(text: _loading ? 'Memproses...' : 'Masuk', onPressed: _loading ? null : _submit),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : () => context.go('/register'),
                child: const Text('Belum punya akun? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}