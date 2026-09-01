import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/services/auth_service.dart';
import 'package:prasowka/services/sync_service.dart';
import 'package:prasowka/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthService>();
    final sync = context.read<SyncService>();
    String? error;

    if (_isLogin) {
      error = await auth.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (error == null) {
        sync.setEncryptionPassword(_passwordCtrl.text);
        final result = await sync.mergeFirstLogin();
        if (mounted && result == MergeResult.pulled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Przywrócono ustawienia z chmury')),
          );
        }
      }
    } else {
      error = await auth.registerWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (error == null) {
        sync.setEncryptionPassword(_passwordCtrl.text);
      }
    }

    if (!mounted) return;
    setState(() { _loading = false; _error = error; });
    if (error == null && mounted) Navigator.of(context).pop();
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthService>();
    final sync = context.read<SyncService>();
    final error = await auth.signInWithGoogle();
    if (error == null) {
      // Google sign-in: use UID as encryption key (no password available)
      sync.setEncryptionPassword(auth.user?.uid ?? 'fallback');
      final result = await sync.mergeFirstLogin();
      if (mounted && result == MergeResult.pulled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Przywrócono ustawienia z chmury')),
        );
      }
    }
    if (!mounted) return;
    setState(() { _loading = false; _error = error; });
    if (error == null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark, size: 64, color: accent),
                const SizedBox(height: 12),
                Text('Prasówka', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Zaloguj się do konta' : 'Utwórz nowe konto',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Podaj email';
                    if (!v.contains('@')) return 'Nieprawidłowy email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Podaj hasło';
                    if (v.length < 6) return 'Min. 6 znaków';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isLogin ? 'Zaloguj się' : 'Zarejestruj się', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('lub', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Google
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Zaloguj przez Google'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle
                TextButton(
                  onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                  child: Text(
                    _isLogin ? 'Nie masz konta? Zarejestruj się' : 'Masz już konto? Zaloguj się',
                    style: TextStyle(color: accent),
                  ),
                ),

                // Skip
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Pomiń na razie', style: TextStyle(color: Colors.grey.shade500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
