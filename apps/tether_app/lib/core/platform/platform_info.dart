import 'package:flutter/foundation.dart';

/// true si la app corre en escritorio (macOS, Windows o Linux).
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// true si la app corre en móvil (iOS o Android).
bool get isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// true si la app corre en Android.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
