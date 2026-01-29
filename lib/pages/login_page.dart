import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/cognito_config.dart';
import '../services/auth_storage.dart';
import '../services/cognito_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CognitoAuthService _authService = CognitoAuthService.fromConfig();
  bool _loading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!CognitoConfig.isConfigured) {
      debugPrint(
        'Cognito is not configured. Set COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID.',
      );
      setState(() {
        _statusMessage =
            'Sign-in is unavailable right now. Please try again later.';
      });
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Enter username and password.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final session = await _authService.signIn(
        username: username,
        password: password,
      );
      if (kDebugMode) {
        final accessToken = session.accessToken;
        final idToken = session.idToken;
        debugPrint(
          'LoginPage: access token len=${accessToken.length} head=${(accessToken)}',
        );
        debugPrint(
          'LoginPage: id token len=${idToken.length} head=${(idToken)}',
        );
      }
      await AuthStorage.saveAccessToken(session.accessToken);
      await AuthStorage.saveIdToken(session.idToken);
      if (!mounted) return;
      setState(() {
        _statusMessage = null;
        _loading = false;
      });
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Sign-in failed: $error');
      setState(() {
        _statusMessage = _friendlySignInError(error);
        _loading = false;
      });
    }
  }

  String _friendlySignInError(Object error) {
    if (_isNetworkError(error)) {
      return 'We could not reach the server. Check your internet connection and try again.';
    }
    if (error is CognitoClientException) {
      final code = error.code ?? error.name ?? '';
      switch (code) {
        case 'NotAuthorizedException':
          return 'Incorrect username or password.';
        case 'UserNotFoundException':
          return 'No account found with that username or email.';
        case 'UserNotConfirmedException':
          return 'Your account is not confirmed yet. Check your email or SMS for the verification link or code.';
        case 'PasswordResetRequiredException':
          return 'Your password must be reset before you can sign in.';
        case 'TooManyRequestsException':
        case 'LimitExceededException':
        case 'RequestLimitExceeded':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'InvalidParameterException':
          return 'Please check your username and password and try again.';
        case 'ResourceNotFoundException':
          return 'Sign-in is unavailable right now. Please try again later.';
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return 'Sign-in failed. Please try again.';
  }

  bool _isNetworkError(Object error) {
    final description = error.toString().toLowerCase();
    return description.contains('socketexception') ||
        description.contains('failed host lookup') ||
        description.contains('network') ||
        description.contains('timeout') ||
        description.contains('timed out');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('LoginPage: build');
    return Scaffold(
      // appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_pin, size: 64),
                const SizedBox(height: 16),
                Text(
                  'LocaXion Bookmark',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username or email',
                          ),
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signIn(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(_loading ? 'Signing in...' : 'Sign In'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/signup');
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Create account'),
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (!CognitoConfig.isConfigured && kDebugMode) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Set COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID using --dart-define.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
