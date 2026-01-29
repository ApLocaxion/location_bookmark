import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/cognito_config.dart';

class CognitoSessionData {
  const CognitoSessionData({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.username,
  });

  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String username;
}

class CognitoAuthService {
  CognitoAuthService({
    required String userPoolId,
    required String clientId,
    String? clientSecret,
  })  : _clientSecret = clientSecret,
        _userPool = CognitoUserPool(
          userPoolId,
          clientId,
          clientSecret: clientSecret,
        );

  factory CognitoAuthService.fromConfig() {
    final secret = CognitoConfig.clientSecret.isEmpty
        ? null
        : CognitoConfig.clientSecret;
    return CognitoAuthService(
      userPoolId: CognitoConfig.userPoolId,
      clientId: CognitoConfig.clientId,
      clientSecret: secret,
    );
  }

  final CognitoUserPool _userPool;
  final String? _clientSecret;

  Future<CognitoSessionData> signIn({
    required String username,
    required String password,
  }) async {
    final user = CognitoUser(
      username,
      _userPool,
      clientSecret: _clientSecret,
    );
    final authDetails = AuthenticationDetails(
      username: username,
      password: password,
    );
    final session = await user.authenticateUser(authDetails);
    if (session == null) {
      throw StateError('No session returned from Cognito.');
    }

    final accessToken = session.getAccessToken().getJwtToken();
    final idToken = session.getIdToken().getJwtToken();
    if (accessToken == null || idToken == null) {
      throw StateError('Cognito tokens are missing.');
    }
    final refreshToken = session.getRefreshToken()?.token;
    final expiration = session.getAccessToken().getExpiration();
    final expiresAt = expiration == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            expiration * 1000,
            isUtc: true,
          );

    return CognitoSessionData(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      username: username,
    );
  }

  Future<void> signUp({
    required String email,
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    final attributes = [
      AttributeArg(name: 'email', value: email),
      AttributeArg(name: 'name', value: name),
      AttributeArg(name: 'given_name', value: name),
      AttributeArg(name: 'phone_number', value: phoneNumber),
    ];
    await _userPool.signUp(email, password, userAttributes: attributes);
  }
}
