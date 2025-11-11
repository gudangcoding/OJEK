import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../widget/form_input.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'customer';
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
      final user = await _api.register(_name.text.trim(), _email.text.trim(), _password.text, _role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrasi berhasil')));
      if (user.role.toLowerCase() == 'driver') {
        if (!mounted) return;
        context.go('/driver');
      } else {
        if (!mounted) return;
        context.go('/customer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registrasi gagal: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                FormInput(
                  label: 'Name',
                  controller: _name,
                  validator: (v) => (v == null || v.isEmpty) ? 'Name wajib diisi' : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                RoleDropdown(value: _role, onChanged: (v) => setState(() => _role = v ?? 'customer')),
                const SizedBox(height: 20),
                PrimaryButton(text: _loading ? 'Memproses...' : 'Daftar', onPressed: _loading ? null : _submit),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () => context.go('/login'),
                  child: const Text('Sudah punya akun? Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}