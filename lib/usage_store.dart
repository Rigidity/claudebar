import 'dart:async';

import 'package:flutter/foundation.dart';

import 'usage.dart';
import 'usage_client.dart';

class UsageStore extends ChangeNotifier {
  UsageStore() {
    refresh();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
    // Keeps pace and "resets in" text current between fetches.
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  static const _refreshInterval = Duration(minutes: 5);

  UsageSnapshot? snapshot;
  String? error;
  DateTime? lastUpdated;
  bool isLoading = false;

  late final Timer _refreshTimer;
  late final Timer _tickTimer;

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      snapshot = await UsageClient.fetch();
      error = null;
      lastUpdated = DateTime.now();
    } on UsageException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Usage request failed: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _tickTimer.cancel();
    super.dispose();
  }
}
