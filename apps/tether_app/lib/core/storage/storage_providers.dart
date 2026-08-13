import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';

/// Persistencia de los tokens de sesión (Keychain/Keystore por plataforma).
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
