import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.database, required this.auth});

  final Database database;
  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool obscurePassword = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || loading) return;
    setState(() { loading = true; error = null; });
    try {
      final session = await widget.auth.login(username: username.text, password: password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(session.isAdmin ? AppRoutes.admin : AppRoutes.staff);
    } on AuthenticationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to sign in right now.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Damma School Management System', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 28),
                      TextFormField(controller: username, enabled: !loading, autofocus: true, validator: (value) => value == null || value.trim().isEmpty ? 'Username is required.' : null, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 16),
                      TextFormField(controller: password, enabled: !loading, obscureText: obscurePassword, onFieldSubmitted: (_) => submit(), validator: (value) => value == null || value.isEmpty ? 'Password is required.' : null, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(tooltip: obscurePassword ? 'Show password' : 'Hide password', onPressed: loading ? null : () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                      if (error != null) ...[const SizedBox(height: 16), Text(error!, style: TextStyle(color: Colors.red))],
                      const SizedBox(height: 24),
                      FilledButton.icon(onPressed: loading ? null : submit, icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: const Text('Login')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}