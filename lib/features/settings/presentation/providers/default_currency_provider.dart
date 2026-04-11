import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';

/// Persists the user's default currency for financial employee requests.
///
/// State is the integer id of a `Currency` from `/api/v1/currencies`, or
/// `null` when the user has not chosen a default. Stored in
/// `flutter_secure_storage` so it survives app restarts.
class DefaultCurrencyController extends StateNotifier<int?> {
  final FlutterSecureStorage _storage;

  DefaultCurrencyController()
      : _storage = const FlutterSecureStorage(),
        super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _storage.read(key: StorageKeys.defaultCurrencyId);
      if (v == null || v.isEmpty) return;
      final id = int.tryParse(v);
      if (id != null) state = id;
    } catch (_) {
      // ignore — leave state as null
    }
  }

  Future<void> setCurrency(int? id) async {
    if (state == id) return;
    state = id;
    if (id == null) {
      await _storage.delete(key: StorageKeys.defaultCurrencyId);
    } else {
      await _storage.write(
        key: StorageKeys.defaultCurrencyId,
        value: id.toString(),
      );
    }
  }

  Future<void> clear() => setCurrency(null);
}

final defaultCurrencyProvider =
    StateNotifierProvider<DefaultCurrencyController, int?>(
  (_) => DefaultCurrencyController(),
);
