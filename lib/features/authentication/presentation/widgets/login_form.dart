import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../state/auth_notifier.dart';
import '../state/auth_state.dart';
import 'manual_oauth_dialog.dart';

/// Login form widget
class LoginForm extends StatefulWidget {
  final AuthNotifier authNotifier;

  const LoginForm({
    super.key,
    required this.authNotifier,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _hasActiveOAuthFlow = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveOAuthFlow();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if there's an active OAuth flow in progress
  Future<void> _checkForActiveOAuthFlow() async {
    final secureStorage = getIt<SecureStorageService>();
    final oauthState = await secureStorage.read('oauth_state');
    if (mounted) {
      setState(() {
        _hasActiveOAuthFlow = oauthState != null && oauthState.isNotEmpty;
      });
    }
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      widget.authNotifier.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final isLoading = widget.authNotifier.state is AuthLoading;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your Open Library account email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _handleLogin(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // Login button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text('or',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),

              // OAuth login button
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _handleOAuthLogin,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text(
                      'Log in at Open Library',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Manual code entry button - only visible if OAuth flow is active
                  if (_hasActiveOAuthFlow) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isLoading ? null : _showManualCodeDialog,
                      icon: const Icon(Icons.vpn_key, size: 18),
                      label: const Text(
                        'Having trouble? Enter code manually',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleOAuthLogin() {
    widget.authNotifier.initiateOAuthLogin();
    // After initiating OAuth, check again to show the manual entry button
    _checkForActiveOAuthFlow();
  }

  void _showManualCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => ManualOAuthDialog(
        authNotifier: widget.authNotifier,
      ),
    );
  }
}
