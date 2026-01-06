import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import '../widgets/login_form.dart';

/// Login page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthNotifier _authNotifier;

  @override
  void initState() {
    super.initState();
    _authNotifier = getIt<AuthNotifier>();
    _authNotifier.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final state = _authNotifier.state;

    if (state is Authenticated) {
      // Navigate to home on successful login
      if (mounted) {
        context.goToHome();
      }
    } else if (state is AuthError) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo/Title
                Image.asset(
                  'assets/splash/splash_logo.png',
                  width: 200,
                ),
                Text(
                  'Reader',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A Book Reader for Open Library',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // Info text
                Text(
                  'Sign in with your Open Library account',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Login Form
                LoginForm(authNotifier: _authNotifier),

                const SizedBox(height: 24),

                Wrap(
                    spacing: 25,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => launchUrlString(
                            "https://archive.org/account/login.forgotpw.php"),
                        icon: Icon(Icons.open_in_browser),
                        label: Text(
                          'Forgot your password?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        style: TextButton.styleFrom(
                            foregroundColor: (Theme.of(context).brightness ==
                                    Brightness.light)
                                ? Colors.black
                                : Colors.white60,
                            backgroundColor: Colors.black26),
                      ),
                      TextButton.icon(
                        onPressed: () => launchUrlString(
                            "https://openlibrary.org/account/create"),
                        icon: Icon(Icons.open_in_browser),
                        label: Text(
                          'Create an account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        style: TextButton.styleFrom(
                            foregroundColor: (Theme.of(context).brightness ==
                                    Brightness.light)
                                ? Colors.black
                                : Colors.white60,
                            backgroundColor: Colors.black26),
                      ),
                    ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
