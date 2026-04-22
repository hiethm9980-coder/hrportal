import 'package:flutter_riverpod/legacy.dart';

/// After the user pops back from `/tasks/:id`, list screens can highlight the
/// corresponding [TaskCard] using this id.
final lastReturnedFromTaskDetailIdProvider =
    StateProvider<int?>((ref) => null);
