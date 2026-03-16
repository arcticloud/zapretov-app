import 'dart:async';

import 'package:dartx/dartx.dart';

import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/model/proxy_failure.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/riverpod_utils.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proxies_overview_notifier.g.dart';

enum ProxiesSort {
  unsorted,
  name,
  delay,
  usage;

  String present(TranslationsEn t) => switch (this) {
    ProxiesSort.unsorted => t.pages.proxies.sortOptions.unsorted,
    ProxiesSort.name => t.pages.proxies.sortOptions.name,
    ProxiesSort.delay => t.pages.proxies.sortOptions.delay,
    ProxiesSort.usage => t.pages.proxies.sortOptions.usage,
  };
}

@Riverpod(keepAlive: true)
class ProxiesSortNotifier extends _$ProxiesSortNotifier with AppLogger {
  late final _pref = PreferencesEntry(
    preferences: ref.watch(sharedPreferencesProvider).requireValue,
    key: "proxies_sort_mode",
    defaultValue: ProxiesSort.delay,
    mapFrom: ProxiesSort.values.byName,
    mapTo: (value) => value.name,
  );

  @override
  ProxiesSort build() {
    final sortBy = _pref.read();
    loggy.info("sort proxies by: [${sortBy.name}]");
    return sortBy;
  }

  Future<void> update(ProxiesSort value) {
    state = value;
    return _pref.write(value);
  }
}

@riverpod
class ProxiesOverviewNotifier extends _$ProxiesOverviewNotifier with AppLogger {
  static const _cacheKey = 'cached_server_list';
  static const _selectedCacheKey = 'cached_selected_proxy';

  @override
  Stream<OutboundGroup?> build() async* {
    ref.disposeDelay(const Duration(seconds: 15));
    ref.watch(coreRestartSignalProvider);
    final serviceRunning = await ref.watch(serviceRunningProvider.future);
    if (!serviceRunning) {
      // Service not running — try to yield cached server list
      final cached = _loadCache();
      if (cached != null) {
        loggy.info("service not running, using cached server list");
        yield cached;
        return;
      }
      throw const ServiceNotRunning();
    }
    final sortBy = ref.watch(proxiesSortNotifierProvider);
    yield* ref
        .watch(proxyRepositoryProvider)
        .watchProxies()
        .map(
          (event) => event.getOrElse((err) {
            loggy.warning("error receiving proxies", err);
            throw err;
          }),
        )
        .asyncMap((proxies) async {
          final sorted = await _sortOutbounds(proxies, sortBy);
          _saveCache(sorted);
          _applyCachedSelection(sorted);
          return sorted;
        });
  }

