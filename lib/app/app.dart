import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ai_generation_queue/presentation/generation_queue_host.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../core/widgets/desktop_frame.dart';
import '../core/widgets/system_bottom_inset.dart';
import '../features/study_workspace/presentation/study_workspace_overlay.dart';
import 'app_info.dart';
import 'routes.dart';

/// Root widget for StudyDesk app.
class StudyVaultApp extends ConsumerWidget {
  const StudyVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode:
          ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
      initialRoute: AppRoutes.home,
      onGenerateRoute: onGenerateRoute,
      builder: (context, child) {
        return GenerationQueueHost(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SystemBottomSafeArea(
              child: DesktopFrame(
                child: StudyWorkspaceHost(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
