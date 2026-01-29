class CognitoConfig {
  static const userPoolId = 'eu-north-1_7yuCEBPYR';

  static const clientId = '70qbvqs2oh2jn507ugsva7qahp';

  static const clientSecret =
      '18n5vgt21thrmd2hth7diso0vngutjudf18qig36i9hk0eog04qm';

  static bool get isConfigured => userPoolId.isNotEmpty && clientId.isNotEmpty;
}
