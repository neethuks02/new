import 'platform_helper_io.dart'
    if (dart.library.js_interop) 'platform_helper_web.dart' as helper;

class PlatformHelper {
  static bool get isWeb => helper.isWebPlatform();

  static void installPwaApp() {
    helper.triggerPwaInstall();
  }
}
