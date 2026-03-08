import 'dart:io';

import 'package:hiddify/utils/utils.dart';

/// Helper to set/unset macOS system proxy via networksetup.
/// Needed because hiddify-core's built-in SetSystemProxy doesn't work
/// reliably on macOS (possibly due to missing code signing or sandbox issues).
class MacosProxyHelper with InfraLogger {
  static const _instance = MacosProxyHelper._();
  const MacosProxyHelper._();
  factory MacosProxyHelper() => _instance;

  /// Set system HTTP and HTTPS proxy on all active network services.
  Future<void> enable(int port) async {
    if (!Platform.isMacOS) return;
    final services = await _getActiveServices();
    for (final service in services) {
      loggy.debug('Setting proxy on "$service" -> 127.0.0.1:$port');
      await Process.run('networksetup', ['-setwebproxy', service, '127.0.0.1', '$port']);
      await Process.run('networksetup', ['-setsecurewebproxy', service, '127.0.0.1', '$port']);
      await Process.run('networksetup', ['-setwebproxystate', service, 'on']);
      await Process.run('networksetup', ['-setsecurewebproxystate', service, 'on']);
      // Also set SOCKS proxy for apps that use it
      await Process.run('networksetup', ['-setsocksfirewallproxy', service, '127.0.0.1', '$port']);
      await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'on']);
    }
  }

  /// Remove system proxy from all active network services.
  Future<void> disable() async {
    if (!Platform.isMacOS) return;
    final services = await _getActiveServices();
    for (final service in services) {
      loggy.debug('Removing proxy from "$service"');
      await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
      await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
      await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
    }
  }

  /// Get list of active network services (Wi-Fi, Ethernet, etc.)
  Future<List<String>> _getActiveServices() async {
    final result = await Process.run('networksetup', ['-listallnetworkservices']);
    if (result.exitCode != 0) {
      loggy.warning('Failed to list network services: ${result.stderr}');
      return [];
    }
    final lines = (result.stdout as String).split('\n');
    // First line is a header ("An asterisk (*) denotes..."), skip it.
    // Lines starting with * are disabled services.
    return lines
        .skip(1)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('*'))
        .toList();
  }
}
