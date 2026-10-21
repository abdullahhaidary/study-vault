import 'package:flutter/widgets.dart';

/// In-app notices are the supported path.
///
/// Local system notifications are not posted. This project does not include a
/// platform notification plugin, and adding one would require Android, iOS,
/// and desktop entitlements that are not configured. A notice that arrives
/// while the app is backgrounded is still shown in-app when the user returns,
/// as long as the process was not killed.
///
/// If the operating system kills the app, the queue does not keep running.
/// Startup recovery marks an in-flight job partial or interrupted so it can
/// be retried. It never claims the provider request is still running.
class AiGenerationNotificationBridge {
  const AiGenerationNotificationBridge();

  bool get systemNotificationsAvailable => false;

  String get limitation =>
      'System notifications are unavailable on this build. '
      'Completion, failure, and partial results appear in the app. '
      'Generation does not continue after the operating system kills the app.';

  bool get appIsBackgrounded {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }
}
