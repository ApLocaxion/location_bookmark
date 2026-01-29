import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/cognito_config.dart';
import '../services/cognito_auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CognitoAuthService _authService = CognitoAuthService.fromConfig();
  bool _loading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!CognitoConfig.isConfigured) {
      debugPrint(
        'Cognito is not configured. Set COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID.',
      );
      setState(() {
        _statusMessage =
            'Account creation is unavailable right now. Please try again later.';
      });
      return;
    }

    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || name.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'All fields are required.';
      });
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() {
        _statusMessage = 'Enter a valid email address.';
      });
      return;
    }
    if (!_isValidE164(phone)) {
      setState(() {
        _statusMessage =
            'Enter a valid phone number in E.164 format (example: +12025550123).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      await _authService.signUp(
        email: email,
        name: name,
        phoneNumber: phone,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign-up successful.')));
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      debugPrint('Sign-up failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = _friendlySignUpError(error);
      });
    }
  }

  String _friendlySignUpError(Object error) {
    if (_isNetworkError(error)) {
      return 'We could not reach the server. Check your internet connection and try again.';
    }
    if (error is CognitoClientException) {
      final code = error.code ?? error.name ?? '';
      switch (code) {
        case 'UsernameExistsException':
        case 'AliasExistsException':
          return 'An account already exists with that email or phone number.';
        case 'InvalidPasswordException':
          return 'Password does not meet the requirements. Try a longer password with a mix of letters and numbers.';
        case 'InvalidParameterException':
          return 'Please check your email, phone number, and name, then try again.';
        case 'TooManyRequestsException':
        case 'LimitExceededException':
        case 'RequestLimitExceeded':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'CodeDeliveryFailureException':
          return 'We could not send the verification message. Please try again.';
        case 'ResourceNotFoundException':
          return 'Account creation is unavailable right now. Please try again later.';
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return 'Sign-up failed. Please try again.';
  }

  bool _isNetworkError(Object error) {
    final description = error.toString().toLowerCase();
    return description.contains('socketexception') ||
        description.contains('failed host lookup') ||
        description.contains('network') ||
        description.contains('timeout') ||
        description.contains('timed out');
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidE164(String phone) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SignupPage: build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign up with Cognito',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone number (E.164)',
                            hintText: '+12025550123',
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signUp(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _signUp,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _loading ? 'Creating...' : 'Create account',
                          ),
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
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