  void _saveCache(OutboundGroup? group) {
    if (group == null) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider).requireValue;
      prefs.setString(_cacheKey, group.writeToJson());
      prefs.setString(_selectedCacheKey, group.selected);
    } catch (e) {
      loggy.warning("failed to cache server list", e);
    }
  }

  OutboundGroup? _loadCache() {
    try {
      final prefs = ref.read(sharedPreferencesProvider).requireValue;
      final json = prefs.getString(_cacheKey);
      if (json == null || json.isEmpty) return null;
      final group = OutboundGroup.fromJson(json);
      // Restore selected proxy from cache
      final selected = prefs.getString(_selectedCacheKey);
      if (selected != null && selected.isNotEmpty) {
        group.selected = selected;
      }
      // Clear ping times — they're stale
      for (final item in group.items) {
        item.urlTestDelay = 0;
      }
      return group;
    } catch (e) {
      loggy.warning("failed to load cached server list", e);
      return null;
    }
  }

  /// Save user's server selection to cache (used when selecting from cached list while disconnected)
  void cacheSelectedProxy(String tag) {
    try {
      final prefs = ref.read(sharedPreferencesProvider).requireValue;
      prefs.setString(_selectedCacheKey, tag);
    } catch (e) {
      loggy.warning("failed to cache selected proxy", e);
    }
  }

  /// Apply cached server selection after VPN starts (user chose server while disconnected)
  void _applyCachedSelection(OutboundGroup? group) {
    if (group == null) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider).requireValue;
      final cachedTag = prefs.getString(_selectedCacheKey);
      if (cachedTag == null || cachedTag.isEmpty) return;
      if (cachedTag == group.selected) return;

      final exists = group.items.any((item) => item.tag == cachedTag);
      if (!exists) return;

      loggy.info("applying cached server selection: $cachedTag");
      changeProxy(group.tag, cachedTag);
      prefs.remove(_selectedCacheKey);
    } catch (e) {
      loggy.warning("failed to apply cached selection", e);
    }
  }

  // Future<List<OutboundGroup>> _sortOutbounds(
  //   List<OutboundGroup> proxies,
  //   ProxiesSort sortBy,
  // ) async {
  //   final groupWithSelected = {
  //     for (final o in proxies) o.tag: o.selected,
  //   };
  //   final sortedProxies = <OutboundGroup>[];
  //   for (final group in proxies) {
  //     final sortedItems = switch (sortBy) {
  //       ProxiesSort.name => group.items.sortedWith((a, b) {
  //           if (a.isGroup && !b.isGroup) return -1;
  //           if (!a.isGroup && b.isGroup) return 1;
  //           return a.tag.compareTo(b.tag);
  //         }),
  //       ProxiesSort.delay => group.items.sortedWith((a, b) {
  //           if (a.isGroup && !b.isGroup) return -1;
  //           if (!a.isGroup && b.isGroup) return 1;

  //           final ai = a.urlTestDelay;
  //           final bi = b.urlTestDelay;
  //           if (ai == 0 && bi == 0) return -1;
  //           if (ai == 0 && bi > 0) return 1;
  //           if (ai > 0 && bi == 0) return -1;
  //           return ai.compareTo(bi);
  //         }),
  //       ProxiesSort.unsorted => group.items,
  //     };
  //     final items = <OutboundInfo>[];
  //     for (final item in sortedItems) {
  //       // if (groupWithSelected.keys.contains(item.tag)) {
  //       //   items.add(item.copyWith(selectedTag: groupWithSelected[item.tag]));
  //       // } else {
  //       items.add(item);
  //       // }
  //     }
  //     group.items.clear();
  //     group.items.addAll(items);
  //     sortedProxies.add(group);
  //   }
  //   return sortedProxies;
  // }

  Future<OutboundGroup?> _sortOutbounds(OutboundGroup? proxies, ProxiesSort sortBy) async {
    if (proxies == null) return null;

    final sortedItems = switch (sortBy) {
      ProxiesSort.name => proxies.items.sortedWith((a, b) {
        if (a.isGroup && !b.isGroup) return -1;
        if (!a.isGroup && b.isGroup) return 1;
        return a.tag.compareTo(b.tag);
      }),
      ProxiesSort.delay => proxies.items.sortedWith((a, b) {
        if (a.isGroup && !b.isGroup) return -1;
        if (!a.isGroup && b.isGroup) return 1;

        final ai = a.urlTestDelay;
        final bi = b.urlTestDelay;
        if (ai == 0 && bi == 0) return -1;
        if (ai == 0 && bi > 0) return 1;
        if (ai > 0 && bi == 0) return -1;
        return ai.compareTo(bi);
      }),
      ProxiesSort.unsorted => proxies.items,
      ProxiesSort.usage => proxies.items.sortedWith((a, b) {
        if (a.isGroup && !b.isGroup) return -1;
        if (!a.isGroup && b.isGroup) return 1;
        return (b.upload + b.download).compareTo(a.upload + a.download);
      }),
    };
    final items = <OutboundInfo>[];
    for (final item in sortedItems) {
      // if (groupWithSelected.keys.contains(item.tag)) {
      //   items.add(item.copyWith(selectedTag: groupWithSelected[item.tag]));
      // } else {
      items.add(item);
      // }
    }
    proxies.items.clear();
    proxies.items.addAll(items);
    return proxies;
  }

  // Future<void> changeProxy(String groupTag, String outboundTag) async {
  //   loggy.debug(
  //     "changing proxy, group: [$groupTag] - outbound: [$outboundTag]",
  //   );
  //   if (state case AsyncData(value: final outbounds)) {
  //     await ref.read(hapticServiceProvider.notifier).lightImpact();
  //     await ref.read(proxyRepositoryProvider).selectProxy(groupTag, outboundTag).getOrElse((err) {
  //       loggy.warning("error selecting outbound", err);
  //       throw err;
  //     }).run();
  //     final outboundg = outbounds.where((e) => e.tag == groupTag).firstOrNull;
  //     if (outboundg != null) {
  //       final newselected = outboundg.items.where((e) => e.tag == outboundTag).firstOrNull;
  //       if (newselected != null) {
  //         newselected.isSelected = true;
  //         outboundg.selected = newselected;
  //       }
  //     }
  //     state = AsyncData(
  //       [...outbounds],
  //     ).copyWithPrevious(state);
  //   }
  // }

  Future<void> changeProxy(String groupTag, String outboundTag) async {
    loggy.debug("changing proxy, group: [$groupTag] - outbound: [$outboundTag]");
    if (!state.hasValue) return;
    final outbounds = state.value!;
    await ref.read(hapticServiceProvider.notifier).lightImpact();
    try {
      await ref.read(proxyRepositoryProvider).selectProxy(groupTag, outboundTag).getOrElse((err) {
        loggy.warning("error selecting outbound", err);
        throw err;
      }).run();
    } catch (e) {
      // Service not running (cached list) — just save selection locally
      loggy.info("service not running, saving selection to cache: $outboundTag");
      cacheSelectedProxy(outboundTag);
    }
    final newselected = outbounds.items.where((e) => e.tag == outboundTag).firstOrNull;
    if (newselected != null) {
      newselected.isSelected = true;
      outbounds.selected = newselected.tag;
      state = AsyncValue.data(outbounds);
    }
  }

  Future<void> urlTest(String groupTag) async {
    loggy.debug("testing group: [$groupTag]");
    if (state case AsyncData()) {
      await ref.read(hapticServiceProvider.notifier).lightImpact();
      await ref.read(proxyRepositoryProvider).urlTest(groupTag).getOrElse((err) {
        loggy.error("error testing group", err);
        throw err;
      }).run();
    }
  }
}
