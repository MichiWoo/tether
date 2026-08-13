import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'api_client.dart';

/// Cliente HTTP autenticado con refresh automático ante 401.
final apiClientProvider = Provider<Dio>(
  (ref) => ApiClient.create(storage: ref.watch(tokenStorageProvider)),
);
