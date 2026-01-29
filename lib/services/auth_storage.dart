export 'auth_storage_stub.dart'
    if (dart.library.html) 'auth_storage_web.dart'
    if (dart.library.io) 'auth_storage_io.dart';
