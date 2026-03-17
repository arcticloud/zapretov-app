import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hiddify/core/analytics/analytics_controller.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/logger/logger.dart';
import 'package:hiddify/core/logger/logger_controller.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_migration.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/app/widget/app.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';

import 'package:hiddify/features/log/data/log_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/system_tray/notifier/system_tray_notifier.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hiddify/riverpod_observer.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> lazyBootstrap(WidgetsBinding widgetsBinding, Environment env) async {
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  final container = ProviderContainer(overrides: [environmentProvider.overrideWithValue(env)]);

  try {
    await _doBootstrap(widgetsBinding, env, container);
  } catch (e, stackTrace) {
    try {
      Logger.bootstrap.error("bootstrap failed, launching app anyway", e, stackTrace);
    } catch (_) {}
  }

  // ALWAYS run the app and remove splash, no matter what happened above
  runApp(
    ProviderScope(
      parent: container,
      observers: [RiverpodObserver()],
      child: SentryUserInteractionWidget(child: const App()),
    ),
  );

  if (!kIsWeb) {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  }
}

Future<void> _doBootstrap(WidgetsBinding widgetsBinding, Environment env, ProviderContainer container) async {
  LoggerController.preInit();
  FlutterError.onError = Logger.logFlutterError;
  WidgetsBinding.instance.platformDispatcher.onError = Logger.logPlatformDispatcherError;

  final stopWatch = Stopwatch()..start();

  await _safeInit("directories", () => container.read(appDirectoriesProvider.future), timeout: 5000);
  try {
    LoggerController.init(container.read(logPathResolverProvider).appFile().path);
  } catch (_) {}

  final appInfo = await _safeInit("app info", () => container.read(appInfoProvider.future), timeout: 5000);
  await _safeInit("preferences", () => container.read(sharedPreferencesProvider.future), timeout: 5000);

  await _safeInit("analytics", () async {
    final enableAnalytics = await container.read(analyticsControllerProvider.future);
    if (enableAnalytics) {
      await container.read(analyticsControllerProvider.notifier).enableAnalytics();
    }
  }, timeout: 5000);

  await _safeInit("preferences migration", () async {
    try {
      await PreferencesMigration(sharedPreferences: container.read(sharedPreferencesProvider).requireValue).migrate();
    } catch (e, stackTrace) {
      Logger.bootstrap.error("preferences migration failed", e, stackTrace);
      Logger.bootstrap.info("clearing preferences");
      await container.read(sharedPreferencesProvider).requireValue.clear();
    }
  }, timeout: 5000);

  final debug = container.read(debugModeNotifierProvider) || kDebugMode;

  if (PlatformUtils.isDesktop) {
    await _safeInit("window controller", () => container.read(windowNotifierProvider.future), timeout: 5000);

    final silentStart = container.read(Preferences.silentStart);
    Logger.bootstrap.debug("silent start [${silentStart ? "Enabled" : "Disabled"}]");
    if (!silentStart) {
      try {
        await container.read(windowNotifierProvider.notifier).show(focus: false);
      } catch (_) {}
    } else {
      Logger.bootstrap.debug("silent start, remain hidden accessible via tray");
    }
    await _safeInit("auto start service", () => container.read(autoStartNotifierProvider.future), timeout: 3000);
  }
  await _safeInit("logs repository", () => container.read(logRepositoryProvider.future), timeout: 5000);
  await _safeInit("logger controller", () => LoggerController.postInit(debug), timeout: 3000);

  if (appInfo != null) {
    Logger.bootstrap.info(appInfo.format());
  }

  await _safeInit("profile repository", () => container.read(profileRepositoryProvider.future), timeout: 10000);

  await _safeInit("translations", () => container.read(translationsProvider.future), timeout: 5000);

  await _safeInit("active profile", () => container.read(activeProfileProvider.future), timeout: 1000);
  await _safeInit("hiddify-core", () => container.read(hiddifyCoreServiceProvider).init(), timeout: 15000);

  if (!kIsWeb) {
    if (PlatformUtils.isDesktop) {
      await _safeInit("system tray", () => container.read(systemTrayNotifierProvider.future), timeout: 1000);
    }

    if (PlatformUtils.isAndroid) {
      await _safeInit("android display mode", () async {
        await FlutterDisplayMode.setHighRefreshRate();
      });
    }
  }

  Logger.bootstrap.info("bootstrap took [${stopWatch.elapsedMilliseconds}ms]");
  stopWatch.stop();
}

Future<T> _init<T>(String name, Future<T> Function() initializer, {int? timeout}) async {
  final stopWatch = Stopwatch()..start();
  Logger.bootstrap.info("initializing [$name]");
  Future<T> func() => timeout != null ? initializer().timeout(Duration(milliseconds: timeout)) : initializer();
  try {
    final result = await func();
    Logger.bootstrap.debug("[$name] initialized in ${stopWatch.elapsedMilliseconds}ms");
    return result;
  } catch (e, stackTrace) {
    Logger.bootstrap.error("[$name] error initializing", e, stackTrace);
    rethrow;
  } finally {
    stopWatch.stop();
  }
}

Future<T?> _safeInit<T>(String name, Future<T> Function() initializer, {int? timeout}) async {
  try {
    return await _init(name, initializer, timeout: timeout);
  } catch (e) {
    return null;
  }
}
