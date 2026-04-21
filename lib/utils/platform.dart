import 'package:flutter/foundation.dart';

/// True when the current runtime's dominant input modality is mouse +
/// keyboard rather than touch — Windows/macOS/Linux native, and the
/// desktop variants of web (platform-detected via userAgent). Used to
/// pick between right-click (desktop) and long-press (mobile) for
/// context actions like "edit this item."
///
/// `defaultTargetPlatform` on web returns the browser's best guess at the
/// OS. So web on Android Chrome reports `android` (stays touch), web on
/// iPhone Safari reports `iOS` (stays touch), web on Windows/Mac/Linux
/// reports the desktop OS (gets right-click). This matches the signal we
/// want without a `MediaQuery(pointer: coarse)` pass.
bool get isDesktopUX =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;
