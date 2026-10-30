import 'dart:js_interop';

@JS('window.triggerPwaInstall')
external void _triggerPwaInstall();

bool isWebPlatform() => true;

void triggerPwaInstall() {
  try {
    _triggerPwaInstall();
  } catch (e) {
    // Fallback if not available
  }
}
