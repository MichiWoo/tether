import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'realtime_service.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService();
});
